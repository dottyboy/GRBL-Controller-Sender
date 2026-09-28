unit usettingsmeta;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  // Mirrors grblHAL's external setting_datatype_to_external() enum
  // (settings.h Format_Bool..Format_IPv4) - the datatype field of a
  // machine-readable [SETTING:...] line (report.c report_settings_detail(),
  // SettingsFormat_MachineReadable case).
  TSettingDataType = (
    sdtBool, sdtBitfield, sdtXBitfield, sdtRadioButtons, sdtAxisMask,
    sdtInteger, sdtDecimal, sdtString, sdtPassword, sdtIPv4
  );

  TSettingMeta = record
    ID: Integer;
    GroupID: Integer;
    Name: string;
    Units: string;
    DataType: TSettingDataType;
    FormatRaw: string; // comma-separated option labels for bitfield/choice
                        // types, otherwise a driver-supplied numeric-format
                        // hint string (not parsed further here)
    MinValue: string;
    MaxValue: string;
    RebootRequired: Boolean;
    AllowNull: Boolean;
  end;

  { TSettingMetaMap: holds the parsed $ES ("enumerate settings") response -
    Phase F2, an enrichment layer on top of Phase F's bare $ID/Value grid.
    Simple linear array (not a hash map) since even grblHAL's full setting
    count is a few hundred at most - a per-connection lookup table, not a
    hot path. }
  TSettingMetaMap = class
  private
    FItems: array of TSettingMeta;
    function IndexOf(AID: Integer): Integer;
  public
    procedure Clear;
    function Count: Integer;
    procedure AddOrReplace(const AMeta: TSettingMeta);
    function TryGet(AID: Integer; out AMeta: TSettingMeta): Boolean;
  end;

// Parses one line of a $ES response, e.g.:
//   [SETTING:0|0|Step pulse time|microseconds|6|#0.0|2.0|75|0|0]
// Returns False for anything else, including the related but differently-
// shaped [SETTINGGROUP:...] and [SETTINGDESCR:...] lines (out of scope
// here - group names/long descriptions aren't needed for the grid's
// one-line-per-setting enrichment).
function TryParseSettingDetailLine(const ALine: string; out AMeta: TSettingMeta): Boolean;

// Decodes a bitfield/xbitfield/radiobutton FormatRaw string into a display
// list like "0=Hard limits, 2=Soft limits" - mirrors report.c's
// report_bitfield() exactly, including its quirk that an "N/A" placeholder
// still consumes a bit index (just isn't shown), so real option numbering
// stays correct even when some bits are reserved/unused.
function DescribeBitfieldOptions(const AFormatRaw: string): string;

// One-line human-friendly summary of a setting's type/unit/range/options,
// e.g. "Integer (microseconds), range 2.0 - 75", "Bitfield: 0=Hard limits,
// 2=Soft limits", "Boolean". Used as the grid's new Description column.
function DescribeSettingMeta(const AMeta: TSettingMeta): string;

implementation

{ TSettingMetaMap }

function TSettingMetaMap.IndexOf(AID: Integer): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FItems) do
    if FItems[i].ID = AID then Exit(i);
  Result := -1;
end;

procedure TSettingMetaMap.Clear;
begin
  SetLength(FItems, 0);
end;

function TSettingMetaMap.Count: Integer;
begin
  Result := Length(FItems);
end;

procedure TSettingMetaMap.AddOrReplace(const AMeta: TSettingMeta);
var
  idx: Integer;
begin
  idx := IndexOf(AMeta.ID);
  if idx >= 0 then
    FItems[idx] := AMeta
  else
  begin
    SetLength(FItems, Length(FItems) + 1);
    FItems[High(FItems)] := AMeta;
  end;
end;

function TSettingMetaMap.TryGet(AID: Integer; out AMeta: TSettingMeta): Boolean;
var
  idx: Integer;
begin
  idx := IndexOf(AID);
  Result := idx >= 0;
  if Result then AMeta := FItems[idx];
end;

function TryParseSettingDetailLine(const ALine: string; out AMeta: TSettingMeta): Boolean;
const
  PREFIX = '[SETTING:'; // 9 chars - deliberately excludes [SETTINGGROUP:
                         // and [SETTINGDESCR:, which differ at position 9
                         // ('G'/'D' vs ':')
