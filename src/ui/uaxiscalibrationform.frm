object AxisCalibrationForm: TAxisCalibrationForm
  Left = 260
  Height = 340
  Top = 160
  Width = 460
  BorderStyle = bsDialog
  Caption = 'Axis Calibration'
  ClientHeight = 340
  ClientWidth = 460
  Position = poScreenCenter
  OnCreate = FormCreate
  LCLVersion = '4.8.0.0'
  object RbAxisX: TRadioButton
    Left = 16
    Height = 24
    Top = 16
    Width = 60
    Caption = 'X'
    OnChange = AxisChanged
    TabOrder = 0
  end
  object RbAxisY: TRadioButton
    Left = 100
    Height = 24
    Top = 16
    Width = 60
    Caption = 'Y'
    OnChange = AxisChanged
    TabOrder = 1
  end
  object RbAxisZ: TRadioButton
    Left = 184
    Height = 24
    Top = 16
    Width = 60
    Caption = 'Z'
    OnChange = AxisChanged
    TabOrder = 2
  end
  object LblCurrentStepsCaption: TLabel
    Left = 16
    Height = 17
    Top = 56
    Width = 140
    Caption = 'Current steps/mm:'
  end
  object LblCurrentStepsVal: TLabel
    Left = 200
    Height = 17
    Top = 56
    Width = 8
    Caption = '?'
  end
  object LblDistanceCaption: TLabel
    Left = 16
    Height = 17
    Top = 92
    Width = 150
    Caption = 'Distance to jog (mm):'
  end
  object EdDistance: TFloatSpinEdit
    Left = 200
    Height = 24
    Top = 88
    Width = 100
    DecimalPlaces = 2
    Increment = 1
    MaxValue = 10000
    MinValue = 1
    TabOrder = 3
    Value = 100
  end
  object BtnJog: TButton
    Left = 320
    Height = 26
    Top = 86
    Width = 120
    Caption = 'Jog +'
    OnClick = BtnJogClick
    TabOrder = 4
  end
  object LblMeasuredCaption: TLabel
    Left = 16
    Height = 17
    Top = 132
    Width = 220
    Caption = 'Measured actual distance (mm):'
  end
  object EdMeasured: TFloatSpinEdit
    Left = 260
    Height = 24
    Top = 128
    Width = 100
    DecimalPlaces = 3
    Increment = 0.1
    MaxValue = 10000
    MinValue = 0.001
    OnChange = EdMeasuredChange
    TabOrder = 5
    Value = 100
  end
  object LblFormula: TLabel
    Left = 16
    Height = 17
    Top = 172
    Width = 3
    Caption = ''
  end
  object LblStatus: TLabel
    Left = 16
    Height = 17
    Top = 208
    Width = 3
    Caption = ''
  end
  object BtnApply: TButton
    Left = 16
    Height = 30
    Top = 244
    Width = 200
    Caption = 'Apply to Grbl Config'
    Enabled = False
    OnClick = BtnApplyClick
    TabOrder = 6
  end
  object BtnClose: TButton
    Left = 358
    Height = 30
    Top = 292
    Width = 86
    Caption = 'Close'
    Default = True
    ModalResult = 1
    TabOrder = 7
  end
  object RefreshTimer: TTimer
    Enabled = False
    Interval = 900
    OnTimer = RefreshTimerTimer
    left = 400
    top = 16
  end
end
