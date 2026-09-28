object AxesEditForm: TAxesEditForm
  Left = 0
  Height = 560
  Top = 0
  Width = 560
  Caption = 'Edit Axes (FluidNC config.yaml)'
  ClientHeight = 560
  ClientWidth = 560
  Position = poScreenCenter
  object LblAxis: TLabel
    Left = 12
    Height = 17
    Top = 12
    Width = 30
    Caption = 'Axis'
  end
  object CboAxis: TComboBox
    Left = 12
    Height = 26
    Top = 30
    Width = 70
    Style = csDropDownList
    OnChange = CboAxisChange
    TabOrder = 0
  end
  object LblMotor: TLabel
    Left = 100
    Height = 17
    Top = 12
    Width = 40
    Caption = 'Motor'
  end
  object CboMotor: TComboBox
    Left = 100
    Height = 26
    Top = 30
    Width = 100
    Style = csDropDownList
    OnChange = CboMotorChange
    TabOrder = 1
  end
  object LblAxisSection: TLabel
    Left = 12
    Height = 17
    Top = 68
    Width = 90
    Caption = 'Axis parameters'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblStepsPerMM: TLabel
    Left = 12
    Height = 17
    Top = 92
    Width = 76
    Caption = 'Steps / mm'
  end
  object EdStepsPerMM: TEdit
    Left = 140
    Height = 25
    Top = 88
    Width = 90
  end
  object LblMaxRate: TLabel
    Left = 250
    Height = 17
    Top = 92
    Width = 100
    Caption = 'Max rate mm/min'
  end
  object EdMaxRate: TEdit
    Left = 400
    Height = 25
    Top = 88
    Width = 90
  end
  object LblAcceleration: TLabel
    Left = 12
    Height = 17
    Top = 122
    Width = 110
    Caption = 'Accel mm/sec2'
  end
  object EdAcceleration: TEdit
    Left = 140
    Height = 25
    Top = 118
    Width = 90
  end
  object LblMaxTravel: TLabel
    Left = 250
    Height = 17
    Top = 122
    Width = 96
    Caption = 'Max travel mm'
  end
  object EdMaxTravel: TEdit
    Left = 400
    Height = 25
    Top = 118
    Width = 90
  end
  object ChkSoftLimits: TCheckBox
    Left = 12
    Height = 21
    Top = 150
    Width = 90
    Caption = 'Soft limits'
    TabOrder = 2
  end
  object LblHomingSection: TLabel
    Left = 12
    Height = 17
    Top = 182
    Width = 60
    Caption = 'Homing'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblHomingCycle: TLabel
    Left = 12
    Height = 17
    Top = 206
    Width = 32
    Caption = 'Cycle'
  end
  object EdHomingCycle: TEdit
    Left = 140
    Height = 25
    Top = 202
    Width = 90
  end
  object ChkPositiveDirection: TCheckBox
    Left = 250
    Height = 21
    Top = 204
    Width = 130
    Caption = 'Positive direction'
    TabOrder = 3
  end
  object LblMposMM: TLabel
    Left = 12
    Height = 17
    Top = 236
    Width = 60
    Caption = 'Mpos mm'
  end
  object EdMposMM: TEdit
    Left = 140
    Height = 25
    Top = 232
    Width = 90
  end
  object LblFeedRate: TLabel
    Left = 250
    Height = 17
    Top = 236
    Width = 108
    Caption = 'Feed rate mm/min'
  end
  object EdFeedRate: TEdit
    Left = 400
    Height = 25
    Top = 232
    Width = 90
  end
  object LblSeekRate: TLabel
    Left = 12
    Height = 17
    Top = 266
    Width = 108
    Caption = 'Seek rate mm/min'
  end
  object EdSeekRate: TEdit
    Left = 140
    Height = 25
    Top = 262
    Width = 90
  end
  object LblSettleMs: TLabel
    Left = 250
    Height = 17
    Top = 266
    Width = 62
    Caption = 'Settle ms'
  end
  object EdSettleMs: TEdit
    Left = 400
    Height = 25
    Top = 262
    Width = 90
  end
  object LblSeekScaler: TLabel
    Left = 12
    Height = 17
    Top = 296
    Width = 66
    Caption = 'Seek scaler'
  end
  object EdSeekScaler: TEdit
    Left = 140
    Height = 25
    Top = 292
    Width = 90
  end
  object LblFeedScaler: TLabel
    Left = 250
    Height = 17
    Top = 296
    Width = 64
    Caption = 'Feed scaler'
  end
  object EdFeedScaler: TEdit
    Left = 400
    Height = 25
    Top = 292
    Width = 90
  end
  object LblMotorSection: TLabel
    Left = 12
    Height = 17
    Top = 328
    Width = 88
    Caption = 'Motor / driver'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblLimitNegPin: TLabel
    Left = 12
    Height = 17
    Top = 352
    Width = 62
    Caption = 'Limit- pin'
  end
  object EdLimitNegPin: TEdit
    Left = 140
    Height = 25
    Top = 348
    Width = 90
  end
  object LblLimitPosPin: TLabel
    Left = 250
    Height = 17
    Top = 352
    Width = 62
    Caption = 'Limit+ pin'
  end
  object EdLimitPosPin: TEdit
    Left = 400
    Height = 25
    Top = 348
    Width = 90
  end
  object LblLimitAllPin: TLabel
    Left = 12
    Height = 17
    Top = 382
    Width = 74
    Caption = 'Limit-all pin'
  end
  object EdLimitAllPin: TEdit
    Left = 140
    Height = 25
    Top = 378
    Width = 90
  end
  object ChkHardLimits: TCheckBox
    Left = 250
    Height = 21
    Top = 380
    Width = 100
    Caption = 'Hard limits'
    TabOrder = 4
  end
  object LblPulloffMM: TLabel
    Left = 12
    Height = 17
    Top = 412
    Width = 66
    Caption = 'Pulloff mm'
  end
  object EdPulloffMM: TEdit
    Left = 140
    Height = 25
    Top = 408
    Width = 90
  end
  object LblDriverType: TLabel
    Left = 250
    Height = 17
    Top = 412
    Width = 62
    Caption = 'Driver type'
  end
  object CboDriverType: TComboBox
    Left = 400
    Height = 25
    Top = 408
    Width = 148
    Style = csDropDownList
    OnChange = CboDriverTypeChange
    TabOrder = 5
  end
  object LblStepPin: TLabel
    Left = 12
    Height = 17
    Top = 442
    Width = 50
    Caption = 'Step pin'
  end
  object EdStepPin: TEdit
    Left = 140
    Height = 25
    Top = 438
    Width = 90
  end
  object LblDirectionPin: TLabel
    Left = 250
    Height = 17
    Top = 442
    Width = 76
    Caption = 'Direction pin'
  end
  object EdDirectionPin: TEdit
    Left = 400
    Height = 25
    Top = 438
    Width = 148
  end
  object LblDisablePin: TLabel
    Left = 12
    Height = 17
    Top = 472
    Width = 66
    Caption = 'Disable pin'
  end
  object EdDisablePin: TEdit
    Left = 140
    Height = 25
    Top = 468
    Width = 90
  end
  object LblMS3Pin: TLabel
    Left = 250
    Height = 17
    Top = 472
    Width = 52
    Caption = 'MS3 pin'
  end
  object EdMS3Pin: TEdit
    Left = 400
    Height = 25
    Top = 468
    Width = 148
  end
  object LblStatus: TLabel
    Left = 12
    Height = 17
    Top = 502
    Width = 536
    Caption = ''
    Font.Color = clRed
    ParentFont = False
    WordWrap = True
  end
  object BtnOK: TButton
    Left = 372
    Height = 26
    Top = 524
    Width = 80
    Caption = 'OK'
    ModalResult = 0
    OnClick = BtnOKClick
    TabOrder = 6
  end
  object BtnCancel: TButton
    Left = 460
    Height = 26
    Top = 524
    Width = 88
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 7
  end
end
