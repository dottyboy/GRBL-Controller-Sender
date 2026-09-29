unit utoolbits;

{ utoolbits: parametric CNC tool-bit shape templates (plan Phase 34) - the
  same modeling FreeCAD's own Path (CAM) workbench Tool Bit Editor uses
  (shape-type + a per-shape parameter set), not a flat preset-only list.
  Real, verified source: read directly from a genuine local FreeCAD 1.1
  installation's own bundled default tool bit files
  (~/.local/share/FreeCAD/v1-1/CamAssets/Tools/Bit/*.fctb, plain JSON) -
  shape-type names, parameter names, and every preset's real default
  values below are transcribed from those actual files, not guessed or
  invented. FreeCAD's own default library only ships 30/45/60/90 degree
  V-bits (no 15 degree, despite an earlier planning note assuming one) -
  matched to what's really there rather than padding the list.

  Deliberately NOT ported: FreeCAD's other, more specialized shape types
  seen in the same real directory (SlittingSaw, ThreadMill, Tap, Probe) -
  out of scope for a hobby CNC router's own tool table, disclosed rather
  than included for completeness padding. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  { TToolBitShape: matches FreeCAD's own real "shape-type" strings
    exactly (Endmill/Ballend/Bullnose/VBit/Drill/Chamfer), one Pascal
    enum value per shape actually ported. }
  TToolBitShape = (tbsEndmill, tbsBallend, tbsBullnose, tbsVBit, tbsDrill, tbsChamfer);

  { TToolBitParams: a flat union of every parameter any ported shape
    needs - simpler than a variant record in Pascal, and only the fields
    relevant to a given Shape are ever populated/read (mirrors FreeCAD's
    own per-shape-type parameter dict, which likewise only defines the
    keys that shape actually uses). All linear values in mm, angles in
    degrees - same convention as every other core unit in this app. }
  TToolBitParams = record
    Diameter: Double;          // all shapes
    ShankDiameter: Double;      // Endmill/Ballend/Bullnose/VBit/Chamfer
    Length: Double;              // all shapes (overall tool length)
    CuttingEdgeHeight: Double;   // Endmill/Ballend/Bullnose/VBit/Chamfer
    CuttingEdgeAngle: Double;    // VBit/Chamfer (included angle, degrees)
    TipDiameter: Double;         // VBit/Chamfer
    CornerRadius: Double;        // Bullnose
    TipAngle: Double;            // Drill (point angle, degrees)
  end;

  TToolBitPreset = record
    Name: string;
    Shape: TToolBitShape;
    Params: TToolBitParams;
  end;

function ShapeName(AShape: TToolBitShape): string;

{ DescribeToolBit: a one-line human-readable geometry summary, meant for
  the existing Tools grid's free-text Comment column (this app's tool
  table has no per-shape-parameter columns of its own - the parametric
  detail lives here, the grid just gets a faithful text rendering of
  it). E.g. 'VBit 90.0deg tip=0.10mm shank=5.00mm len=20.00mm'. }
function DescribeToolBit(AShape: TToolBitShape; const AParams: TToolBitParams): string;

function DefaultParamsForShape(AShape: TToolBitShape): TToolBitParams;

function PresetCount: Integer;
function GetPreset(AIndex: Integer): TToolBitPreset;

implementation

const
  PRESET_COUNT = 9;

var
  GPresets: array[0..PRESET_COUNT - 1] of TToolBitPreset;

function ShapeName(AShape: TToolBitShape): string;
begin
  case AShape of
    tbsEndmill: Result := 'Endmill';
    tbsBallend: Result := 'Ball End';
    tbsBullnose: Result := 'Bull Nose';
    tbsVBit: Result := 'V-Bit';
    tbsDrill: Result := 'Drill';
    tbsChamfer: Result := 'Chamfer';
  end;
end;

function DescribeToolBit(AShape: TToolBitShape; const AParams: TToolBitParams): string;
begin
  case AShape of
    tbsEndmill:
      Result := Format('Endmill dia=%.3fmm shank=%.2fmm len=%.1fmm',
        [AParams.Diameter, AParams.ShankDiameter, AParams.Length]);
    tbsBallend:
      Result := Format('Ball End dia=%.3fmm shank=%.2fmm len=%.1fmm',
        [AParams.Diameter, AParams.ShankDiameter, AParams.Length]);
    tbsBullnose:
      Result := Format('Bull Nose dia=%.3fmm corner=%.2fmm shank=%.2fmm len=%.1fmm',
        [AParams.Diameter, AParams.CornerRadius, AParams.ShankDiameter, AParams.Length]);
    tbsVBit:
      Result := Format('VBit %.1fdeg dia=%.2fmm tip=%.2fmm shank=%.2fmm len=%.1fmm',
        [AParams.CuttingEdgeAngle, AParams.Diameter, AParams.TipDiameter,
         AParams.ShankDiameter, AParams.Length]);
    tbsDrill:
      Result := Format('Drill dia=%.3fmm tipangle=%.1fdeg len=%.1fmm',
        [AParams.Diameter, AParams.TipAngle, AParams.Length]);
    tbsChamfer:
      Result := Format('Chamfer %.1fdeg dia=%.2fmm tip=%.2fmm shank=%.2fmm len=%.1fmm',
        [AParams.CuttingEdgeAngle, AParams.Diameter, AParams.TipDiameter,
         AParams.ShankDiameter, AParams.Length]);
  else
    Result := '';
  end;
end;

function DefaultParamsForShape(AShape: TToolBitShape): TToolBitParams;
begin
  FillChar(Result, SizeOf(Result), 0);
  case AShape of
    tbsEndmill:
      begin
        Result.Diameter := 3.175;
        Result.ShankDiameter := 3.175;
        Result.Length := 45;
        Result.CuttingEdgeHeight := 25;
      end;
    tbsBallend:
      begin
        Result.Diameter := 6;
        Result.ShankDiameter := 3;
        Result.Length := 50;
        Result.CuttingEdgeHeight := 40;
      end;
    tbsBullnose:
      begin
        Result.Diameter := 6;
        Result.ShankDiameter := 3;
        Result.Length := 50;
        Result.CuttingEdgeHeight := 40;
        Result.CornerRadius := 1.5;
      end;
    tbsVBit:
      begin
        Result.Diameter := 10;
        Result.ShankDiameter := 5;
        Result.Length := 20;
        Result.CuttingEdgeHeight := 1;
        Result.CuttingEdgeAngle := 90;
        Result.TipDiameter := 0.1;
      end;
    tbsDrill:
      begin
        Result.Diameter := 5;
        Result.Length := 50;
        Result.TipAngle := 119;
      end;
    tbsChamfer:
      begin
        Result.Diameter := 12.3323;
        Result.ShankDiameter := 6.35;
        Result.Length := 30;
        Result.CuttingEdgeHeight := 6.35;
        Result.CuttingEdgeAngle := 45;
        Result.TipDiameter := 5;
      end;
  end;
end;

function PresetCount: Integer;
begin
  Result := PRESET_COUNT;
end;

function GetPreset(AIndex: Integer): TToolBitPreset;
begin
  Result := GPresets[AIndex];
end;

procedure SeedPreset(AIndex: Integer; const AName: string; AShape: TToolBitShape;
  AParams: TToolBitParams);
begin
  GPresets[AIndex].Name := AName;
  GPresets[AIndex].Shape := AShape;
  GPresets[AIndex].Params := AParams;
end;

var
  p: TToolBitParams;

initialization
  // Real defaults, transcribed from an actual local FreeCAD 1.1 install's
  // own bundled *.fctb preset files (see this unit's header comment).
  p := DefaultParamsForShape(tbsVBit); p.CuttingEdgeAngle := 30; p.Length := 30;
  SeedPreset(0, '30 Deg. V-Bit', tbsVBit, p);

  p := DefaultParamsForShape(tbsVBit); p.CuttingEdgeAngle := 45;
  SeedPreset(1, '45 Deg. V-Bit', tbsVBit, p);

  p := DefaultParamsForShape(tbsVBit); p.CuttingEdgeAngle := 60;
  SeedPreset(2, '60 Deg. V-Bit', tbsVBit, p);

  p := DefaultParamsForShape(tbsVBit); p.CuttingEdgeAngle := 90;
  SeedPreset(3, '90 Deg. V-Bit', tbsVBit, p);

  p := DefaultParamsForShape(tbsEndmill);
  SeedPreset(4, '3.175mm Endmill', tbsEndmill, p);

  p := DefaultParamsForShape(tbsEndmill);
  p.Diameter := 5; p.ShankDiameter := 3; p.Length := 50; p.CuttingEdgeHeight := 30;
  SeedPreset(5, '5mm Endmill', tbsEndmill, p);

  p := DefaultParamsForShape(tbsBallend);
  SeedPreset(6, '6mm Ball End', tbsBallend, p);

  p := DefaultParamsForShape(tbsBullnose);
  SeedPreset(7, '6mm Bull Nose', tbsBullnose, p);

  p := DefaultParamsForShape(tbsDrill);
  SeedPreset(8, '5mm Drill', tbsDrill, p);

end.
