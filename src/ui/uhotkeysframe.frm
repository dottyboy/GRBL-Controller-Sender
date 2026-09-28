object HotkeysFrame: THotkeysFrame
  Left = 0
  Height = 400
  Top = 0
  Width = 500
  Align = alClient
  ClientHeight = 400
  ClientWidth = 500
  TabOrder = 0
  object ToolBar: TPanel
    Left = 0
    Height = 50
    Top = 0
    Width = 500
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 50
    ClientWidth = 500
    TabOrder = 0
    object BtnRebind: TButton
      Left = 4
      Height = 28
      Top = 4
      Width = 110
      Caption = 'Rebind Selected'
      OnClick = BtnRebindClick
      TabOrder = 0
    end
    object LblHint: TLabel
      Left = 4
      Height = 15
      Top = 34
      Width = 400
      Caption = ''
      Font.Color = clGreen
      ParentFont = False
    end
  end
  object Grid: TStringGrid
    Left = 0
    Height = 350
    Top = 50
    Width = 500
    Align = alClient
    ColCount = 2
    FixedRows = 1
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect]
    RowCount = 1
    TabOrder = 1
    ColWidths = (
      220
      260
    )
  end
end
