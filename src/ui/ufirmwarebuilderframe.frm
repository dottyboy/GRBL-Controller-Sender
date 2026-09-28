object FirmwareBuilderFrame: TFirmwareBuilderFrame
  Left = 0
  Height = 480
  Top = 0
  Width = 820
  Align = alClient
  ClientHeight = 480
  ClientWidth = 820
  TabOrder = 0
  object ToolBarBoard: TPanel
    Left = 0
    Height = 40
    Top = 0
    Width = 820
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 40
    ClientWidth = 820
    TabOrder = 0
    object LblEcosystem: TLabel
      Left = 8
      Height = 17
      Top = 12
      Width = 62
      Caption = 'Ecosystem'
    end
    object CboEcosystem: TComboBox
      Left = 76
      Height = 25
      Top = 8
      Width = 90
      Style = csDropDownList
      OnChange = CboEcosystemChange
      TabOrder = 0
    end
    object LblBoard: TLabel
      Left = 176
      Height = 17
      Top = 12
      Width = 32
      Caption = 'Board'
    end
    object CboBoard: TComboBox
      Left = 212
      Height = 25
      Top = 8
      Width = 320
      Style = csDropDownList
      OnChange = CboBoardChange
      TabOrder = 1
    end
    object BtnRefreshBoards: TButton
      Left = 540
      Height = 25
      Top = 8
      Width = 100
      Caption = 'Refresh Boards'
      OnClick = BtnRefreshBoardsClick
      TabOrder = 2
    end
  end
  object ToolBarAxes: TPanel
    Left = 0
    Height = 130
    Top = 40
    Width = 820
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 130
    ClientWidth = 820
    TabOrder = 1
    object LblAxisLetter: TLabel
      Left = 8
      Height = 17
      Top = 12
      Width = 60
      Caption = 'Dual-drive'
    end
    object CboAxisLetter: TComboBox
      Left = 76
      Height = 25
      Top = 8
      Width = 60
      Style = csDropDownList
      TabOrder = 0
    end
    object BtnAddAxis: TButton
      Left = 144
      Height = 25
      Top = 8
      Width = 130
      Caption = 'Add (auto-pick pins)'
      OnClick = BtnAddAxisClick
      TabOrder = 1
    end
    object BtnRemoveAxis: TButton
      Left = 282
      Height = 25
      Top = 8
      Width = 130
      Caption = 'Remove selected row'
      OnClick = BtnRemoveAxisClick
      TabOrder = 2
    end
    object GridAxes: TStringGrid
      Left = 8
      Height = 90
      Top = 38
      Width = 400
      ColCount = 3
      FixedCols = 0
      RowCount = 1
      TabOrder = 3
    end
  end
  object ToolBarModules: TPanel
    Left = 0
    Height = 90
    Top = 170
    Width = 820
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 90
    ClientWidth = 820
    TabOrder = 2
    object LblModules: TLabel
      Left = 8
      Height = 17
      Top = 6
      Width = 100
      Caption = 'Accessory modules'
    end
    object CheckListModules: TCheckListBox
      Left = 8
      Height = 76
      Top = 26
      Width = 500
      TabOrder = 0
      OnClickCheck = CheckListModulesClickCheck
    end
    object LblEncPulsePin: TLabel
      Left = 520
      Height = 17
      Top = 30
      Width = 96
      Caption = 'Encoder pulse DIN'
    end
    object EdEncPulsePin: TSpinEdit
      Left = 624
      Height = 25
      Top = 26
      Width = 60
      MaxValue = 63
      MinValue = 0
      OnChange = EdEncPulsePinChange
      TabOrder = 1
      Value = 6
    end
    object LblEncDirPin: TLabel
      Left = 520
      Height = 17
      Top = 62
      Width = 78
      Caption = 'Encoder dir DIN'
    end
    object EdEncDirPin: TSpinEdit
      Left = 624
      Height = 25
      Top = 58
      Width = 60
      MaxValue = 63
      MinValue = 0
      OnChange = EdEncDirPinChange
      TabOrder = 2
      Value = 7
    end
  end
  object ToolBarSetup: TPanel
    Left = 0
    Height = 40
    Top = 260
    Width = 820
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 40
    ClientWidth = 820
    TabOrder = 3
    object LblSetupName: TLabel
      Left = 8
      Height = 17
      Top = 12
      Width = 34
      Caption = 'Setup'
    end
    object EdSetupName: TEdit
      Left = 48
      Height = 25
      Top = 8
      Width = 140
    end
    object BtnSaveSetup: TButton
      Left = 196
      Height = 25
      Top = 8
      Width = 60
      Caption = 'Save'
      OnClick = BtnSaveSetupClick
      TabOrder = 0
    end
    object CboSetups: TComboBox
      Left = 264
      Height = 25
      Top = 8
      Width = 160
      Style = csDropDownList
      TabOrder = 1
    end
    object BtnLoadSetup: TButton
      Left = 432
      Height = 25
      Top = 8
      Width = 60
      Caption = 'Load'
      OnClick = BtnLoadSetupClick
      TabOrder = 2
    end
    object BtnDeleteSetup: TButton
      Left = 500
      Height = 25
      Top = 8
      Width = 70
      Caption = 'Delete'
      OnClick = BtnDeleteSetupClick
      TabOrder = 3
    end
  end
  object ToolBarActions: TPanel
    Left = 0
    Height = 70
    Top = 300
    Width = 820
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 70
    ClientWidth = 820
    TabOrder = 4
    object BtnGenerate: TButton
      Left = 8
      Height = 26
      Top = 8
      Width = 130
      Caption = 'Generate Project'
      OnClick = BtnGenerateClick
      TabOrder = 0
    end
    object LblGeneratedPath: TLabel
      Left = 146
      Height = 17
      Top = 14
      Width = 3
      Caption = ''
    end
    object BtnBuild: TButton
      Left = 8
      Height = 26
      Top = 38
      Width = 90
      Caption = 'Build'
      OnClick = BtnBuildClick
      TabOrder = 1
    end
    object LblPort: TLabel
      Left = 106
      Height = 17
      Top = 44
      Width = 26
      Caption = 'Port'
    end
    object CboPort: TComboBox
      Left = 138
      Height = 25
      Top = 38
      Width = 140
      TabOrder = 2
    end
    object BtnRefreshPorts: TButton
      Left = 284
      Height = 25
      Top = 38
      Width = 30
      Caption = '↻'
      OnClick = BtnRefreshPortsClick
      TabOrder = 3
    end
    object BtnUpload: TButton
      Left = 322
      Height = 26
      Top = 38
      Width = 90
      Caption = 'Upload'
      OnClick = BtnUploadClick
      TabOrder = 4
    end
  end
  object MemoLog: TMemo
    Left = 0
    Height = 110
    Top = 370
    Width = 820
    Align = alClient
    Font.Name = 'Monospace'
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssAutoVertical
    TabOrder = 5
  end
end
