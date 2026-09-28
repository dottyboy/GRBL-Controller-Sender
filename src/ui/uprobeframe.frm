object ProbeFrame: TProbeFrame
  Left = 0
  Height = 400
  Top = 0
  Width = 700
  Align = alClient
  ClientHeight = 400
  ClientWidth = 700
  TabOrder = 0
  object ConfigPanel: TPanel
    Left = 0
    Height = 92
    Top = 0
    Width = 700
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 92
    ClientWidth = 700
    TabOrder = 0
    object LblXRange: TLabel
      Left = 8
      Height = 17
      Top = 8
      Width = 68
      Caption = 'X min/max'
    end
    object EdXMin: TEdit
      Left = 90
      Height = 25
      Top = 4
      Width = 60
      Text = '0'
    end
    object EdXMax: TEdit
      Left = 156
      Height = 25
      Top = 4
      Width = 60
      Text = '100'
    end
    object LblYRange: TLabel
      Left = 228
      Height = 17
      Top = 8
      Width = 68
      Caption = 'Y min/max'
    end
    object EdYMin: TEdit
      Left = 310
      Height = 25
      Top = 4
      Width = 60
      Text = '0'
    end
    object EdYMax: TEdit
      Left = 376
      Height = 25
      Top = 4
      Width = 60
      Text = '100'
    end
    object LblGrid: TLabel
      Left = 448
      Height = 17
      Top = 8
      Width = 46
      Caption = 'Grid NxN'
    end
    object EdXN: TEdit
      Left = 508
      Height = 25
      Top = 4
      Width = 40
      Text = '5'
    end
    object EdYN: TEdit
      Left = 552
      Height = 25
      Top = 4
      Width = 40
      Text = '5'
    end
    object LblZRange: TLabel
      Left = 8
      Height = 17
      Top = 40
      Width = 96
      Caption = 'Probe Z / Clear Z'
    end
    object EdZMin: TEdit
      Left = 110
      Height = 25
      Top = 36
      Width = 60
      Text = '-5'
    end
    object EdZMax: TEdit
      Left = 176
      Height = 25
      Top = 36
      Width = 60
      Text = '3'
    end
    object LblSafeZ: TLabel
      Left = 248
      Height = 17
      Top = 40
      Width = 44
      Caption = 'Safe Z'
    end
    object EdSafeZ: TEdit
      Left = 296
      Height = 25
      Top = 36
      Width = 50
      Text = '5'
    end
    object LblFeed: TLabel
      Left = 356
      Height = 17
      Top = 40
      Width = 60
      Caption = 'Probe feed'
    end
    object EdFeed: TEdit
      Left = 424
      Height = 25
      Top = 36
      Width = 60
      Text = '10'
    end
    object BtnScan: TButton
      Left = 8
      Height = 26
      Top = 66
      Width = 100
      Caption = 'Start Scan'
      OnClick = BtnScanClick
      TabOrder = 0
    end
    object BtnZero: TButton
      Left = 112
      Height = 26
      Top = 66
      Width = 110
      Caption = 'Zero at Current'
      OnClick = BtnZeroClick
      TabOrder = 1
    end
    object BtnSave: TButton
      Left = 226
      Height = 26
      Top = 66
      Width = 70
      Caption = 'Save...'
      OnClick = BtnSaveClick
      TabOrder = 2
    end
    object BtnLoad: TButton
      Left = 300
      Height = 26
      Top = 66
      Width = 70
      Caption = 'Load...'
      OnClick = BtnLoadClick
      TabOrder = 3
    end
    object LblStatus: TLabel
      Left = 384
      Height = 17
      Top = 71
      Width = 84
      Caption = 'Grid not started'
    end
  end
  object TouchProbePanel: TPanel
    Left = 0
    Height = 76
    Top = 92
    Width = 700
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 76
    ClientWidth = 700
    TabOrder = 2
    object LblProbeType: TLabel
      Left = 8
      Height = 17
      Top = 8
      Width = 60
      Caption = 'Probe type'
    end
    object CboProbeType: TComboBox
      Left = 8
      Height = 25
      Top = 26
      Width = 170
      ItemHeight = 0
      ItemIndex = 0
      Items.Strings = (
        'Z Touch-off'
        'Corner / Bore Center'
        'Edge Finder'
      )
      Style = csDropDownList
      TabOrder = 0
      Text = 'Z Touch-off'
      OnChange = CboProbeTypeChange
    end
    object LblTPDiameter: TLabel
      Left = 190
      Height = 17
      Top = 8
      Width = 88
      Caption = 'Tip/feature dia.'
    end
    object EdTPDiameter: TEdit
      Left = 190
      Height = 25
      Top = 26
      Width = 60
      Text = '6'
    end
    object LblTPZOffset: TLabel
      Left = 300
      Height = 17
      Top = 8
      Width = 50
      Caption = 'Z offset'
    end
    object EdTPZOffset: TEdit
      Left = 300
      Height = 25
      Top = 26
      Width = 60
      Text = '0'
    end
    object LblTPRetract: TLabel
      Left = 370
      Height = 17
      Top = 8
      Width = 44
      Caption = 'Retract'
    end
    object EdTPRetract: TEdit
      Left = 370
      Height = 25
      Top = 26
      Width = 60
      Text = '2'
    end
    object LblTPSearchDist: TLabel
      Left = 440
      Height = 17
      Top = 8
      Width = 66
      Caption = 'Search dist'
    end
    object EdTPSearchDist: TEdit
      Left = 440
      Height = 25
      Top = 26
      Width = 60
      Text = '25'
    end
    object CboEdgeAxis: TComboBox
      Left = 510
      Height = 25
      Top = 26
      Width = 70
      ItemHeight = 0
      ItemIndex = 0
      Items.Strings = (
        'X-'
        'X+'
        'Y-'
        'Y+'
      )
      Style = csDropDownList
      TabOrder = 1
      Text = 'X-'
    end
    object BtnTouchProbe: TButton
      Left = 590
      Height = 26
      Top = 26
      Width = 90
      Caption = 'Probe'
      OnClick = BtnTouchProbeClick
      TabOrder = 2
    end
    object LblTouchStatus: TLabel
      Left = 8
      Height = 17
      Top = 56
      Width = 22
      Caption = 'Idle'
    end
  end
  object Grid: TStringGrid
    Left = 0
    Height = 232
    Top = 168
    Width = 700
    Align = alClient
    ColCount = 2
    FixedCols = 0
    RowCount = 2
    TabOrder = 1
  end
end
