unit uopengl3dframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  OpenGLContext, GL, GLU,
  ugcode;

type

  { TOpenGL3DFrame: renders the same TSegmentArray produced by ugcode.pas
    (shared with any future 2D preview - see the Phase 3 plan note about
    factoring segment generation out of the renderer) as a rotatable/
    zoomable 3D wireframe toolpath, mouse-driven like a typical CAM
    viewer: left-drag orbits, wheel zooms. }
  TOpenGL3DFrame = class(TFrame)
    BtnRefresh: TButton;
    BtnResetView: TButton;
    GLBox: TOpenGLControl;
    LblInfo: TLabel;
    ToolBar: TPanel;
    procedure BtnRefreshClick(Sender: TObject);
    procedure BtnResetViewClick(Sender: TObject);
    procedure GLBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GLBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure GLBoxMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GLBoxMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure GLBoxPaint(Sender: TObject);
  private
    FSegments: TSegmentArray;
    FSegCount: Integer;
    // Plan Phase 11: highest Power among all LaserOn segments (from
    // TGCodeParser.MaxPower), used to normalize the power-gradient color in
    // DrawToolpath - the real $30 max-S setting isn't known at parse time,
    // so relative-to-this-program's-own-max is the honest choice rather
    // than guessing a fixed S range (grbl programs commonly use S0-255 or
    // S0-1000 depending on the board/config).
    FMaxPower: Double;
    FCenterX, FCenterY, FCenterZ: Double;
    FExtent: Double; // half-diagonal of bounding box, for camera framing
    FRotX, FRotZ: Single;   // orbit angles (degrees)
    FDistance: Single;      // camera distance
    FDragging: Boolean;
    FLastX, FLastY: Integer;
    FOnRequestParse: TNotifyEvent;
    procedure SetupProjection;
    procedure DrawAxes;
    procedure DrawToolpath;
  public
    procedure ResetView;
    procedure SetSegments(const ASegments: TSegmentArray; ACount: Integer;
      AMinX, AMinY, AMinZ, AMaxX, AMaxY, AMaxZ, AMaxPower: Double);
    property OnRequestParse: TNotifyEvent read FOnRequestParse write FOnRequestParse;
  end;

implementation

{$R *.frm}

{ TOpenGL3DFrame }

procedure TOpenGL3DFrame.ResetView;
begin
  FRotX := 55;
  FRotZ := -35;
  if FExtent > 0 then
    FDistance := FExtent * 2.5
  else
    FDistance := 200;
  GLBox.Invalidate;
end;

procedure TOpenGL3DFrame.SetSegments(const ASegments: TSegmentArray;
  ACount: Integer; AMinX, AMinY, AMinZ, AMaxX, AMaxY, AMaxZ, AMaxPower: Double);
var
  dx, dy, dz: Double;
begin
  FSegments := ASegments;
  FSegCount := ACount;
  FMaxPower := AMaxPower;

  if ACount = 0 then
  begin
    FCenterX := 0; FCenterY := 0; FCenterZ := 0;
    FExtent := 100;
  end
  else
  begin
    FCenterX := (AMinX + AMaxX) / 2.0;
    FCenterY := (AMinY + AMaxY) / 2.0;
    FCenterZ := (AMinZ + AMaxZ) / 2.0;
    dx := AMaxX - AMinX; dy := AMaxY - AMinY; dz := AMaxZ - AMinZ;
    FExtent := Sqrt(dx * dx + dy * dy + dz * dz) / 2.0;
    if FExtent < 1 then FExtent := 1;
  end;

  LblInfo.Caption := IntToStr(ACount) + ' segments';
  ResetView;
end;

procedure TOpenGL3DFrame.BtnRefreshClick(Sender: TObject);
begin
  if Assigned(FOnRequestParse) then FOnRequestParse(Self);
end;

procedure TOpenGL3DFrame.BtnResetViewClick(Sender: TObject);
begin
  ResetView;
end;

procedure TOpenGL3DFrame.GLBoxMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FDragging := True;
    FLastX := X;
    FLastY := Y;
  end;
