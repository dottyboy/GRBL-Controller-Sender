object ResumeJobForm: TResumeJobForm
  Left = 300
  Height = 380
  Top = 200
  Width = 420
  BorderStyle = bsDialog
  Caption = 'Resume Laser Job'
  ClientHeight = 380
  ClientWidth = 420
  Position = poScreenCenter
  OnCreate = FormCreate
  LCLVersion = '4.8.0.0'
  object LblCause: TLabel
    Left = 16
    Height = 15
    Top = 12
    Width = 60
    Caption = 'Cause:'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblCauseValue: TLabel
    Left = 16
    Height = 15
    Top = 32
    Width = 388
    AutoSize = False
    Caption = ''
  end
  object LblCounts: TLabel
    Left = 16
    Height = 15
    Top = 60
    Width = 388
    AutoSize = False
    Caption = ''
  end
  object RbFromBeginning: TRadioButton
    Left = 16
    Height = 24
    Top = 92
    Width = 388
    Caption = 'From the beginning'
    OnChange = RbCheckedChanged
    TabOrder = 0
  end
  object RbFromExecuted: TRadioButton
    Left = 16
    Height = 24
    Top = 116
    Width = 388
    Caption = 'From last executed line'
    OnChange = RbCheckedChanged
    TabOrder = 1
  end
  object RbFromSent: TRadioButton
    Left = 16
    Height = 24
    Top = 140
    Width = 388
    Caption = 'From last sent line'
    OnChange = RbCheckedChanged
    TabOrder = 2
  end
  object RbFromSpecific: TRadioButton
    Left = 16
    Height = 24
    Top = 164
    Width = 160
    Caption = 'From line #'
    OnChange = RbCheckedChanged
    TabOrder = 3
  end
  object SpecificLine: TSpinEdit
    Left = 184
    Height = 24
    Top = 162
    Width = 100
    MaxValue = 999999
    MinValue = 1
    TabOrder = 4
    Value = 1
  end
  object CbRedoHoming: TCheckBox
    Left = 16
    Height = 24
    Top = 204
    Width = 300
    Caption = 'Re-home before resuming ($H)'
    OnChange = CbRedoHomingChange
    TabOrder = 5
  end
  object CbUnlockOnly: TCheckBox
    Left = 16
    Height = 24
    Top = 228
    Width = 300
    Caption = 'Unlock alarm without homing ($X)'
    TabOrder = 6
  end
  object CbRestoreWCO: TCheckBox
    Left = 16
    Height = 24
    Top = 252
    Width = 388
    Caption = 'Restore work offset'
    TabOrder = 7
  end
  object BtnOK: TButton
    Left = 196
    Height = 32
    Top = 320
    Width = 100
    Caption = 'OK'
    Default = True
    ModalResult = 1
    OnClick = BtnOKClick
    TabOrder = 8
  end
  object BtnCancel: TButton
    Left = 304
    Height = 32
    Top = 320
    Width = 100
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    OnClick = BtnCancelClick
    TabOrder = 9
  end
end
