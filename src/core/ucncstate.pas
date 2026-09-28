unit ucncstate;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uboardinfo, usettingsmeta;

const
  // Ordered list of work coordinate systems, mirrors bCNC's WCS in CNC.py
  WCS: array[0..8] of string = (
    'G54', 'G55', 'G56', 'G57', 'G58', 'G59', 'G28', 'G30', 'G92'
  );

type
  { TCNCState mirrors bCNC's CNC.vars dict (CNC.py ~line 680), as a typed
    class instead of a dynamic dict. Only fields needed through Phase 1-4
    are included; extend as later phases need more of CNC.vars. }
  TCNCState = class
  public
    // Machine position (absolute, from GRBL status reports)
    MX, MY, MZ, MA, MB, MC: Double;
    // Work position (MPos - WCO)
    WX, WY, WZ, WA, WB, WC: Double;
    // Work coordinate offset (WCO)
    WCOX, WCOY, WCOZ, WCOA, WCOB, WCOC: Double;
    // Probe result position
    PRBX, PRBY, PRBZ: Double;
    PrbCmd: string;
    PrbFeed: Double;
    ErrLine: string;

    // Modal state (GCode.py MODAL_MODES targets)
    Motion: string;      // G0/G1/G2/G3/G38.2/G80...
    WCSMode: string;      // G54..G59
    Plane: string;        // G17/G18/G19
    FeedMode: string;     // G93/G94
    Distance: string;     // G90/G91
    ArcMode: string;      // G91.1
    Units: string;        // G20/G21
    Cutter: string;
    TLOMode: string;
    ProgState: string;    // M0/M1/M2/M30
    Spindle: string;      // M3/M4/M5
    Coolant: string;      // M7/M8/M9

    Tool: Integer;
    Feed: Double;
    RPM: Double;
    Planner: Integer;
    RxBytes: Integer;
    CurFeed: Double;
    CurSpindle: Double;

    // Overrides (percent)
    OvFeed, OvRapid, OvSpindle: Integer;
    OvChanged: Boolean;
    TargetOvFeed, TargetOvRapid, TargetOvSpindle: Integer;

    TLO: Double;

    // Connection/run state
    StateStr: string;      // Idle/Run/Hold/Alarm/... (raw GRBL state field)
    Pins: string;
    Msg: string;
    Version: string;
    Controller: string;    // '', 'GRBL0', 'GRBL1', 'SMOOTHIE', 'G2CORE'
    Running: Boolean;
    // Board/firmware identity from $I - per-connection, so it lives here in
    // the live-status group (reset on reconnect), not the config group below.
    BoardInfo: TBoardInfo;
    // Raw $N=value settings dump (Phase F) - Name=ID, Value=raw string, e.g.
    // Settings.Values['130']. Per-connection like BoardInfo (a different
    // board may report different values), not the config group below.
    Settings: TStringList;
    // Parsed $ES ("enumerate settings") response (Phase F2) - name/unit/
    // type/range/options per setting ID, grblHAL-only. Per-connection like
    // Settings above.
    SettingsMeta: TSettingMetaMap;

    // Machine limits/config (bCNC.ini [CNC]/[Connection] equivalents).
    // NOT touched by Reset() - these are user-configured (via uconfig.pas/
    // the settings dialog) and must survive a reconnect, unlike the live
    // status fields above which genuinely reset on every new connection.
    Safe: Double;
    Diameter: Double;
    CutFeed: Double;
    CutFeedZ: Double;
    TravelX, TravelY, TravelZ: Double;       // CNC.py travel_x/y/z
    FeedMaxX, FeedMaxY, FeedMaxZ: Double;     // CNC.py feedmax_x/y/z
    AccelX, AccelY, AccelZ: Double;           // CNC.py acceleration_x/y/z
    StartupGCode: string;                     // CNC.py startup ('G90')
    GangedAxes: string;                       // user-declared, e.g. '', 'Y', 'XY' -
                                               // which axes have a 2nd, auto-squared
                                               // motor (see uboardinfo's SupportsGanging
                                               // for the firmware CAPABILITY flag, vs.
                                               // this which is WHICH axes actually do)

    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    procedure ResetConfigDefaults;
  end;

implementation

constructor TCNCState.Create;
begin
  inherited Create;
  BoardInfo := TBoardInfo.Create;
  Settings := TStringList.Create;
  SettingsMeta := TSettingMetaMap.Create;
  ResetConfigDefaults;
  Reset;
end;

destructor TCNCState.Destroy;
begin
  SettingsMeta.Free;
  Settings.Free;
  BoardInfo.Free;
  inherited Destroy;
end;

procedure TCNCState.Reset;
begin
  MX := 0; MY := 0; MZ := 0; MA := 0; MB := 0; MC := 0;
  WX := 0; WY := 0; WZ := 0; WA := 0; WB := 0; WC := 0;
  WCOX := 0; WCOY := 0; WCOZ := 0; WCOA := 0; WCOB := 0; WCOC := 0;
  PRBX := 0; PRBY := 0; PRBZ := 0;
  PrbCmd := 'G38.2';
  PrbFeed := 10.0;
  ErrLine := '';

  Motion := 'G0';
  WCSMode := 'G54';
  Plane := 'G17';
  FeedMode := 'G94';
  Distance := 'G90';
  ArcMode := 'G91.1';
  Units := 'G20';
  Cutter := '';
  TLOMode := '';
  ProgState := 'M0';
  Spindle := 'M5';
  Coolant := 'M9';

  Tool := 0;
  Feed := 0;
  RPM := 0;
  Planner := 0;
  RxBytes := 0;
  CurFeed := 0;
  CurSpindle := 0;

  OvFeed := 100; OvRapid := 100; OvSpindle := 100;
  OvChanged := False;
  TargetOvFeed := 100; TargetOvRapid := 100; TargetOvSpindle := 100;

  TLO := 0;

  StateStr := 'Not connected';
  Pins := '';
  Msg := '';
  Version := '';
  Controller := '';
  Running := False;
  BoardInfo.Reset;
  Settings.Clear;
  SettingsMeta.Clear;
end;

procedure TCNCState.ResetConfigDefaults;
begin
  // Defaults mirror CNC.py's class-level values / bCNC.ini [CNC] section.
  Safe := 3.0;
  Diameter := 3.175;
  CutFeed := 1000.0;
  CutFeedZ := 500.0;
  TravelX := 300; TravelY := 300; TravelZ := 60;
  FeedMaxX := 3000; FeedMaxY := 3000; FeedMaxZ := 2000;
  AccelX := 25; AccelY := 25; AccelZ := 25;
  StartupGCode := 'G90';
  GangedAxes := '';
end;

end.
