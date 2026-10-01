object DepthMapFrame: TDepthMapFrame
  Left = 0
  Height = 160
  Top = 0
  Width = 520
  ClientHeight = 160
  ClientWidth = 520
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
end
