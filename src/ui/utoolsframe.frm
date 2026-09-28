object ToolsFrame: TToolsFrame
  Left = 0
  Height = 400
  Top = 0
  Width = 600
  Align = alClient
  ClientHeight = 400
  ClientWidth = 600
  TabOrder = 0
  object ToolBar: TPanel
    Left = 0
    Height = 34
    Top = 0
    Width = 600
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 34
    ClientWidth = 600
    TabOrder = 0
    object BtnAdd: TButton
      Left = 4
      Height = 26
      Top = 4
      Width = 70
      Caption = 'Add Tool'
      OnClick = BtnAddClick
      TabOrder = 0
    end
    object BtnDelete: TButton
      Left = 78
      Height = 26
      Top = 4
      Width = 70
      Caption = 'Delete'
      OnClick = BtnDeleteClick
      TabOrder = 1
    end
    object BtnUse: TButton
      Left = 152
      Height = 26
      Top = 4
      Width = 110
      Caption = 'Use Selected'
      OnClick = BtnUseClick
      TabOrder = 2
    end
  end
  object Grid: TStringGrid
    Left = 0
    Height = 366
    Top = 34
    Width = 600
    Align = alClient
    ColCount = 6
    FixedRows = 1
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goEditing, goSmoothScroll]
    RowCount = 1
    TabOrder = 1
    OnEditingDone = GridEditingDone
    ColWidths = (
      140
      80
      60
      70
      80
      160
    )
  end
end
