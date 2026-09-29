object GerberImportFrame: TGerberImportFrame
  Left = 0
  Height = 420
  Top = 0
  Width = 700
  Align = alClient
  ClientHeight = 420
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
  object LblToolDiameter: TLabel
    Left = 12
    Height = 15
    Top = 66
    Width = 120
    Caption = 'Tool diameter (mm)'
  end
  object EdToolDiameter: TFloatSpinEdit
    Left = 12
    Height = 24
    Top = 84
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 20
    MinValue = 0.01
    TabOrder = 1
    Value = 0.2
  end
  object LblIsolationGap: TLabel
    Left = 128
    Height = 15
    Top = 66
    Width = 110
    Caption = 'Isolation gap (mm)'
  end
  object EdIsolationGap: TFloatSpinEdit
    Left = 128
    Height = 24
    Top = 84
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 20
    MinValue = 0
    TabOrder = 2
    Value = 0.1
  end
  object LblPasses: TLabel
    Left = 244
    Height = 15
    Top = 66
    Width = 40
    Caption = 'Passes'
  end
  object EdPasses: TSpinEdit
    Left = 244
    Height = 24
    Top = 84
    Width = 70
    MaxValue = 20
    MinValue = 1
    TabOrder = 3
    Value = 1
  end
  object LblPassStepover: TLabel
    Left = 330
    Height = 15
    Top = 66
    Width = 120
    Caption = 'Pass stepover (mm)'
  end
  object EdPassStepover: TFloatSpinEdit
    Left = 330
    Height = 24
    Top = 84
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 20
    MinValue = 0.001
    TabOrder = 4
    Value = 0.15
  end
  object LblCutDepth: TLabel
    Left = 12
    Height = 15
    Top = 128
    Width = 90
    Caption = 'Cut depth (mm)'
  end
  object EdCutDepth: TFloatSpinEdit
    Left = 12
    Height = 24
    Top = 146
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 10
    MinValue = 0.01
    TabOrder = 5
    Value = 0.1
  end
  object LblDepthPerPass: TLabel
    Left = 128
    Height = 15
    Top = 128
    Width = 120
    Caption = 'Depth per pass (mm)'
  end
  object EdDepthPerPass: TFloatSpinEdit
    Left = 128
    Height = 24
    Top = 146
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 10
    MinValue = 0.01
    TabOrder = 6
    Value = 0.1
  end
  object LblSafeZ: TLabel
    Left = 244
    Height = 15
    Top = 128
    Width = 70
    Caption = 'Safe Z (mm)'
  end
  object EdSafeZ: TFloatSpinEdit
    Left = 244
    Height = 24
    Top = 146
    Width = 100
    DecimalPlaces = 2
    Increment = 0.5
    MaxValue = 100
    MinValue = 0.5
    TabOrder = 7
    Value = 5
  end
  object LblFeedRate: TLabel
    Left = 12
    Height = 15
    Top = 190
    Width = 110
    Caption = 'Feed rate (mm/min)'
  end
  object EdFeedRate: TSpinEdit
    Left = 12
    Height = 24
    Top = 208
    Width = 100
    MaxValue = 10000
    MinValue = 10
    TabOrder = 8
    Value = 300
  end
  object LblPlungeRate: TLabel
    Left = 128
    Height = 15
    Top = 190
    Width = 130
    Caption = 'Plunge rate (mm/min)'
  end
  object EdPlungeRate: TSpinEdit
    Left = 128
    Height = 24
    Top = 208
    Width = 100
    MaxValue = 5000
    MinValue = 10
    TabOrder = 9
    Value = 100
  end
  object LblSpindleRPM: TLabel
    Left = 244
    Height = 15
    Top = 190
    Width = 120
    Caption = 'Spindle RPM (0=off)'
  end
  object EdSpindleRPM: TSpinEdit
    Left = 244
    Height = 24
    Top = 208
    Width = 100
    MaxValue = 100000
    MinValue = 0
    TabOrder = 10
    Value = 0
  end
  object BtnGenerate: TButton
    Left = 12
    Height = 32
    Top = 254
    Width = 160
    Caption = 'Generate G-Code'
    Font.Style = [fsBold]
    ParentFont = False
    OnClick = BtnGenerateClick
    TabOrder = 11
  end
  object LblStatus: TLabel
    Left = 184
    Height = 15
    Top = 262
    Width = 3
    Caption = ''
  end
end
