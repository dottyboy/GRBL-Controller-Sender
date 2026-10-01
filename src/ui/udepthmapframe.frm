object DepthMapFrame: TDepthMapFrame
  Left = 0
  Height = 380
  Top = 0
  Width = 560
  ClientHeight = 380
  ClientWidth = 560
  TabOrder = 0
  object BtnLoadPhoto: TButton
    Left = 16
    Height = 30
    Top = 16
    Width = 140
    Caption = 'Load Photo...'
    OnClick = BtnLoadPhotoClick
    TabOrder = 0
  end
  object LblFile: TLabel
    Left = 170
    Height = 15
    Top = 24
    Width = 3
    Caption = ''
  end
  object LblStatus: TLabel
    Left = 16
    Height = 15
    Top = 64
    Width = 3
    Caption = ''
  end
  object BtnSendToRaster: TButton
    Left = 16
    Height = 30
    Top = 96
    Width = 180
    Caption = 'Send to Raster Import'
    OnClick = BtnSendToRasterClick
    TabOrder = 1
  end
  object LblReliefGroup: TLabel
    Left = 16
    Height = 15
    Top = 144
    Width = 260
    Caption = 'CNC Relief (reuses the loaded depth map)'
  end
  object LblPixelSize: TLabel
    Left = 16
    Height = 15
    Top = 168
    Width = 80
    Caption = 'Pixel size (mm)'
  end
  object EdPixelSize: TFloatSpinEdit
    Left = 16
    Height = 24
    Top = 186
    Width = 120
    DecimalPlaces = 3
    Increment = 0.1
    MaxValue = 50
    MinValue = 0.01
    TabOrder = 2
  end
  object LblMaxDepth: TLabel
    Left = 160
    Height = 15
    Top = 168
    Width = 80
    Caption = 'Max depth (mm)'
  end
  object EdMaxDepth: TFloatSpinEdit
    Left = 160
    Height = 24
    Top = 186
    Width = 120
    DecimalPlaces = 2
    Increment = 0.5
    MaxValue = 200
    MinValue = 0.1
    TabOrder = 3
  end
  object LblFeedRate: TLabel
    Left = 16
    Height = 15
    Top = 222
    Width = 80
    Caption = 'Feed (mm/min)'
  end
  object EdFeedRate: TSpinEdit
    Left = 16
    Height = 24
    Top = 240
    Width = 120
    MaxValue = 20000
    MinValue = 1
    TabOrder = 4
  end
  object LblSafeZ: TLabel
    Left = 160
    Height = 15
    Top = 222
    Width = 60
    Caption = 'Safe Z (mm)'
  end
  object EdSafeZ: TFloatSpinEdit
    Left = 160
    Height = 24
    Top = 240
    Width = 120
    DecimalPlaces = 2
    Increment = 0.5
    MaxValue = 100
    MinValue = 0
    TabOrder = 5
  end
  object LblDirection: TLabel
    Left = 16
    Height = 15
    Top = 276
    Width = 50
    Caption = 'Direction'
  end
  object CboDirection: TComboBox
    Left = 16
    Height = 26
    Top = 294
    Width = 140
    Style = csDropDownList
    TabOrder = 6
  end
  object ChkInvert: TCheckBox
    Left = 170
    Height = 19
    Top = 297
    Width = 200
    Caption = 'Invert (near = deepest)'
    TabOrder = 7
  end
  object BtnGenerateRelief: TButton
    Left = 16
    Height = 30
    Top = 332
    Width = 180
    Caption = 'Generate CNC Relief'
    OnClick = BtnGenerateReliefClick
    TabOrder = 8
  end
end
