unit uxmodem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, userial;

type
  TXModemProgressEvent = procedure(ABytesDone: Integer) of object;

// CRC-16/XMODEM (CCITT, poly 0x1021, init 0x0000, no reflection, no xorout)
// - the exact algorithm FluidNC's xmodem.cpp crc16_ccitt() implements.
function XModemCRC16(const ABuf; ALen: Integer): Word;

// Sends AData to the far end acting as an XMODEM RECEIVER (FluidNC's
// xmodemReceive(), reached via "$XR=<filename>" - the board receives, we
// transmit). Classic 128-byte/SOH blocks with CRC16 - FluidNC's receiver
// accepts either SOH(128)/STX(1024) and either checksum/CRC depending on
// what the sender offers, so 128-byte/CRC keeps this side simple with no
// real cost for a config.yaml-sized file.
function XModemSend(ALink: TSerialLink; const AData: TBytes;
  AOnProgress: TXModemProgressEvent = nil): Boolean;

// Receives into AData from the far end acting as an XMODEM SENDER
// (FluidNC's xmodemTransmit(), reached via "$XS=<filename>" - the board
// sends, we receive). Must handle BOTH 128-byte (SOH) and 1024-byte (STX)
// blocks since FluidNC's sender always uses 1K blocks
// (xmodem.cpp: #define TRANSMIT_XMODEM_1K 1).
function XModemReceive(ALink: TSerialLink; out AData: TBytes;
  AOnProgress: TXModemProgressEvent = nil): Boolean;

implementation

const
  SOH = $01;
  STX = $02;
  EOT = $04;
  ACK = $06;
  NAK = $15;
  CAN = $18;
  CTRLZ = $1A;
  BLOCK_TIMEOUT_MS = 1000; // FluidNC's DLY_1S
  MAX_RETRANS = 10;        // per-block retry budget (generous vs FluidNC's
                            // MAXRETRANS=3, since a real serial link here
                            // may be slower/burstier than the reference's
                            // assumed environment - still finite, so a dead
                            // link fails instead of hanging the UI forever)
  MAX_HANDSHAKE_ROUNDS = 16;
  MAX_REJECT_CYCLES = 200;  // safety cap beyond the reference's unbounded
                             // reject/NAK retry loop on the receive side

var
  CRCTable: array[0..255] of Word;

procedure InitCRCTable;
var
  i, j: Integer;
  crc: Word;
begin
  for i := 0 to 255 do
  begin
    crc := Word(i) shl 8;
    for j := 0 to 7 do
    begin
      if (crc and $8000) <> 0 then
        crc := Word((crc shl 1) xor $1021)
      else
        crc := Word(crc shl 1);
    end;
    CRCTable[i] := crc;
  end;
end;

function XModemCRC16(const ABuf; ALen: Integer): Word;
var
  p: PByte;
  i: Integer;
  crc: Word;
begin
  crc := 0;
  p := @ABuf;
  for i := 0 to ALen - 1 do
  begin
    crc := Word((crc shl 8) xor CRCTable[((crc shr 8) xor p^) and $FF]);
    Inc(p);
  end;
  Result := crc;
end;

function XModemSend(ALink: TSerialLink; const AData: TBytes;
  AOnProgress: TXModemProgressEvent): Boolean;
const
  BLOCK_SIZE = 128;
var
  useCRC: Boolean;
  c, retry, sent: Integer;
  packetNo: Byte;
  offset, chunkLen, i: Integer;
  pkt: array[0..BLOCK_SIZE + 4] of Byte; // SOH+no+~no+128 data+2 crc (or +1 cks)
  crc: Word;
  cks: Byte;
  ackOk: Boolean;
begin
  Result := False;
  sent := 0;

  // 1) Wait for the receiver's handshake: 'C' (CRC mode) or NAK (checksum).
  useCRC := True;
  c := -1;
  for retry := 1 to MAX_HANDSHAKE_ROUNDS * 2 do
  begin
    c := ALink.ReadByte(BLOCK_TIMEOUT_MS);
    if c = Ord('C') then begin useCRC := True; Break; end;
    if c = NAK then begin useCRC := False; Break; end;
    c := -1;
  end;
  if c = -1 then Exit; // no sync - far end never asked for data

  // 2) Send AData in 128-byte blocks, padding the final block with CTRLZ.
  packetNo := 1;
  offset := 0;
  while offset < Length(AData) do
  begin
    chunkLen := Length(AData) - offset;
    if chunkLen > BLOCK_SIZE then chunkLen := BLOCK_SIZE;

    pkt[0] := SOH;
    pkt[1] := packetNo;
    pkt[2] := Byte(not packetNo);
    for i := 0 to BLOCK_SIZE - 1 do
      if i < chunkLen then
        pkt[3 + i] := AData[offset + i]
      else
        pkt[3 + i] := CTRLZ;

    if useCRC then
    begin
      crc := XModemCRC16(pkt[3], BLOCK_SIZE);
      pkt[3 + BLOCK_SIZE] := Hi(crc);
      pkt[4 + BLOCK_SIZE] := Lo(crc);
    end
    else
    begin
      cks := 0;
      for i := 0 to BLOCK_SIZE - 1 do
        cks := Byte(cks + pkt[3 + i]);
      pkt[3 + BLOCK_SIZE] := cks;
    end;

    ackOk := False;
    for retry := 1 to MAX_RETRANS do
    begin
      if useCRC then
        ALink.WriteBytes(pkt, BLOCK_SIZE + 5)
      else
        ALink.WriteBytes(pkt, BLOCK_SIZE + 4);

      c := ALink.ReadByte(BLOCK_TIMEOUT_MS);
      if c = ACK then begin ackOk := True; Break; end;
      if c = CAN then
      begin
        if ALink.ReadByte(BLOCK_TIMEOUT_MS) = CAN then Exit; // canceled by receiver
      end;
      // NAK, timeout (-1), or garbage: retry the same block.
    end;
    if not ackOk then Exit; // exhausted retries - link likely dead

    Inc(offset, chunkLen);
    Inc(sent, chunkLen);
    packetNo := Byte(packetNo + 1);
    if Assigned(AOnProgress) then AOnProgress(sent);
  end;

  // 3) End of transmission.
  for retry := 1 to MAX_RETRANS do
  begin
    ALink.WriteByte(EOT);
    c := ALink.ReadByte(BLOCK_TIMEOUT_MS);
    if (c = ACK) or (c = -1) then Break; // FluidNC's own sender also treats
                                          // a timeout here as an acceptable
                                          // EOT ack (xmodemTransmit: `c ==
                                          // ACK || c == -1`)
  end;

  Result := True;
