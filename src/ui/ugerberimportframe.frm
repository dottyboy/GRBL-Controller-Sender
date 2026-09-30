object GerberImportFrame: TGerberImportFrame
  Left = 0
  Height = 620
  Top = 0
  Width = 700
  Align = alClient
  ClientHeight = 620
  ClientWidth = 700
  TabOrder = 0
  object BtnOpenGerber: TButton
    Left = 12
    Height = 28
    Top = 12
    Width = 130
    Caption = 'Open Gerber...'
    OnClick = BtnOpenGerberClick
    TabOrder = 0
  end
  object LblGerberFile: TLabel
    Left = 152
    Height = 15
    Top = 18
    Width = 200
    Caption = ''
  end
  object RgTool: TRadioGroup
    Left = 12
    Height = 50
    Top = 48
    Width = 140
    Caption = 'Tool'
    ItemIndex = 0
    Items.Strings = (
      'CNC'
      'Laser'
    )
    OnClick = RgToolClick
    TabOrder = 1
  end
  object RgStrategy: TRadioGroup
    Left = 160
    Height = 50
    Top = 48
    Width = 190
    Caption = 'Strategy'
    ItemIndex = 0
    Items.Strings = (
      'Isolate'
      'Draw (CNC only)'
    )
    OnClick = RgStrategyClick
    TabOrder = 2
  end
  object LblToolDiameter: TLabel
    Left = 12
    Height = 15
    Top = 126
    Width = 120
    Caption = 'Tool diameter (mm)'
  end
  object EdToolDiameter: TFloatSpinEdit
    Left = 12
    Height = 24
    Top = 144
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 20
    MinValue = 0.01
    TabOrder = 3
    Value = 0.2
  end
  object LblIsolationGap: TLabel
    Left = 128
    Height = 15
    Top = 126
    Width = 110
    Caption = 'Isolation gap (mm)'
  end
  object EdIsolationGap: TFloatSpinEdit
    Left = 128
    Height = 24
    Top = 144
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 20
    MinValue = 0
    TabOrder = 4
    Value = 0.1
  end
  object LblPasses: TLabel
    Left = 244
    Height = 15
    Top = 126
    Width = 40
    Caption = 'Passes'
  end
  object EdPasses: TSpinEdit
    Left = 244
    Height = 24
    Top = 144
    Width = 70
    MaxValue = 20
    MinValue = 1
    TabOrder = 5
    Value = 1
  end
  object LblPassStepover: TLabel
    Left = 330
    Height = 15
    Top = 126
    Width = 120
    Caption = 'Pass stepover (mm)'
  end
  object EdPassStepover: TFloatSpinEdit
    Left = 330
    Height = 24
    Top = 144
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 20
    MinValue = 0.001
    TabOrder = 6
    Value = 0.15
  end
  object LblCutDepth: TLabel
    Left = 12
    Height = 15
    Top = 188
    Width = 90
    Caption = 'Cut depth (mm)'
  end
  object EdCutDepth: TFloatSpinEdit
    Left = 12
    Height = 24
    Top = 206
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 10
    MinValue = 0.01
    TabOrder = 7
    Value = 0.1
  end
  object LblDepthPerPass: TLabel
    Left = 128
    Height = 15
    Top = 188
    Width = 120
    Caption = 'Depth per pass (mm)'
  end
  object EdDepthPerPass: TFloatSpinEdit
    Left = 128
    Height = 24
    Top = 206
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 10
    MinValue = 0.01
    TabOrder = 8
    Value = 0.1
  end
  object LblSafeZ: TLabel
    Left = 244
    Height = 15
    Top = 188
    Width = 70
    Caption = 'Safe Z (mm)'
  end
  object EdSafeZ: TFloatSpinEdit
    Left = 244
    Height = 24
    Top = 206
    Width = 100
    DecimalPlaces = 2
    Increment = 0.5
    MaxValue = 100
    MinValue = 0.5
    TabOrder = 9
    Value = 5
  end
  object LblFeedRate: TLabel
    Left = 12
    Height = 15
    Top = 250
    Width = 110
    Caption = 'Feed rate (mm/min)'
  end
  object EdFeedRate: TSpinEdit
    Left = 12
    Height = 24
    Top = 268
    Width = 100
    MaxValue = 10000
    MinValue = 10
    TabOrder = 10
    Value = 300
  end
  object LblPlungeRate: TLabel
    Left = 128
    Height = 15
    Top = 250
    Width = 130
    Caption = 'Plunge rate (mm/min)'
  end
  object EdPlungeRate: TSpinEdit
    Left = 128
    Height = 24
    Top = 268
    Width = 100
    MaxValue = 5000
    MinValue = 10
    TabOrder = 11
    Value = 100
  end
  object LblSpindleRPM: TLabel
    Left = 244
    Height = 15
    Top = 250
    Width = 120
    Caption = 'Spindle RPM (0=off)'
  end
  object EdSpindleRPM: TSpinEdit
    Left = 244
    Height = 24
    Top = 268
    Width = 100
    MaxValue = 100000
    MinValue = 0
    TabOrder = 12
    Value = 0
  end
  object LblLaserPower: TLabel
    Left = 12
    Height = 15
    Top = 250
    Width = 90
    Caption = 'Laser power (S)'
    Visible = False
  end
  object EdLaserPower: TSpinEdit
    Left = 12
    Height = 24
    Top = 268
    Width = 100
    MaxValue = 1000
    MinValue = 0
    TabOrder = 13
    Value = 200
    Visible = False
  end
  object LblLaserFeedRate: TLabel
    Left = 128
    Height = 15
    Top = 250
    Width = 110
    Caption = 'Feed rate (mm/min)'
    Visible = False
  end
  object EdLaserFeedRate: TSpinEdit
    Left = 128
    Height = 24
    Top = 268
    Width = 100
    MaxValue = 10000
    MinValue = 10
    TabOrder = 14
    Value = 800
    Visible = False
  end
  object BtnGenerate: TButton
    Left = 12
    Height = 32
    Top = 314
    Width = 160
    Caption = 'Generate G-Code'
    Font.Style = [fsBold]
    ParentFont = False
    OnClick = BtnGenerateClick
    TabOrder = 15
  end
  object LblStatus: TLabel
    Left = 184
    Height = 15
    Top = 322
    Width = 3
    Caption = ''
  end
  object LblRegSection: TLabel
    Left = 12
    Height = 15
    Top = 356
    Width = 220
    Caption = 'Double-sided registration (CNC only)'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblRegHoleDiameter: TLabel
    Left = 12
    Height = 15
    Top = 380
    Width = 110
    Caption = 'Hole diameter (mm)'
  end
  object EdRegHoleDiameter: TFloatSpinEdit
    Left = 12
    Height = 24
    Top = 398
    Width = 100
    DecimalPlaces = 2
    Increment = 0.1
    MaxValue = 10
    MinValue = 0.5
    TabOrder = 16
    Value = 3
  end
  object LblRegDrillDepth: TLabel
    Left = 128
    Height = 15
    Top = 380
    Width = 100
    Caption = 'Drill depth (mm)'
  end
  object EdRegDrillDepth: TFloatSpinEdit
    Left = 128
    Height = 24
    Top = 398
    Width = 100
    DecimalPlaces = 2
    Increment = 0.5
    MaxValue = 50
    MinValue = 0.1
    TabOrder = 17
    Value = 6
  end
  object LblRegPeckDepth: TLabel
    Left = 244
    Height = 15
    Top = 380
    Width = 100
    Caption = 'Peck depth (mm)'
  end
  object EdRegPeckDepth: TFloatSpinEdit
    Left = 244
    Height = 24
    Top = 398
    Width = 100
    DecimalPlaces = 2
    Increment = 0.5
    MaxValue = 50
    MinValue = 0
    TabOrder = 18
    Value = 2
  end
  object LblRegHole1: TLabel
    Left = 12
    Height = 15
    Top = 442
    Width = 120
    Caption = 'Hole 1 X, Y (mm)'
  end
  object EdRegHole1X: TFloatSpinEdit
    Left = 12
    Height = 24
    Top = 460
    Width = 70
    DecimalPlaces = 2
    Increment = 1
    MaxValue = 1000
    MinValue = -1000
    TabOrder = 19
    Value = 5
  end
  object EdRegHole1Y: TFloatSpinEdit
    Left = 86
    Height = 24
    Top = 460
    Width = 70
    DecimalPlaces = 2
    Increment = 1
    MaxValue = 1000
    MinValue = -1000
    TabOrder = 20
    Value = 5
  end
  object LblRegHole2: TLabel
    Left = 180
    Height = 15
    Top = 442
    Width = 120
    Caption = 'Hole 2 X, Y (mm)'
  end
  object EdRegHole2X: TFloatSpinEdit
    Left = 180
    Height = 24
    Top = 460
    Width = 70
    DecimalPlaces = 2
    Increment = 1
    MaxValue = 1000
    MinValue = -1000
    TabOrder = 21
    Value = 95
  end
  object EdRegHole2Y: TFloatSpinEdit
    Left = 254
    Height = 24
    Top = 460
    Width = 70
    DecimalPlaces = 2
    Increment = 1
    MaxValue = 1000
    MinValue = -1000
    TabOrder = 22
    Value = 5
  end
  object BtnGenerateRegHoles: TButton
    Left = 12
    Height = 32
    Top = 500
    Width = 220
    Caption = 'Generate Registration Holes'
    OnClick = BtnGenerateRegHolesClick
    TabOrder = 23
  end
  object LblMirrorSection: TLabel
    Left = 12
    Height = 15
    Top = 550
    Width = 140
    Caption = 'Mirror for second side'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object ChkMirror: TCheckBox
    Left = 12
    Height = 19
    Top = 572
    Width = 170
    Caption = 'Mirror before generating'
    OnClick = ChkMirrorClick
    TabOrder = 24
  end
  object LblMirrorAxisX: TLabel
    Left = 200
    Height = 15
    Top = 570
    Width = 110
    Caption = 'Mirror axis X (mm)'
  end
  object EdMirrorAxisX: TFloatSpinEdit
    Left = 200
    Height = 24
    Top = 588
    Width = 100
    DecimalPlaces = 2
    Increment = 1
    MaxValue = 1000
    MinValue = -1000
    TabOrder = 25
    Value = 50
  end
end
