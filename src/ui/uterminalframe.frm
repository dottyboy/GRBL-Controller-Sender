object TerminalFrame: TTerminalFrame
  Left = 0
  Height = 400
  Top = 0
  Width = 600
  Align = alClient
  ClientHeight = 400
  ClientWidth = 600
  TabOrder = 0
  object Memo: TMemo
    Left = 0
    Height = 307
    Top = 0
    Width = 600
    Align = alClient
    Font.Name = 'Monospace'
    Lines.Strings = (
      ''
    )
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssAutoVertical
    TabOrder = 0
  end
  object EdCommand: TEdit
    Left = 0
    Height = 25
    Top = 375
    Width = 600
    Align = alBottom
    OnKeyPress = EdCommandKeyPress
    TabOrder = 1
  end
  object BtnClear: TButton
    Left = 0
    Height = 34
    Top = 341
    Width = 600
    Align = alBottom
    Caption = 'Clear'
    OnClick = ClearClick
    TabOrder = 2
  end
  object BtnSend: TButton
    Left = 0
    Height = 34
    Top = 307
    Width = 600
    Align = alBottom
    Caption = 'Send'
    OnClick = SendClick
    TabOrder = 3
  end
end
