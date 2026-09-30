object LaserControlFrame: TLaserControlFrame
  Left = 0
  Height = 620
  Top = 0
  Width = 700
  Align = alClient
  ClientHeight = 620
  ClientWidth = 700
  TabOrder = 0
  object LblHeader: TLabel
    Left = 12
    Height = 15
    Top = 8
    Width = 40
    Caption = 'Header'
  end
  object MemoHeader: TMemo
    Left = 12
    Height = 70
    Top = 26
    Width = 320
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object CboHeaderFooterPreset: TComboBox
    Left = 100
    Height = 24
    Top = 4
    Width = 180
    Style = csDropDownList
    TabOrder = 10
  end
  object BtnLoadHeaderFooterPreset: TButton
    Left = 286
    Height = 24
    Top = 4
    Width = 64
    Caption = 'Load'
    OnClick = BtnLoadHeaderFooterPresetClick
    TabOrder = 11
  end
  object LblFooter: TLabel
    Left = 356
    Height = 15
    Top = 8
    Width = 36
    Caption = 'Footer'
  end
  object MemoFooter: TMemo
    Left = 356
    Height = 70
    Top = 26
    Width = 320
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object LblPasses: TLabel
    Left = 12
    Height = 15
    Top = 108
    Width = 42
    Caption = 'Passes'
  end
  object SpinPasses: TSpinEdit
    Left = 60
    Height = 24
    Top = 104
    Width = 70
    MaxValue = 999
    MinValue = 1
    TabOrder = 2
    Value = 1
  end
  object BtnStart: TButton
    Left = 12
    Height = 32
    Top = 140
    Width = 100
    Caption = 'Start'
    OnClick = BtnStartClick
    TabOrder = 3
  end
  object BtnPauseResume: TButton
    Left = 120
    Height = 32
    Top = 140
    Width = 100
    Caption = 'Pause'
    Enabled = False
    OnClick = BtnPauseResumeClick
    TabOrder = 4
  end
  object BtnAbort: TButton
    Left = 228
    Height = 32
    Top = 140
    Width = 100
    Caption = 'Abort'
    Enabled = False
    OnClick = BtnAbortClick
    TabOrder = 5
  end
  object LblProgress: TLabel
    Left = 12
    Height = 15
    Top = 184
    Width = 664
    AutoSize = False
    Caption = ''
  end
  object LblStatus: TLabel
    Left = 12
    Height = 15
    Top = 208
    Width = 664
    AutoSize = False
    Caption = ''
  end
  object LblFeed: TLabel
    Left = 12
    Height = 15
    Top = 244
    Width = 90
    Caption = 'Feed override'
  end
  object TrackFeed: TTrackBar
    Left = 12
    Height = 32
    Top = 262
    Width = 300
    Max = 200
    Min = 10
    Frequency = 10
    Position = 100
    OnChange = TrackFeedChange
    TabOrder = 6
  end
  object LblFeedValue: TLabel
    Left = 320
    Height = 15
    Top = 270
    Width = 40
    Caption = '100%'
  end
  object LblRapid: TLabel
    Left = 12
    Height = 15
    Top = 304
    Width = 96
    Caption = 'Rapid override'
  end
  object RbRapid100: TRadioButton
    Left = 12
    Height = 24
    Top = 322
    Width = 90
    Caption = '100%'
    Checked = True
    OnChange = RbRapidChange
    TabOrder = 7
    TabStop = True
  end
  object RbRapid50: TRadioButton
    Left = 106
    Height = 24
    Top = 322
    Width = 90
    Caption = '50%'
    OnChange = RbRapidChange
    TabOrder = 8
  end
  object RbRapid25: TRadioButton
    Left = 200
    Height = 24
    Top = 322
    Width = 90
    Caption = '25%'
    OnChange = RbRapidChange
    TabOrder = 9
  end
  object LblSpindle: TLabel
    Left = 12
    Height = 15
    Top = 360
    Width = 100
    Caption = 'Power override'
  end
  object TrackSpindle: TTrackBar
    Left = 12
    Height = 32
    Top = 378
    Width = 300
    Max = 200
    Min = 10
    Frequency = 10
    Position = 100
    OnChange = TrackSpindleChange
    TabOrder = 10
  end
  object LblSpindleValue: TLabel
    Left = 320
    Height = 15
    Top = 386
    Width = 40
    Caption = '100%'
  end
  object ChkAutoCooling: TCheckBox
    Left = 12
    Height = 24
    Top = 420
    Width = 140
    Caption = 'Auto-cooling'
    TabOrder = 11
  end
  object LblCoolOn: TLabel
    Left = 160
    Height = 15
    Top = 424
    Width = 44
    Caption = 'On (s)'
  end
  object EdCoolOn: TSpinEdit
    Left = 208
    Height = 24
    Top = 420
    Width = 70
    MaxValue = 3600
    MinValue = 1
    TabOrder = 12
    Value = 60
  end
  object LblCoolOff: TLabel
    Left = 288
    Height = 15
    Top = 424
    Width = 48
    Caption = 'Off (s)'
  end
  object EdCoolOff: TSpinEdit
    Left = 340
    Height = 24
    Top = 420
    Width = 70
    MaxValue = 3600
    MinValue = 1
    TabOrder = 13
    Value = 10
  end
  object ChkArmTestFire: TCheckBox
    Left = 12
    Height = 24
    Top = 460
    Width = 140
    Caption = 'Arm test fire'
    OnChange = ChkArmTestFireChange
    TabOrder = 14
  end
  object LblTestFirePower: TLabel
    Left = 160
    Height = 15
    Top = 464
    Width = 42
    Caption = 'Power'
  end
  object EdTestFirePower: TSpinEdit
    Left = 208
    Height = 24
    Top = 460
    Width = 70
    MaxValue = 1000
    MinValue = 1
    TabOrder = 15
    Value = 5
  end
  object BtnTestFire: TButton
    Left = 288
    Height = 28
    Top = 458
    Width = 120
    Caption = 'Test Fire'
    Enabled = False
    OnClick = BtnTestFireClick
    TabOrder = 16
  end
  object LblMacros: TLabel
    Left = 12
    Height = 15
    Top = 504
    Width = 46
    Caption = 'Macros'
  end
  object BtnEditMacros: TButton
    Left = 100
    Height = 24
    Top = 500
    Width = 120
    Caption = 'Edit Macros...'
    OnClick = BtnEditMacrosClick
    TabOrder = 17
  end
  object MacroPanel: TPanel
    Left = 12
    Height = 84
    Top = 528
    Width = 676
    BevelOuter = bvLowered
    ClientHeight = 84
    ClientWidth = 676
    TabOrder = 18
  end
end
