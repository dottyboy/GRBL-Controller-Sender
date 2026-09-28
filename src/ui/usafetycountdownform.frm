object SafetyCountdownForm: TSafetyCountdownForm
  Left = 300
  Height = 190
  Top = 300
  Width = 340
  BorderStyle = bsDialog
  Caption = 'Laser Safety Countdown'
  ClientHeight = 190
  ClientWidth = 340
  Position = poScreenCenter
  OnCreate = FormCreate
  LCLVersion = '4.8.0.0'
  object LblMessage: TLabel
    Left = 16
    Height = 20
    Top = 16
    Width = 308
    Caption = 'Laser job starting...'
    Font.Height = -17
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblSeconds: TLabel
    Left = 16
    Height = 60
    Top = 48
    Width = 308
    Alignment = taCenter
    AutoSize = False
    Caption = '5'
    Font.Height = -48
    Layout = tlCenter
    ParentFont = False
  end
  object ChkDontShowAgain: TCheckBox
    Left = 16
    Height = 24
    Top = 116
    Width = 200
    Caption = 'Do not show this again'
    TabOrder = 0
  end
  object BtnCancel: TButton
    Left = 224
    Height = 32
    Top = 144
    Width = 100
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 1
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 1000
    OnTimer = Timer1Timer
    left = 264
    top = 16
  end
end
