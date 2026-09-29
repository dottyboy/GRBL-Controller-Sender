object GerberImportFrame: TGerberImportFrame
  Left = 0
  Height = 480
  Top = 0
  Width = 700
  Align = alClient
  ClientHeight = 480
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
end
