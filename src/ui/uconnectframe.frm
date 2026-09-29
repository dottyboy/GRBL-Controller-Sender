object ConnectFrame: TConnectFrame
  Left = 0
  Height = 103
  Top = 0
  Width = 677
  Align = alTop
  ClientHeight = 103
  ClientWidth = 677
  LCLVersion = '4.8.0.0'
  TabOrder = 0
  object LblPort: TLabel
    Left = 8
    Height = 16
    Top = 10
    Width = 26
    Caption = 'Port'
    Font.Name = 'Ubuntu'
    ParentFont = False
  end
  object CboPort: TComboBox
    Left = 40
    Height = 28
    Top = 6
    Width = 140
    Font.Name = 'Ubuntu'
    ItemHeight = 0
    ParentFont = False
    TabOrder = 0
  end
  object BtnRefresh: TButton
    Left = 184
    Height = 25
    Top = 5
    Width = 50
    Caption = 'Scan'
    Font.Name = 'Ubuntu'
    ParentFont = False
    TabOrder = 1
    OnClick = BtnRefreshClick
  end
  object LblBaud: TLabel
    Left = 246
    Height = 16
    Top = 10
    Width = 31
    Caption = 'Baud'
    Font.Name = 'Ubuntu'
    ParentFont = False
  end
  object CboBaud: TComboBox
    Left = 282
    Height = 26
    Top = 6
    Width = 90
    Font.Name = 'Ubuntu'
    ItemHeight = 0
    ItemIndex = 4
    Items.Strings = (
      '9600'
      '19200'
      '38400'
      '57600'
      '115200'
    )
    ParentFont = False
    Style = csDropDownList
    TabOrder = 2
    Text = '115200'
  end
  object LblController: TLabel
    Left = 380
    Height = 16
    Top = 10
    Width = 60
    Caption = 'Controller'
    Font.Name = 'Ubuntu'
    ParentFont = False
  end
  object CboController: TComboBox
    Left = 444
    Height = 26
    Top = 6
    Width = 110
    Font.Name = 'Ubuntu'
    ItemHeight = 0
    ItemIndex = 0
    Items.Strings = (
      'GRBL 1.x'
      'GRBL 0.9'
      'Smoothieware'
      'G2core'
    )
    ParentFont = False
    Style = csDropDownList
    TabOrder = 3
    Text = 'GRBL 1.x'
  end
  object BtnOpenClose: TButton
    Left = 564
    Height = 25
    Top = 5
    Width = 90
    Caption = 'Open'
    Font.Name = 'Ubuntu'
    ParentFont = False
    TabOrder = 4
    OnClick = BtnOpenCloseClick
  end
  object LblState: TLabel
    Left = 8
    Height = 16
    Top = 36
    Width = 94
    Caption = 'Not connected'
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblBoardInfo: TLabel
    AnchorSideLeft.Control = LblState
    AnchorSideLeft.Side = asrBottom
    Left = 125
    Height = 16
    Top = 36
    Width = 164
    BorderSpacing.Left = 23
    Caption = 'Board info not yet detected'
    Font.Name = 'Ubuntu'
    ParentFont = False
  end
  object LblBoardProfile: TLabel
    Left = 8
    Height = 16
    Top = 67
    Width = 39
    Caption = 'Profile'
    Font.Name = 'Ubuntu'
    ParentFont = False
  end
  object CboBoardProfile: TComboBox
    Left = 56
    Height = 30
    Top = 62
    Width = 320
    Font.Name = 'Ubuntu'
    ItemHeight = 0
    ParentFont = False
    Style = csDropDownList
    TabOrder = 5
    OnChange = CboBoardProfileChange
  end
  object BtnRefreshInfo: TButton
    Left = 384
    Height = 25
    Top = 62
    Width = 90
    Caption = 'Refresh Info'
    Font.Name = 'Ubuntu'
    ParentFont = False
    TabOrder = 6
    OnClick = BtnRefreshInfoClick
  end
  object BtnWiFi: TButton
    Left = 484
    Height = 25
    Top = 62
    Width = 90
    Caption = 'WiFi...'
    Font.Name = 'Ubuntu'
    ParentFont = False
    TabOrder = 7
    OnClick = BtnWiFiClick
  end
end
