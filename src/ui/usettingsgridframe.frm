object SettingsGridFrame: TSettingsGridFrame
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
    Height = 76
    Top = 0
    Width = 700
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 76
    ClientWidth = 700
    TabOrder = 0
    object BtnRefresh: TButton
      Left = 8
      Height = 26
      Top = 7
      Width = 100
      Caption = 'Refresh ($$)'
      OnClick = BtnRefreshClick
      TabOrder = 0
    end
    object BtnApply: TButton
      Left = 116
      Height = 26
      Top = 7
      Width = 130
      Caption = 'Apply Changed'
      OnClick = BtnApplyClick
      TabOrder = 1
    end
    object BtnFetchDescriptions: TButton
      Left = 254
      Height = 26
      Top = 7
      Width = 150
      Caption = 'Fetch Descriptions ($ES)'
      OnClick = BtnFetchDescriptionsClick
      TabOrder = 2
    end
    object LblStatus: TLabel
      Left = 412
      Height = 17
      Top = 12
      Width = 84
      Caption = 'Not connected'
    end
    object CboTemplate: TComboBox
      Left = 8
      Height = 26
      Top = 41
      Width = 280
      Style = csDropDownList
      OnChange = CboTemplateChange
      TabOrder = 3
    end
  end
  object Grid: TStringGrid
    Left = 0
    Height = 324
    Top = 76
    Width = 700
    Align = alClient
    ColCount = 3
    ColWidths = (
      50
      90
      400
    )
    FixedCols = 0
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goEditing]
    RowCount = 2
    TabOrder = 1
  end
  object RefreshTimer: TTimer
    Enabled = False
    Interval = 900
    OnTimer = RefreshTimerTimer
    left = 580
    top = 8
  end
  object DescTimer: TTimer
    Enabled = False
    Interval = 2000
    OnTimer = DescTimerTimer
    left = 620
    top = 8
  end
end
