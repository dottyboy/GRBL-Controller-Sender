object RasterImportFrame: TRasterImportFrame
  Left = 0
  Height = 500
  Top = 0
  Width = 700
  Align = alClient
  ClientHeight = 500
  ClientWidth = 700
  TabOrder = 0
  object BtnOpen: TButton
    Left = 12
    Height = 28
    Top = 12
    Width = 100
    Caption = 'Open Image...'
    OnClick = BtnOpenClick
    TabOrder = 0
  end
  object LblFile: TLabel
    Left = 120
    Height = 15
    Top = 18
    Width = 300
    Caption = ''
  end
  object LblToolMode: TLabel
    Left = 12
    Height = 15
    Top = 56
    Width = 52
    Caption = 'Tool mode'
  end
  object CboToolMode: TComboBox
    Left = 12
    Height = 24
    Top = 74
    Width = 160
    ReadOnly = True
    Style = csDropDownList
    OnChange = CboToolModeChange
    TabOrder = 1
  end
  object LblDither: TLabel
    Left = 188
    Height = 15
    Top = 56
    Width = 45
    Caption = 'Dither'
  end
  object CboDither: TComboBox
    Left = 188
    Height = 24
    Top = 74
    Width = 160
    ReadOnly = True
    Style = csDropDownList
    TabOrder = 2
  end
  object LblDirection: TLabel
    Left = 364
    Height = 15
    Top = 56
    Width = 51
    Caption = 'Direction'
  end
  object CboDirection: TComboBox
    Left = 364
    Height = 24
    Top = 74
    Width = 140
    ReadOnly = True
    Style = csDropDownList
    TabOrder = 3
  end
  object LblThreshold: TLabel
    Left = 520
    Height = 15
    Top = 56
    Width = 55
    Caption = 'Threshold'
  end
  object EdThreshold: TSpinEdit
    Left = 520
    Height = 24
    Top = 74
    Width = 80
    MaxValue = 255
    MinValue = 0
    TabOrder = 4
    Value = 128
  end
  object LblMinPower: TLabel
    Left = 12
    Height = 15
    Top = 112
    Width = 60
    Caption = 'Min power'
  end
  object EdMinPower: TSpinEdit
    Left = 12
    Height = 24
    Top = 130
    Width = 100
    MaxValue = 1000
    MinValue = 0
    TabOrder = 5
    Value = 0
  end
  object LblMaxPower: TLabel
    Left = 128
    Height = 15
    Top = 112
    Width = 62
    Caption = 'Max power'
  end
  object EdMaxPower: TSpinEdit
    Left = 128
    Height = 24
    Top = 130
    Width = 100
    MaxValue = 1000
    MinValue = 0
    TabOrder = 6
    Value = 255
  end
  object LblFeedRate: TLabel
    Left = 244
    Height = 15
    Top = 112
    Width = 68
    Caption = 'Feed (mm/min)'
  end
  object EdFeedRate: TSpinEdit
    Left = 244
    Height = 24
    Top = 130
    Width = 100
    MaxValue = 100000
    MinValue = 1
    TabOrder = 7
    Value = 1500
  end
  object LblPixelSize: TLabel
    Left = 360
    Height = 15
    Top = 112
    Width = 88
    Caption = 'Pixel size (mm)'
  end
  object EdPixelSize: TFloatSpinEdit
    Left = 360
    Height = 24
    Top = 130
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 100
    MinValue = 0.001
    TabOrder = 8
    Value = 0.1
  end
  object ChkInvert: TCheckBox
    Left = 12
    Height = 24
    Top = 168
    Width = 200
    Caption = 'Invert (lighter = more power)'
    TabOrder = 9
  end
  object BtnGenerate: TButton
    Left = 12
    Height = 32
    Top = 204
    Width = 120
    Caption = 'Generate'
    OnClick = BtnGenerateClick
    TabOrder = 10
  end
  object LblStatus: TLabel
    Left = 12
    Height = 15
    Top = 248
    Width = 664
    AutoSize = False
    Caption = ''
  end
end
