object SvgImportFrame: TSvgImportFrame
  Left = 0
  Height = 500
  Top = 0
  Width = 700
  Align = alClient
  ClientHeight = 500
  ClientWidth = 700
  TabOrder = 0
  object BtnOpenSvg: TButton
    Left = 12
    Height = 28
    Top = 12
    Width = 110
    Caption = 'Open SVG...'
    OnClick = BtnOpenSvgClick
    TabOrder = 0
  end
  object LblSvgFile: TLabel
    Left = 130
    Height = 15
    Top = 18
    Width = 200
    Caption = ''
  end
  object BtnGenerateShapes: TButton
    Left = 340
    Height = 28
    Top = 12
    Width = 130
    Caption = 'Generate from SVG'
    OnClick = BtnGenerateShapesClick
    TabOrder = 1
  end
  object BtnOpenImage: TButton
    Left = 12
    Height = 28
    Top = 56
    Width = 110
    Caption = 'Open Image...'
    OnClick = BtnOpenImageClick
    TabOrder = 2
  end
  object LblImageFile: TLabel
    Left = 130
    Height = 15
    Top = 62
    Width = 200
    Caption = ''
  end
  object BtnVectorize: TButton
    Left = 340
    Height = 28
    Top = 56
    Width = 110
    Caption = 'Vectorize'
    OnClick = BtnVectorizeClick
    TabOrder = 3
  end
  object BtnGenerateVector: TButton
    Left = 456
    Height = 28
    Top = 56
    Width = 130
    Caption = 'Generate from Vector'
    OnClick = BtnGenerateVectorClick
    TabOrder = 4
  end
  object BtnCenterline: TButton
    Left = 592
    Height = 28
    Top = 56
    Width = 96
    Caption = 'Centerline'
    OnClick = BtnCenterlineClick
    TabOrder = 5
  end
  object LblThreshold: TLabel
    Left = 12
    Height = 15
    Top = 100
    Width = 55
    Caption = 'Threshold'
  end
  object EdThreshold: TSpinEdit
    Left = 12
    Height = 24
    Top = 118
    Width = 80
    MaxValue = 255
    MinValue = 0
    TabOrder = 6
    Value = 128
  end
  object LblPower: TLabel
    Left = 100
    Height = 15
    Top = 100
    Width = 34
    Caption = 'Power'
  end
  object EdPower: TSpinEdit
    Left = 100
    Height = 24
    Top = 118
    Width = 80
    MaxValue = 1000
    MinValue = 0
    TabOrder = 7
    Value = 200
  end
  object LblFeedRate: TLabel
    Left = 188
    Height = 15
    Top = 100
    Width = 68
    Caption = 'Feed (mm/min)'
  end
  object EdFeedRate: TSpinEdit
    Left = 188
    Height = 24
    Top = 118
    Width = 100
    MaxValue = 100000
    MinValue = 1
    TabOrder = 8
    Value = 1000
  end
  object LblPixelSize: TLabel
    Left = 296
    Height = 15
    Top = 100
    Width = 88
    Caption = 'Pixel size (mm)'
  end
  object EdPixelSize: TFloatSpinEdit
    Left = 296
    Height = 24
    Top = 118
    Width = 100
    DecimalPlaces = 3
    Increment = 0.01
    MaxValue = 100
    MinValue = 0.001
    TabOrder = 9
    Value = 0.2
  end
  object LblStatus: TLabel
    Left = 12
    Height = 15
    Top = 156
    Width = 664
    AutoSize = False
    Caption = ''
  end
end
