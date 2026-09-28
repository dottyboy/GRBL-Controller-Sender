object JogFrame: TJogFrame
  Left = 0
  Height = 300
  Top = 0
  Width = 243
  Align = alLeft
  ClientHeight = 300
  ClientWidth = 243
  LCLVersion = '4.8.0.0'
  TabOrder = 0
  DesignLeft = 1008
  DesignTop = 341
  object LblStep: TLabel
    Left = 6
    Height = 32
    Top = 114
    Width = 51
    Alignment = taCenter
    Caption = 'Step X/Y'#10'(mm)'
  end
  object CboStep: TComboBox
    Left = 72
    Height = 26
    Top = 114
    Width = 56
    ItemHeight = 0
    ItemIndex = 1
    Items.Strings = (
      '0.1'
      '1'
      '10'
      '50'
    )
    Style = csDropDownList
    TabOrder = 0
    Text = '1'
  end
  object BtnYPlus: TButton
    Left = 40
    Height = 30
    Top = 8
    Width = 50
    Caption = 'Y+'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 1
    OnClick = JogClick
  end
  object BtnXMinus: TButton
    Left = 6
    Height = 30
    Top = 37
    Width = 50
    Caption = 'X-'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 2
    OnClick = JogClick
  end
  object BtnXPlus: TButton
    Left = 72
    Height = 30
    Top = 37
    Width = 50
    Caption = 'X+'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 3
    OnClick = JogClick
  end
  object BtnYMinus: TButton
    Left = 40
    Height = 30
    Top = 66
    Width = 50
    Caption = 'Y-'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 4
    OnClick = JogClick
  end
  object BtnZPlus: TButton
    Left = 168
    Height = 30
    Top = 8
    Width = 50
    Caption = 'Z+'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 5
    OnClick = JogClick
  end
  object BtnZMinus: TButton
    Left = 168
    Height = 30
    Top = 47
    Width = 50
    Caption = 'Z-'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 6
    OnClick = JogClick
  end
  object BtnHome: TButton
    Left = 6
    Height = 26
    Top = 168
    Width = 60
    Caption = 'Home'
    Font.Name = 'Ubuntu'
    ParentFont = False
    TabOrder = 7
    OnClick = HomeClick
  end
  object BtnUnlock: TButton
    Left = 70
    Height = 26
    Top = 168
    Width = 60
    Caption = 'Unlock'
    Font.Name = 'Ubuntu'
    ParentFont = False
    TabOrder = 8
    OnClick = UnlockClick
  end
  object BtnHold: TButton
    Left = 134
    Height = 26
    Top = 168
    Width = 60
    Caption = 'Hold'
    Font.Name = 'Ubuntu'
    ParentFont = False
    TabOrder = 9
    OnClick = HoldClick
  end
  object BtnResume: TButton
    Left = 6
    Height = 26
    Top = 198
    Width = 60
    Caption = 'Resume'
    Font.Name = 'Ubuntu'
    ParentFont = False
    TabOrder = 10
    OnClick = ResumeClick
  end
  object BtnReset: TButton
    Left = 70
    Height = 26
    Top = 198
    Width = 60
    Caption = 'Reset'
    Font.Name = 'Ubuntu'
    ParentFont = False
    TabOrder = 11
    OnClick = ResetClick
  end
  object CboStepZ: TComboBox
    Left = 162
    Height = 26
    Top = 114
    Width = 56
    ItemHeight = 0
    ItemIndex = 1
    Items.Strings = (
      '0.1'
      '1'
      '10'
      '50'
    )
    Style = csDropDownList
    TabOrder = 12
    Text = '1'
  end
  object LblStepZ: TLabel
    Left = 176
    Height = 32
    Top = 82
    Width = 38
    Alignment = taCenter
    Caption = 'Step Z'#10'(mm)'
  end
end
