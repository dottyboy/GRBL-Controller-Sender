object SafetyCountdownFrame: TSafetyCountdownFrame
  Left = 0
  Height = 190
  Top = 0
  Width = 340
  ClientHeight = 190
  ClientWidth = 340
  TabOrder = 0
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
    OnClick = BtnCancelClick
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
