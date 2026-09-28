unit ug2core;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ugenericcontroller;

type
  { TG2CoreController is a structural stub for controllers/G2Core.py.
    G2core speaks a fundamentally different, JSON-based protocol (status
    reports like {"sr":{"posx":...}}, not GRBL's <...>/[...] bracket
    format), so ParseLine's bracket-based dispatch in TGenericController
    does not apply as-is. This class exists so "G2CORE" is a selectable
    controller (completing the day-one multi-controller abstraction) but
    its parsing is intentionally unimplemented - a real port needs a JSON
    parser (fpjson, already bundled with FPC) and a rewritten ParseLine
    override, not just the two bracket-parser methods below.
    See References/bCNC/bCNC/controllers/G2Core.py for the source. }
  TG2CoreController = class(TGenericController)
  public
    constructor Create(AHost: IControllerHost);
    procedure ParseBracketAngle(const ALine: string; ACLine: TLineFifo); override;
    procedure ParseBracketSquare(const ALine: string); override;
  end;

implementation

constructor TG2CoreController.Create(AHost: IControllerHost);
begin
  inherited Create(AHost);
  FGCodeCase := 1; // G2Core.py: gcode_case = 1
  FHasOverride := False;
end;

procedure TG2CoreController.ParseBracketAngle(const ALine: string; ACLine: TLineFifo);
begin
  // G2core does not use '<...>' status reports; unreachable in practice
  // until ParseLine itself is overridden for JSON framing. Log raw so
  // nothing is silently dropped.
  FHost.LogReceived(ALine);
end;

procedure TG2CoreController.ParseBracketSquare(const ALine: string);
begin
  FHost.LogReceived(ALine);
end;

end.
