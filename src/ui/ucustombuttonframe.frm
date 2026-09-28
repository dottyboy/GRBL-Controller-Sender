object CustomButtonFrame: TCustomButtonFrame
  Left = 0
  Height = 400
  Top = 0
  Width = 700
  Align = alClient
  ClientHeight = 400
  ClientWidth = 700
  TabOrder = 0
  object ToolBar: TPanel
    Left = 0
    Height = 50
    Top = 0
    Width = 700
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 50
    ClientWidth = 700
    TabOrder = 0
    object BtnAdd: TButton
      Left = 4
      Height = 26
      Top = 4
      Width = 100
      Caption = 'Add Button'
      OnClick = BtnAddClick
      TabOrder = 0
    end
    object BtnDelete: TButton
      Left = 112
      Height = 26
      Top = 4
      Width = 70
      Caption = 'Delete'
      OnClick = BtnDeleteClick
      TabOrder = 1
    end
    object LblHint: TLabel
      Left = 4
      Height = 15
      Top = 34
      Width = 400
      Caption = 'Each button enqueues its g-code when clicked on the Laser Control tab.'
    end
  end
  object Grid: TStringGrid
    Left = 0
    Height = 350
    Top = 50
    Width = 700
    Align = alClient
    ColCount = 2
    FixedRows = 1
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goEditing, goSmoothScroll]
    RowCount = 1
    TabOrder = 1
    OnEditingDone = GridEditingDone
    ColWidths = (
      150
      520
    )
  end
end
