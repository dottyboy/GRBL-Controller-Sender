object EditorFrame: TEditorFrame
  Left = 0
  Height = 400
  Top = 0
  Width = 600
  Align = alClient
  ClientHeight = 400
  ClientWidth = 600
  TabOrder = 0
  object ToolBar: TPanel
    Left = 0
    Height = 34
    Top = 0
    Width = 600
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 34
    ClientWidth = 600
    TabOrder = 0
    object BtnOpen: TButton
      Left = 4
      Height = 26
      Top = 4
      Width = 70
      Caption = 'Open...'
      OnClick = BtnOpenClick
      TabOrder = 0
    end
    object BtnSave: TButton
      Left = 78
      Height = 26
      Top = 4
      Width = 70
      Caption = 'Save'
      OnClick = BtnSaveClick
      TabOrder = 1
    end
    object BtnSaveAs: TButton
      Left = 152
      Height = 26
      Top = 4
      Width = 80
      Caption = 'Save As...'
      OnClick = BtnSaveAsClick
      TabOrder = 2
    end
    object BtnSend: TButton
      Left = 260
      Height = 26
      Top = 4
      Width = 100
      Caption = 'Send Program'
      OnClick = BtnSendClick
      TabOrder = 3
    end
    object BtnStop: TButton
      Left = 364
      Height = 26
      Top = 4
      Width = 70
      Caption = 'Stop'
      OnClick = BtnStopClick
      TabOrder = 4
    end
    object LblFile: TLabel
      Left = 444
      Height = 17
      Top = 9
      Width = 56
      Caption = '(untitled)'
    end
  end
  object SynEditor: TSynEdit
    Left = 0
    Height = 366
    Top = 34
    Width = 600
    Align = alClient
    Font.Name = 'Monospace'
    ParentFont = False
    TabOrder = 1
  end
end
