unit uspoilboardframe;

{ TSpoilboardFrame: parametric spoilboard-preparation UI - facing/surfacing,
  peg-hole grid, T-track channels. "Generate G-Code" builds a program from
  the current fields (see uspoilboard.pas for the actual math) and loads it
  into the app's existing G-code editor tab for review/sending - that part
  never talks to the controller directly. Named profiles (save/load/delete)
  persist via uspoilboardstore.pas so a repeat blank spoilboard's settings
  don't need re-entering.

  The one part that DOES talk to the controller: "Send Travel Limits"
  writes the selected machine preset's $130/$131/$132 (max travel, mm) so
  soft-limits/homing math on the controller matches the real machine. It
  never touches $20/$22 (soft-limits/homing enable) - whether those should
  be on depends on whether limit switches are actually wired on this
  specific unit, which a catalog entry can't know, so that stays a manual,
  deliberate choice in the Settings ($$) tab. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  Grids, Dialogs, uspoilboard, uspoilboardstore, umachinecatalog, usender,
  ui18n;

const
  TCOL_ORIENT = 0;
  TCOL_POSITION = 1;
  TCOL_WIDTH = 2;
  TCOL_DEPTH = 3;
  TCOL_STARTMARGIN = 4;
  TCOL_ENDMARGIN = 5;

type

  { TOnGenerated: fired after a program is successfully built, so umain.pas
    can push it into the editor/3D view without this frame needing to know
    about either. }
  TOnGenerated = procedure(const AProgramText: string) of object;

  { TSpoilboardFrame }

  TSpoilboardFrame = class(TFrame)
    BtnGenerate: TButton;
    BtnProfileSave: TButton;
    BtnProfileLoad: TButton;
    BtnProfileDelete: TButton;
    BtnTrackAdd: TButton;
    BtnTrackDelete: TButton;
    BtnMachineApply: TButton;
    BtnSendLimits: TButton;
    CbProfile: TComboBox;
    CbMachinePreset: TComboBox;
    TopBar: TPanel;
    BottomBar: TPanel;
    ScrollBox1: TScrollBox;
    ChkFacingEnabled: TCheckBox;
    ChkFacingRowsAlongX: TCheckBox;
    ChkHolesEnabled: TCheckBox;
    ChkHoleStaggered: TCheckBox;
    EdWorkWidthX: TEdit;
    EdWorkHeightY: TEdit;
    EdSafeZ: TEdit;
    EdFacingToolDiameter: TEdit;
    EdFacingStepoverPercent: TEdit;
    EdFacingDepthPerPass: TEdit;
    EdFacingTotalDepth: TEdit;
    EdFacingFeedRate: TEdit;
    EdFacingPlungeRate: TEdit;
    EdFacingSpindleRPM: TEdit;
    EdHoleDiameter: TEdit;
    EdHoleMarginX: TEdit;
    EdHoleMarginY: TEdit;
    EdHoleSpacingX: TEdit;
    EdHoleSpacingY: TEdit;
    EdHoleDrillDepth: TEdit;
    EdHolePeckDepth: TEdit;
    EdHolePlungeRate: TEdit;
    EdTrackToolDiameter: TEdit;
    EdTrackStepoverPercent: TEdit;
    EdTrackFeedRate: TEdit;
    EdTrackPlungeRate: TEdit;
    LblStatus: TLabel;
    LblMachineInfo: TLabel;
    TrackGrid: TStringGrid;
    procedure BtnGenerateClick(Sender: TObject);
    procedure BtnProfileSaveClick(Sender: TObject);
    procedure BtnProfileLoadClick(Sender: TObject);
    procedure BtnProfileDeleteClick(Sender: TObject);
    procedure BtnTrackAddClick(Sender: TObject);
    procedure BtnTrackDeleteClick(Sender: TObject);
    procedure BtnMachineApplyClick(Sender: TObject);
    procedure BtnSendLimitsClick(Sender: TObject);
  private
    FStore: TSpoilboardStore;
    FSender: TSender;
    FOnGenerated: TOnGenerated;
    function BuildConfigFromFields: TSpoilboardConfig;
    procedure ApplyConfigToFields(const ACfg: TSpoilboardConfig);
    procedure RefreshProfileList;
    procedure SetStatus(const AMsg: string; AIsError: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetSender(ASender: TSender);
    property OnGenerated: TOnGenerated read FOnGenerated write FOnGenerated;
  end;

implementation

{$R *.frm}

{ TSpoilboardFrame }

constructor TSpoilboardFrame.Create(AOwner: TComponent);
var
  i: Integer;
  cat: TMachineProfileArray;
begin
  inherited Create(AOwner);
  FStore := TSpoilboardStore.Create;

  cat := MachineCatalog;
  CbMachinePreset.Items.BeginUpdate;
  try
    CbMachinePreset.Items.Clear;
    for i := 0 to High(cat) do
      CbMachinePreset.Items.Add(cat[i].DisplayName);
  finally
    CbMachinePreset.Items.EndUpdate;
  end;

  TrackGrid.Cells[TCOL_ORIENT, 0] := 'H/V';
  TrackGrid.Cells[TCOL_POSITION, 0] := 'Position';
  TrackGrid.Cells[TCOL_WIDTH, 0] := 'Width';
  TrackGrid.Cells[TCOL_DEPTH, 0] := 'Depth';
  TrackGrid.Cells[TCOL_STARTMARGIN, 0] := 'Start margin';
  TrackGrid.Cells[TCOL_ENDMARGIN, 0] := 'End margin';
  ApplyConfigToFields(DefaultSpoilboardConfig);
  RefreshProfileList;
end;

destructor TSpoilboardFrame.Destroy;
begin
  FStore.Free;
  inherited Destroy;
end;

procedure TSpoilboardFrame.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
end;

procedure TSpoilboardFrame.RefreshProfileList;
var
  names: TStringList;
  keep: string;
begin
  keep := CbProfile.Text;
  names := TStringList.Create;
  try
    FStore.ListProfileNames(names);
    CbProfile.Items.Assign(names);
  finally
    names.Free;
  end;
  CbProfile.Text := keep;
end;

function TSpoilboardFrame.BuildConfigFromFields: TSpoilboardConfig;
var
  i: Integer;
  t: TTTrackDef;
begin
  Result := DefaultSpoilboardConfig;

  Result.WorkWidthX := StrToFloatDef(EdWorkWidthX.Text, Result.WorkWidthX);
  Result.WorkHeightY := StrToFloatDef(EdWorkHeightY.Text, Result.WorkHeightY);
  Result.SafeZ := StrToFloatDef(EdSafeZ.Text, Result.SafeZ);

  Result.FacingEnabled := ChkFacingEnabled.Checked;
  Result.FacingToolDiameter := StrToFloatDef(EdFacingToolDiameter.Text, Result.FacingToolDiameter);
  Result.FacingStepoverPercent := StrToFloatDef(EdFacingStepoverPercent.Text, Result.FacingStepoverPercent);
  Result.FacingDepthPerPass := StrToFloatDef(EdFacingDepthPerPass.Text, Result.FacingDepthPerPass);
  Result.FacingTotalDepth := StrToFloatDef(EdFacingTotalDepth.Text, Result.FacingTotalDepth);
  Result.FacingFeedRate := StrToFloatDef(EdFacingFeedRate.Text, Result.FacingFeedRate);
  Result.FacingPlungeRate := StrToFloatDef(EdFacingPlungeRate.Text, Result.FacingPlungeRate);
  Result.FacingSpindleRPM := StrToIntDef(EdFacingSpindleRPM.Text, Result.FacingSpindleRPM);
  Result.FacingRowsAlongX := ChkFacingRowsAlongX.Checked;

  Result.HolesEnabled := ChkHolesEnabled.Checked;
  Result.HoleDiameter := StrToFloatDef(EdHoleDiameter.Text, Result.HoleDiameter);
  Result.HoleMarginX := StrToFloatDef(EdHoleMarginX.Text, Result.HoleMarginX);
  Result.HoleMarginY := StrToFloatDef(EdHoleMarginY.Text, Result.HoleMarginY);
  Result.HoleSpacingX := StrToFloatDef(EdHoleSpacingX.Text, Result.HoleSpacingX);
  Result.HoleSpacingY := StrToFloatDef(EdHoleSpacingY.Text, Result.HoleSpacingY);
  Result.HoleStaggered := ChkHoleStaggered.Checked;
  Result.HoleDrillDepth := StrToFloatDef(EdHoleDrillDepth.Text, Result.HoleDrillDepth);
  Result.HolePeckDepth := StrToFloatDef(EdHolePeckDepth.Text, Result.HolePeckDepth);
  Result.HolePlungeRate := StrToFloatDef(EdHolePlungeRate.Text, Result.HolePlungeRate);

  Result.TrackToolDiameter := StrToFloatDef(EdTrackToolDiameter.Text, Result.TrackToolDiameter);
  Result.TrackStepoverPercent := StrToFloatDef(EdTrackStepoverPercent.Text, Result.TrackStepoverPercent);
  Result.TrackFeedRate := StrToFloatDef(EdTrackFeedRate.Text, Result.TrackFeedRate);
  Result.TrackPlungeRate := StrToFloatDef(EdTrackPlungeRate.Text, Result.TrackPlungeRate);

  SetLength(Result.Tracks, 0);
  for i := 1 to TrackGrid.RowCount - 1 do
  begin
    if Trim(TrackGrid.Cells[TCOL_POSITION, i]) = '' then Continue;
    if UpperCase(Trim(TrackGrid.Cells[TCOL_ORIENT, i])) = 'V' then
      t.Orientation := toVertical
    else
      t.Orientation := toHorizontal;
    t.Position := StrToFloatDef(TrackGrid.Cells[TCOL_POSITION, i], 0);
    t.Width := StrToFloatDef(TrackGrid.Cells[TCOL_WIDTH, i], 0);
    t.Depth := StrToFloatDef(TrackGrid.Cells[TCOL_DEPTH, i], 0);
    t.StartMargin := StrToFloatDef(TrackGrid.Cells[TCOL_STARTMARGIN, i], 0);
    t.EndMargin := StrToFloatDef(TrackGrid.Cells[TCOL_ENDMARGIN, i], 0);
    SetLength(Result.Tracks, Length(Result.Tracks) + 1);
    Result.Tracks[High(Result.Tracks)] := t;
  end;
end;

procedure TSpoilboardFrame.ApplyConfigToFields(const ACfg: TSpoilboardConfig);
var
  i, c: Integer;
begin
  EdWorkWidthX.Text := FloatToStr(ACfg.WorkWidthX);
  EdWorkHeightY.Text := FloatToStr(ACfg.WorkHeightY);
  EdSafeZ.Text := FloatToStr(ACfg.SafeZ);

  ChkFacingEnabled.Checked := ACfg.FacingEnabled;
  EdFacingToolDiameter.Text := FloatToStr(ACfg.FacingToolDiameter);
  EdFacingStepoverPercent.Text := FloatToStr(ACfg.FacingStepoverPercent);
  EdFacingDepthPerPass.Text := FloatToStr(ACfg.FacingDepthPerPass);
  EdFacingTotalDepth.Text := FloatToStr(ACfg.FacingTotalDepth);
  EdFacingFeedRate.Text := FloatToStr(ACfg.FacingFeedRate);
  EdFacingPlungeRate.Text := FloatToStr(ACfg.FacingPlungeRate);
  EdFacingSpindleRPM.Text := IntToStr(ACfg.FacingSpindleRPM);
  ChkFacingRowsAlongX.Checked := ACfg.FacingRowsAlongX;

  ChkHolesEnabled.Checked := ACfg.HolesEnabled;
  EdHoleDiameter.Text := FloatToStr(ACfg.HoleDiameter);
  EdHoleMarginX.Text := FloatToStr(ACfg.HoleMarginX);
  EdHoleMarginY.Text := FloatToStr(ACfg.HoleMarginY);
  EdHoleSpacingX.Text := FloatToStr(ACfg.HoleSpacingX);
  EdHoleSpacingY.Text := FloatToStr(ACfg.HoleSpacingY);
  ChkHoleStaggered.Checked := ACfg.HoleStaggered;
  EdHoleDrillDepth.Text := FloatToStr(ACfg.HoleDrillDepth);
  EdHolePeckDepth.Text := FloatToStr(ACfg.HolePeckDepth);
  EdHolePlungeRate.Text := FloatToStr(ACfg.HolePlungeRate);

  EdTrackToolDiameter.Text := FloatToStr(ACfg.TrackToolDiameter);
  EdTrackStepoverPercent.Text := FloatToStr(ACfg.TrackStepoverPercent);
  EdTrackFeedRate.Text := FloatToStr(ACfg.TrackFeedRate);
  EdTrackPlungeRate.Text := FloatToStr(ACfg.TrackPlungeRate);

  TrackGrid.RowCount := Length(ACfg.Tracks) + 1;
  if TrackGrid.RowCount < 2 then TrackGrid.RowCount := 2;
  for i := 1 to TrackGrid.RowCount - 1 do
    for c := TCOL_ORIENT to TCOL_ENDMARGIN do
      TrackGrid.Cells[c, i] := '';
  for i := 0 to High(ACfg.Tracks) do
  begin
    if ACfg.Tracks[i].Orientation = toHorizontal then
      TrackGrid.Cells[TCOL_ORIENT, i + 1] := 'H'
    else
      TrackGrid.Cells[TCOL_ORIENT, i + 1] := 'V';
    TrackGrid.Cells[TCOL_POSITION, i + 1] := FloatToStr(ACfg.Tracks[i].Position);
    TrackGrid.Cells[TCOL_WIDTH, i + 1] := FloatToStr(ACfg.Tracks[i].Width);
    TrackGrid.Cells[TCOL_DEPTH, i + 1] := FloatToStr(ACfg.Tracks[i].Depth);
    TrackGrid.Cells[TCOL_STARTMARGIN, i + 1] := FloatToStr(ACfg.Tracks[i].StartMargin);
    TrackGrid.Cells[TCOL_ENDMARGIN, i + 1] := FloatToStr(ACfg.Tracks[i].EndMargin);
  end;
end;

procedure TSpoilboardFrame.BtnTrackAddClick(Sender: TObject);
begin
  TrackGrid.RowCount := TrackGrid.RowCount + 1;
  TrackGrid.Cells[TCOL_ORIENT, TrackGrid.RowCount - 1] := 'H';
end;

procedure TSpoilboardFrame.BtnTrackDeleteClick(Sender: TObject);
var
  r: Integer;
begin
  r := TrackGrid.Row;
  if (r < 1) or (TrackGrid.RowCount <= 2) then Exit;
  TrackGrid.DeleteRow(r);
end;

procedure TSpoilboardFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
end;

procedure TSpoilboardFrame.BtnSendLimitsClick(Sender: TObject);
var
  profile: TMachineProfile;
  sent: string;
begin
  if not FindMachineProfile(CbMachinePreset.Text, profile) then
  begin
    SetStatus(T('Select a machine from the list before sending limits.'), True);
    Exit;
  end;
  if (FSender = nil) or (not FSender.Connected) then
  begin
    SetStatus(T('Not connected - connect to the controller before sending $130/$131/$132.'), True);
    Exit;
  end;

  FSender.WriteSetting('130', FormatFloat('0.000', profile.TravelX));
  FSender.WriteSetting('131', FormatFloat('0.000', profile.TravelY));
  sent := '$130, $131';
  if profile.TravelZ > 0 then
  begin
    FSender.WriteSetting('132', FormatFloat('0.000', profile.TravelZ));
    sent := sent + ', $132';
  end;
  SetStatus(Format(T('Sent %s to "%s" ($20/$22 untouched - enable soft limits/homing manually in Settings ($$) if the machine has limit switches wired).'),
    [sent, profile.DisplayName]), False);
end;

procedure TSpoilboardFrame.BtnMachineApplyClick(Sender: TObject);
var
  profile: TMachineProfile;
  zText, infoText: string;
begin
  if not FindMachineProfile(CbMachinePreset.Text, profile) then
  begin
    SetStatus(T('Select a machine from the list before applying.'), True);
    Exit;
  end;

  // Only Work X/Y come from the machine (its usable travel = the largest
  // spoilboard blank that fits) - SafeZ and every facing/hole/track
  // parameter stay whatever the user already set, those depend on the
  // tool and the job, not the machine.
  EdWorkWidthX.Text := FloatToStr(profile.TravelX);
  EdWorkHeightY.Text := FloatToStr(profile.TravelY);

  if profile.TravelZ > 0 then
    zText := FormatFloat('0.#', profile.TravelZ) + ' mm'
  else
    zText := T('not published');

  // The template/labels are translated; the catalog's own free-text data
  // (Manufacturer/Controller/Notes/DriveNote) stays as authored (Croatian)
  // - translating the whole machine database into 3 languages is a
  // separate, much larger task than the UI chrome, not attempted here.
  infoText := Format(T('Manufacturer: %s. Z travel: %s. Drive: %s%s. Controller: %s.'),
    [profile.Manufacturer, zText, DriveTypeName(profile.Drive),
     IfThen(profile.DriveNote <> '', ' (' + profile.DriveNote + ')', ''),
     profile.Controller]);
  if profile.Notes <> '' then
    infoText := infoText + ' ' + T('Note:') + ' ' + profile.Notes;
  LblMachineInfo.Caption := infoText;

  SetStatus(Format(T('Work area filled from "%s".'), [profile.DisplayName]), False);
end;

procedure TSpoilboardFrame.BtnGenerateClick(Sender: TObject);
var
  cfg: TSpoilboardConfig;
  lines: TStringList;
begin
  cfg := BuildConfigFromFields;
  lines := TStringList.Create;
  try
    try
      BuildSpoilboardProgram(cfg, lines);
      SetStatus(Format('Generated %d lines.', [lines.Count]), False);
      if Assigned(FOnGenerated) then
        FOnGenerated(lines.Text);
    except
      on E: EGenerateError do
        SetStatus(E.Message, True);
    end;
  finally
    lines.Free;
  end;
end;

procedure TSpoilboardFrame.BtnProfileSaveClick(Sender: TObject);
var
  profileName: string;
begin
  profileName := Trim(CbProfile.Text);
  if profileName = '' then
  begin
    SetStatus('Enter a profile name first.', True);
    Exit;
  end;
  FStore.Save(profileName, BuildConfigFromFields);
  RefreshProfileList;
  SetStatus('Profile "' + profileName + '" saved.', False);
end;

procedure TSpoilboardFrame.BtnProfileLoadClick(Sender: TObject);
var
  profileName: string;
  cfg: TSpoilboardConfig;
begin
  profileName := Trim(CbProfile.Text);
  if profileName = '' then Exit;
  if FStore.Load(profileName, cfg) then
  begin
    ApplyConfigToFields(cfg);
    SetStatus('Profile "' + profileName + '" loaded.', False);
  end
  else
    SetStatus('Profile "' + profileName + '" not found.', True);
end;

procedure TSpoilboardFrame.BtnProfileDeleteClick(Sender: TObject);
var
  profileName: string;
begin
  profileName := Trim(CbProfile.Text);
  if profileName = '' then Exit;
  FStore.Delete(profileName);
  RefreshProfileList;
  CbProfile.Text := '';
  SetStatus('Profile "' + profileName + '" deleted.', False);
end;

end.
