unit uwificonfigform;

{ TWiFiConfigForm: the plan's own Phase 21 "WiFi discovery/config" wizard,
  built in the order the plan's own 2nd-wave scope note calls for -
  direct host:port connect first (cheap, high value, works today against
  any already-configured ESP32/grblHAL board), then the LAN scan and the
  write-config helper as secondary, harder-to-verify-without-real-
  hardware add-ons.

  - "Use This Connection" builds the userial.pas "tcp:host:port" device
    string and hands it back to the caller (uconnectframe.pas), which
    fills it into the existing Port field - reuses the whole existing
    connect machinery unchanged, no new connection path in usender.pas.
  - "Scan" runs uwifidiscovery.pas's ScanSubnet on a worker TThread (this
    form's own small TScanThread, mirroring usender.pas's own
    TSenderThread/Synchronize discipline) so the UI stays responsive;
    results feed "Use Selected Result" back into the Host field.
  - "Write Config" sends uwificonfig.pas's real command sequence through
    the ALREADY-CONNECTED FSender (only meaningful while connected via
    real USB serial to begin with - the assigned-IP reply is best watched
    on the existing Terminal tab, not duplicated here, since this dialog
    doesn't own a second serial-reading path).

  A modal using only TEdit/TComboBox/TListBox/TButton controls - no
  TStringGrid (this codebase's own established Phase-14-crash-class
  avoidance for freshly-created modals). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, StdCtrls, Dialogs,
  userial, utcpdevice, uwifidiscovery, uwificonfig, usender, ui18n, ui18ncontrols;

type

  { TScanThread: runs ScanSubnet off the UI thread, Synchronizing each
    found result / progress tick back - same discipline as
    usender.pas's own TSenderThread. }
  TScanThread = class(TThread)
  private
    FBaseIP, FSubnetMask: string;
    FPort, FTimeoutMs: Integer;
    FOwner: TObject; // TWiFiConfigForm, typed as TObject to avoid a circular class reference
    FPendingResult: TDiscoveryResult;
    FPendingDone, FPendingTotal: Integer;
    procedure SyncFound;
    procedure SyncProgress;
    procedure SyncFinished;
    procedure DoFound(const AResult: TDiscoveryResult);
    procedure DoProgress(ADone, ATotal: Integer);
    function DoCancel: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TObject; const ABaseIP, ASubnetMask: string; APort, ATimeoutMs: Integer);
  end;

  { TWiFiConfigForm }

  TWiFiConfigForm = class(TForm)
    BtnClose: TButton;
    BtnDirectConnect: TButton;
    BtnScan: TButton;
    BtnStopScan: TButton;
    BtnUseSelected: TButton;
    BtnWriteConfig: TButton;
    CbBoardKind: TComboBox;
    EdBaseIP: TEdit;
    EdHost: TEdit;
    EdPort: TEdit;
    EdSSID: TEdit;
    EdSubnetMask: TEdit;
    EdWiFiPassword: TEdit;
    LbResults: TListBox;
    LblBaseIP: TLabel;
    LblConfigHeader: TLabel;
    LblConfigNote: TLabel;
    LblDirectHeader: TLabel;
    LblHost: TLabel;
    LblPort: TLabel;
    LblScanHeader: TLabel;
    LblScanProgress: TLabel;
    LblSSID: TLabel;
    LblSubnetMask: TLabel;
    LblWiFiPassword: TLabel;
    procedure BtnDirectConnectClick(Sender: TObject);
    procedure BtnScanClick(Sender: TObject);
    procedure BtnStopScanClick(Sender: TObject);
    procedure BtnUseSelectedClick(Sender: TObject);
    procedure BtnWriteConfigClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure LbResultsSelectionChange(Sender: TObject; User: Boolean);
  private
    FSender: TSender;
    FScanThread: TScanThread;
    FScanCancelled: Boolean;
    FResults: array of TDiscoveryResult;
    FDeviceString: string; // result for the caller - '' if the dialog was just closed
    procedure ScanFinished;
  public
    // Shows the dialog. Returns the "tcp:host:port" device string to
    // connect with if the user clicked "Use This Connection" or "Use
    // Selected Result" (either sets it and closes), '' if they just
    // closed the dialog without picking anything. ASender, if not nil,
    // enables the "Write Config" section (needs an already-open
    // connection to actually send anything).
    class function Execute(ASender: TSender): string;
  end;

implementation

{$R *.frm}

{ TScanThread }

constructor TScanThread.Create(AOwner: TObject; const ABaseIP, ASubnetMask: string; APort, ATimeoutMs: Integer);
begin
  FOwner := AOwner;
  FBaseIP := ABaseIP;
  FSubnetMask := ASubnetMask;
  FPort := APort;
  FTimeoutMs := ATimeoutMs;
  inherited Create(False);
end;

procedure TScanThread.SyncFound;
var
  frm: TWiFiConfigForm;
begin
  frm := FOwner as TWiFiConfigForm;
  SetLength(frm.FResults, Length(frm.FResults) + 1);
  frm.FResults[High(frm.FResults)] := FPendingResult;
  frm.LbResults.Items.Add(Format('%s%s (port %d)', [FPendingResult.IP,
    IfThen(FPendingResult.HostName <> '', ' - ' + FPendingResult.HostName, ''), FPendingResult.Port]));
end;

procedure TScanThread.SyncProgress;
var
  frm: TWiFiConfigForm;
begin
  frm := FOwner as TWiFiConfigForm;
  frm.LblScanProgress.Caption := Format(T('Scanning: %d / %d'), [FPendingDone, FPendingTotal]);
end;

procedure TScanThread.SyncFinished;
begin
  (FOwner as TWiFiConfigForm).ScanFinished;
end;

procedure TScanThread.DoFound(const AResult: TDiscoveryResult);
begin
  FPendingResult := AResult;
  Synchronize(@SyncFound);
end;

procedure TScanThread.DoProgress(ADone, ATotal: Integer);
begin
  FPendingDone := ADone;
  FPendingTotal := ATotal;
  Synchronize(@SyncProgress);
end;

function TScanThread.DoCancel: Boolean;
begin
  Result := Terminated or (FOwner as TWiFiConfigForm).FScanCancelled;
end;

procedure TScanThread.Execute;
begin
  ScanSubnet(FBaseIP, FSubnetMask, FPort, 300, @DoFound, @DoProgress, @DoCancel);
  Synchronize(@SyncFinished);
end;

{ TWiFiConfigForm }

procedure TWiFiConfigForm.FormCreate(Sender: TObject);
begin
  TranslateControls(Self);
  CbBoardKind.Items.Clear;
  CbBoardKind.Items.Add('Ortur');
  CbBoardKind.Items.Add('Longer');
  CbBoardKind.ItemIndex := 0;
  EdPort.Text := '23';
  BtnWriteConfig.Enabled := (FSender <> nil) and FSender.Connected;
end;

procedure TWiFiConfigForm.FormDestroy(Sender: TObject);
begin
  if FScanThread <> nil then
  begin
    FScanCancelled := True;
    FScanThread.WaitFor;
    FScanThread.Free;
  end;
end;

procedure TWiFiConfigForm.BtnDirectConnectClick(Sender: TObject);
var
  host: string;
  port: Integer;
begin
  host := Trim(EdHost.Text);
  port := StrToIntDef(Trim(EdPort.Text), 0);
  if (host = '') or (port <= 0) or (port > 65535) then
  begin
    ShowMessage(T('Enter a valid host and port first.'));
    Exit;
  end;
  FDeviceString := TCP_DEVICE_PREFIX + host + ':' + IntToStr(port);
  ModalResult := mrOK;
end;

procedure TWiFiConfigForm.BtnScanClick(Sender: TObject);
var
  port: Integer;
begin
  if Trim(EdBaseIP.Text) = '' then
  begin
    ShowMessage(T('Enter a base IP on your local network first (e.g. 192.168.1.50).'));
    Exit;
  end;
  // A previous scan's thread object (if any - Scan is disabled while one
  // is actually running, so this only ever fires once that one has
  // already finished and called ScanFinished) is only ever freed here,
  // never inside ScanFinished itself - freeing it from code the thread
  // itself Synchronize()'d into would be freeing its own still-executing
  // stack frame's owner (see uprocessrunner.pas's own documented real
  // bug from the Firmware Builder initiative: FreeOnTerminate combined
  // with a manual Free is exactly this double-free/dangling-pointer
  // class of mistake - avoided here by never setting FreeOnTerminate and
  // always freeing from a DIFFERENT call stack than the thread's own).
  if FScanThread <> nil then
  begin
    FScanThread.WaitFor;
    FreeAndNil(FScanThread);
  end;

  port := StrToIntDef(Trim(EdPort.Text), 23);
  LbResults.Items.Clear;
  SetLength(FResults, 0);
  BtnUseSelected.Enabled := False;
  FScanCancelled := False;
  BtnScan.Enabled := False;
  BtnStopScan.Enabled := True;
  LblScanProgress.Caption := T('Scanning...');
  FScanThread := TScanThread.Create(Self, Trim(EdBaseIP.Text), Trim(EdSubnetMask.Text), port, 300);
end;

procedure TWiFiConfigForm.BtnStopScanClick(Sender: TObject);
begin
  FScanCancelled := True;
  BtnStopScan.Enabled := False;
  LblScanProgress.Caption := T('Stopping...');
end;

procedure TWiFiConfigForm.ScanFinished;
begin
  // Deliberately does NOT touch FScanThread itself (no nil-ing, no Free) -
  // this runs via Synchronize from INSIDE the thread's own Execute, right
  // before Execute returns; freeing the thread object from its own still-
  // executing call stack would be a use-after-free the moment Execute's
  // remaining cleanup ran. The thread object is only ever freed later,
  // from a different call stack (the next BtnScanClick, or FormDestroy) -
  // see BtnScanClick's own comment on this exact hazard.
  BtnScan.Enabled := True;
  BtnStopScan.Enabled := False;
  if FScanCancelled then
    LblScanProgress.Caption := T('Scan aborted')
  else
    LblScanProgress.Caption := Format(T('Scan finished - %d found'), [Length(FResults)]);
end;

procedure TWiFiConfigForm.LbResultsSelectionChange(Sender: TObject; User: Boolean);
begin
  BtnUseSelected.Enabled := LbResults.ItemIndex >= 0;
end;

procedure TWiFiConfigForm.BtnUseSelectedClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := LbResults.ItemIndex;
  if (idx < 0) or (idx > High(FResults)) then Exit;
  EdHost.Text := FResults[idx].IP;
  EdPort.Text := IntToStr(FResults[idx].Port);
end;

procedure TWiFiConfigForm.BtnWriteConfigClick(Sender: TObject);
var
  kind: TWiFiBoardKind;
  cmds: TStringList;
  i: Integer;
begin
  if (FSender = nil) or (not FSender.Connected) then
  begin
    ShowMessage(T('Not connected - connect via USB serial first, then write WiFi credentials over that connection.'));
    Exit;
  end;
  if (Trim(EdSSID.Text) = '') or (Trim(EdWiFiPassword.Text) = '') then
  begin
    ShowMessage(T('Enter both SSID and password first.'));
    Exit;
  end;
  if CbBoardKind.ItemIndex = 1 then kind := wbkLonger else kind := wbkOrtur;

  cmds := TStringList.Create;
  try
    BuildWiFiConfigCommands(kind, Trim(EdSSID.Text), Trim(EdWiFiPassword.Text), cmds);
    for i := 0 to cmds.Count - 1 do
      FSender.EnqueueGCode(cmds[i]);
  finally
    cmds.Free;
  end;
  ShowMessage(T('WiFi config commands sent - watch the Terminal tab for the assigned IP once the board reconnects.'));
end;

class function TWiFiConfigForm.Execute(ASender: TSender): string;
var
  frm: TWiFiConfigForm;
begin
  Result := '';
  frm := TWiFiConfigForm.Create(Application);
  try
    frm.FSender := ASender;
    frm.BtnWriteConfig.Enabled := (ASender <> nil) and ASender.Connected;
    if frm.ShowModal = mrOK then
      Result := frm.FDeviceString;
  finally
    frm.Free;
  end;
end;

end.