end;

procedure TOpenGL3DFrame.GLBoxMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if not FDragging then Exit;
  FRotZ := FRotZ + (X - FLastX) * 0.5;
  FRotX := FRotX - (Y - FLastY) * 0.5;
  if FRotX < 1 then FRotX := 1;
  if FRotX > 179 then FRotX := 179;
  FLastX := X;
  FLastY := Y;
  GLBox.Invalidate;
end;

procedure TOpenGL3DFrame.GLBoxMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDragging := False;
end;

procedure TOpenGL3DFrame.GLBoxMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  FDistance := FDistance * (1.0 - WheelDelta / 1200.0);
  if FDistance < FExtent * 0.1 then FDistance := FExtent * 0.1;
  if FDistance > FExtent * 20 then FDistance := FExtent * 20;
  GLBox.Invalidate;
  Handled := True;
end;

procedure TOpenGL3DFrame.SetupProjection;
var
  aspect: Double;
begin
  glViewport(0, 0, GLBox.Width, GLBox.Height);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  if GLBox.Height = 0 then
    aspect := 1
  else
    aspect := GLBox.Width / GLBox.Height;
  gluPerspective(45.0, aspect, 0.1, (FDistance + FExtent) * 4 + 10);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
end;

procedure TOpenGL3DFrame.DrawAxes;
var
  L: Single;
begin
  L := FExtent * 0.3;
  if L <= 0 then L := 10;
  glLineWidth(2.0);
  glBegin(GL_LINES);
    glColor3f(1, 0, 0); glVertex3f(0, 0, 0); glVertex3f(L, 0, 0);   // X red
    glColor3f(0, 1, 0); glVertex3f(0, 0, 0); glVertex3f(0, L, 0);   // Y green
    glColor3f(0.3, 0.3, 1); glVertex3f(0, 0, 0); glVertex3f(0, 0, L); // Z blue
  glEnd;
  glLineWidth(1.0);
end;

procedure TOpenGL3DFrame.DrawToolpath;
var
  i: Integer;
  t, r, g, b: Single;
begin
  glBegin(GL_LINES);
  for i := 0 to FSegCount - 1 do
  begin
    if FSegments[i].Rapid then
      glColor3f(0.55, 0.55, 0.55)          // rapid travel, laser guaranteed off
    else if not FSegments[i].LaserOn then
      glColor3f(0.45, 0.40, 0.20)          // feed move with the laser off (e.g. after M5)
    else
    begin
      // Power-gradient: low power = dim red, high power = bright yellow -
      // the common "laser power heat" direction (also LaserGRBL's own
      // convention), normalized against this program's own highest S
      // value (FMaxPower) since the real $30 max-S setting isn't known
      // here - see FMaxPower's own doc comment.
      if FMaxPower > 0 then
        t := EnsureRange(FSegments[i].Power / FMaxPower, 0.0, 1.0)
      else
        t := 1.0; // no S word ever seen on a laser-on move - show full power rather than invisible
      r := 0.35 + 0.65 * t;
      g := 0.05 + 0.85 * t;
      b := 0.05 + 0.15 * t;
      glColor3f(r, g, b);
    end;
    glVertex3f(FSegments[i].X1, FSegments[i].Y1, FSegments[i].Z1);
    glVertex3f(FSegments[i].X2, FSegments[i].Y2, FSegments[i].Z2);
  end;
  glEnd;
end;

procedure TOpenGL3DFrame.GLBoxPaint(Sender: TObject);
begin
  if not GLBox.MakeCurrent then Exit;

  glClearColor(0.10, 0.10, 0.12, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  glEnable(GL_DEPTH_TEST);

  SetupProjection;

  glTranslatef(0, 0, -FDistance);
  glRotatef(FRotX, 1, 0, 0);
  glRotatef(FRotZ, 0, 0, 1);
  glTranslatef(-FCenterX, -FCenterY, -FCenterZ);

  DrawAxes;
  DrawToolpath;

  GLBox.SwapBuffers;
end;

end.