var
  inner: string;
  parts: TStringArray;
  dt: Integer;
begin
  Result := False;
  FillChar(AMeta, SizeOf(AMeta), 0);
  AMeta.DataType := sdtInteger;

  if (Length(ALine) < Length(PREFIX) + 1) or
     (Copy(ALine, 1, Length(PREFIX)) <> PREFIX) or
     (ALine[Length(ALine)] <> ']') then
    Exit;

  inner := Copy(ALine, Length(PREFIX) + 1, Length(ALine) - Length(PREFIX) - 1);
  parts := inner.Split('|');
  if Length(parts) < 3 then Exit; // need at least id|group|name

  AMeta.ID := StrToIntDef(parts[0], -1);
  if AMeta.ID < 0 then Exit;

  AMeta.GroupID := StrToIntDef(parts[1], 0);
  AMeta.Name := parts[2];
  if Length(parts) > 3 then AMeta.Units := parts[3];
  if Length(parts) > 4 then
  begin
    dt := StrToIntDef(parts[4], Ord(sdtInteger));
    if (dt >= Ord(sdtBool)) and (dt <= Ord(sdtIPv4)) then
      AMeta.DataType := TSettingDataType(dt);
  end;
  if Length(parts) > 5 then AMeta.FormatRaw := parts[5];
  if Length(parts) > 6 then AMeta.MinValue := parts[6];
  if Length(parts) > 7 then AMeta.MaxValue := parts[7];
  if Length(parts) > 8 then AMeta.RebootRequired := parts[8] = '1';
  if Length(parts) > 9 then AMeta.AllowNull := parts[9] = '1';

  Result := True;
end;

function DescribeBitfieldOptions(const AFormatRaw: string): string;
var
  elements: TStringArray;
  i, bit: Integer;
begin
  Result := '';
  if AFormatRaw = '' then Exit;
  elements := AFormatRaw.Split(',');
  bit := 0;
  for i := 0 to High(elements) do
  begin
    if elements[i] <> 'N/A' then
    begin
      if Result <> '' then Result := Result + ', ';
      Result := Result + IntToStr(bit) + '=' + elements[i];
    end;
    Inc(bit); // N/A still consumes a bit index - matches report_bitfield()
  end;
end;

function DescribeSettingMeta(const AMeta: TSettingMeta): string;
var
  typeStr, rangeStr, optsStr: string;
begin
  case AMeta.DataType of
    sdtBool: typeStr := 'Boolean';
    sdtBitfield: typeStr := 'Bitfield';
    sdtXBitfield: typeStr := 'Bitfield (bit 0 enables rest)';
    sdtRadioButtons: typeStr := 'Choice';
    sdtAxisMask: typeStr := 'Axis mask';
    sdtInteger: typeStr := 'Integer';
    sdtDecimal: typeStr := 'Decimal';
    sdtString: typeStr := 'String';
    sdtPassword: typeStr := 'Password';
    sdtIPv4: typeStr := 'IPv4 address';
  else
    typeStr := 'Value';
  end;

  Result := typeStr;
  if AMeta.Units <> '' then
    Result := Result + ' (' + AMeta.Units + ')';

  if AMeta.DataType in [sdtBitfield, sdtXBitfield, sdtRadioButtons] then
  begin
    optsStr := DescribeBitfieldOptions(AMeta.FormatRaw);
    if optsStr <> '' then
      Result := Result + ': ' + optsStr;
  end
  else if (AMeta.MinValue <> '') or (AMeta.MaxValue <> '') then
  begin
    if (AMeta.MinValue <> '') and (AMeta.MaxValue <> '') then
      rangeStr := AMeta.MinValue + ' - ' + AMeta.MaxValue
    else if AMeta.MinValue <> '' then
      rangeStr := 'min ' + AMeta.MinValue
    else
      rangeStr := 'max ' + AMeta.MaxValue;
    Result := Result + ', range ' + rangeStr;
  end;

  if AMeta.RebootRequired then
    Result := Result + ' [reboot required]';
end;

end.
