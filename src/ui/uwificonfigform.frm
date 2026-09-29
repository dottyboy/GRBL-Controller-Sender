object WiFiConfigForm: TWiFiConfigForm
  Left = 220
  Height = 520
  Top = 140
  Width = 620
  BorderStyle = bsDialog
  Caption = 'Connect via WiFi'
  ClientHeight = 520
  ClientWidth = 620
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  LCLVersion = '4.8.0.0'
  object LblDirectHeader: TLabel
    Left = 12
    Height = 17
    Top = 12
    Width = 220
    Caption = 'Connect directly (host:port)'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblHost: TLabel
    Left = 12
    Height = 17
    Top = 44
    Width = 28
    Caption = 'Host'
  end
  object EdHost: TEdit
    Left = 60
    Height = 25
    Top = 40
    Width = 220
    TabOrder = 0
  end
  object LblPort: TLabel
    Left = 296
    Height = 17
    Top = 44
    Width = 24
    Caption = 'Port'
  end
  object EdPort: TEdit
    Left = 330
    Height = 25
    Top = 40
    Width = 70
    Text = '23'
    TabOrder = 1
  end
  object BtnDirectConnect: TButton
    Left = 420
    Height = 25
    Top = 40
    Width = 160
    Caption = 'Use This Connection'
    OnClick = BtnDirectConnectClick
    TabOrder = 2
  end
  object LblScanHeader: TLabel
    Left = 12
    Height = 17
    Top = 84
    Width = 220
    Caption = 'Scan local network'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblBaseIP: TLabel
    Left = 12
    Height = 17
    Top = 116
    Width = 50
    Caption = 'Base IP'
  end
  object EdBaseIP: TEdit
    Left = 70
    Height = 25
    Top = 112
    Width = 130
    TabOrder = 3
  end
  object LblSubnetMask: TLabel
    Left = 210
    Height = 17
    Top = 116
    Width = 40
    Caption = 'Mask'
  end
  object EdSubnetMask: TEdit
    Left = 254
    Height = 25
    Top = 112
    Width = 130
    Text = '255.255.255.0'
    TabOrder = 4
  end
  object BtnScan: TButton
    Left = 420
    Height = 25
    Top = 112
    Width = 90
    Caption = 'Scan'
    OnClick = BtnScanClick
    TabOrder = 5
  end
  object BtnStopScan: TButton
    Left = 514
    Height = 25
    Top = 112
    Width = 90
    Caption = 'Stop'
    Enabled = False
    OnClick = BtnStopScanClick
    TabOrder = 6
  end
  object LblScanProgress: TLabel
    Left = 12
    Height = 17
    Top = 144
    Width = 3
    Caption = ''
  end
  object LbResults: TListBox
    Left = 12
    Height = 130
    Top = 168
    Width = 596
    OnSelectionChange = LbResultsSelectionChange
    TabOrder = 7
  end
  object BtnUseSelected: TButton
    Left = 12
    Height = 25
    Top = 304
    Width = 160
    Caption = 'Use Selected Result'
    Enabled = False
    OnClick = BtnUseSelectedClick
    TabOrder = 8
  end
  object LblConfigHeader: TLabel
    Left = 12
    Height = 17
    Top = 348
    Width = 280
    Caption = 'Write WiFi credentials to connected board'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblConfigNote: TLabel
    Left = 12
    Height = 34
    Top = 368
    Width = 596
    AutoSize = False
    WordWrap = True
    Caption = 'Only works while already connected via USB serial to an Ortur/Longer grblHAL board - sends real $74/$75/$WRS or $sta/... commands over that connection, watch the Terminal tab for the assigned IP.'
  end
  object LblSSID: TLabel
    Left = 12
    Height = 17
    Top = 412
    Width = 26
    Caption = 'SSID'
  end
  object EdSSID: TEdit
    Left = 60
    Height = 25
    Top = 408
    Width = 200
    TabOrder = 9
  end
  object LblWiFiPassword: TLabel
    Left = 270
    Height = 17
    Top = 412
    Width = 50
    Caption = 'Password'
  end
  object EdWiFiPassword: TEdit
    Left = 330
    Height = 25
    Top = 408
    Width = 180
    TabOrder = 10
  end
  object CbBoardKind: TComboBox
    Left = 12
    Height = 25
    Top = 444
    Width = 120
    ItemHeight = 17
    Style = csDropDownList
    TabOrder = 11
  end
  object BtnWriteConfig: TButton
    Left = 140
    Height = 25
    Top = 444
    Width = 160
    Caption = 'Write Config'
    OnClick = BtnWriteConfigClick
    TabOrder = 12
  end
  object BtnClose: TButton
    Left = 518
    Height = 32
    Top = 476
    Width = 90
    Caption = 'Close'
    Cancel = True
    Default = True
    ModalResult = 2
    TabOrder = 13
  end
end