end;

function XModemReceive(ALink: TSerialLink; out AData: TBytes;
  AOnProgress: TXModemProgressEvent): Boolean;
var
  useCRC: Boolean;
  tryChar: Integer; // Ord('C'), or 0 once negotiated
  packetNo: Byte;
  round, rejectCycles, c, want, got: Integer;
  blockSize: Integer;
  blockOk: Boolean;
  hdr: array[0..2] of Byte;
  payload: array[0..1023] of Byte;
  csum: array[0..1] of Byte;
  buf: TBytes;
  bufLen: Integer;
  trimmed: Integer;

  procedure AppendPayload(ACount: Integer);
  begin
    if bufLen + ACount > Length(buf) then
      SetLength(buf, (bufLen + ACount) + 4096);
    Move(payload[0], buf[bufLen], ACount);
    Inc(bufLen, ACount);
  end;

begin
  Result := False;
  bufLen := 0;
  SetLength(buf, 8192);
  useCRC := True;
  tryChar := Ord('C');
  packetNo := 1;
  rejectCycles := 0;

  while True do
  begin
    // Handshake / re-sync: offer CRC first, fall back to checksum.
    c := -1;
    for round := 1 to MAX_HANDSHAKE_ROUNDS do
    begin
      if tryChar <> 0 then ALink.WriteByte(Byte(tryChar));
      c := ALink.ReadByte(BLOCK_TIMEOUT_MS * 2);
      if c = SOH then begin blockSize := 128; Break; end;
      if c = STX then begin blockSize := 1024; Break; end;
      if c = EOT then
      begin
        ALink.WriteByte(ACK);
        trimmed := bufLen;
        while (trimmed > 0) and (buf[trimmed - 1] = CTRLZ) do Dec(trimmed);
        SetLength(buf, trimmed);
        AData := buf;
        Result := True;
        Exit;
      end;
      if c = CAN then
      begin
        if ALink.ReadByte(BLOCK_TIMEOUT_MS) = CAN then Exit; // canceled by sender
      end;
      c := -1;
    end;
    if c = -1 then
    begin
      if tryChar = Ord('C') then
      begin
        tryChar := NAK;
        useCRC := False;
        Continue; // one more full round of handshake attempts, checksum mode
      end;
      Exit; // sync error - gave up
    end;
    if tryChar = Ord('C') then useCRC := True;
    tryChar := 0;

    // Block header already consumed its first byte (SOH/STX) above; read
    // packetno + complement + payload + checksum/CRC, and validate all of
    // it before touching packetNo/buf - blockOk stays False on any short
    // read or mismatch, so the tail below can fall straight through to a
    // single NAK-and-retry without a goto.
    blockOk := False;
    hdr[0] := Byte(c);
    if ALink.ReadBytes(hdr[1], 2, BLOCK_TIMEOUT_MS) = 2 then
    begin
      want := blockSize;
      got := ALink.ReadBytes(payload[0], want, BLOCK_TIMEOUT_MS);
      if got = want then
      begin
        if useCRC then
        begin
          if ALink.ReadBytes(csum[0], 2, BLOCK_TIMEOUT_MS) = 2 then
            blockOk := XModemCRC16(payload[0], blockSize) =
              ((Word(csum[0]) shl 8) or csum[1]);
        end
        else
        begin
          if ALink.ReadBytes(csum[0], 1, BLOCK_TIMEOUT_MS) = 1 then
          begin
            c := 0;
            for round := 0 to blockSize - 1 do c := (c + payload[round]) and $FF;
            blockOk := Byte(c) = csum[0];
          end;
        end;
        if blockOk and (hdr[1] <> Byte(not hdr[2])) then
          blockOk := False;
      end;
    end;

    if blockOk then
    begin
      if hdr[1] = packetNo then
      begin
        AppendPayload(blockSize);
        packetNo := Byte(packetNo + 1);
        ALink.WriteByte(ACK);
        if Assigned(AOnProgress) then AOnProgress(bufLen);
      end
      else if hdr[1] = Byte(packetNo - 1) then
        // Our previous ACK was lost and the sender resent the same block -
        // already have this data, just re-ACK without appending again.
        ALink.WriteByte(ACK)
      else
        blockOk := False; // packetno neither expected nor a retransmit
    end;

    if not blockOk then
    begin
      Inc(rejectCycles);
      if rejectCycles > MAX_REJECT_CYCLES then Exit;
      ALink.WriteByte(NAK);
    end;
  end;
end;

initialization
  InitCRCTable;

end.
