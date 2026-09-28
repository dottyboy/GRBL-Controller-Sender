object MaterialPresetFrame: TMaterialPresetFrame
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
    Height = 34
    Top = 0
    Width = 700
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 34
    ClientWidth = 700
    TabOrder = 0
    object BtnAdd: TButton
      Left = 4
      Height = 26
      Top = 4
      Width = 90
      Caption = 'Add Material'
      OnClick = BtnAddClick
      TabOrder = 0
    end
    object BtnDelete: TButton
      Left = 98
      Height = 26
      Top = 4
      Width = 70
      Caption = 'Delete'
      OnClick = BtnDeleteClick
      TabOrder = 1
    end
    object BtnApply: TButton
      Left = 172
      Height = 26
      Top = 4
      Width = 140
      Caption = 'Apply to Laser Control'
      OnClick = BtnApplyClick
      TabOrder = 2
    end
  end
  object Grid: TStringGrid
    Left = 0
    Height = 366
    Top = 34
    Width = 700
    Align = alClient
    ColCount = 6
    FixedRows = 1
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goEditing, goSmoothScroll]
    RowCount = 1
    TabOrder = 1
    OnEditingDone = GridEditingDone
    ColWidths = (
      130
      110
      80
      100
      60
      190
    )
  end
end
