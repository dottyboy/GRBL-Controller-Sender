object FluidNCFrame: TFluidNCFrame
  Left = 0
  Height = 400
  Top = 0
  Width = 700
  Align = alClient
  ClientHeight = 400
  ClientWidth = 700
  TabOrder = 0
  object ToolBar: TPanel
    Left = 0
    Height = 68
    Top = 0
    Width = 700
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 68
    ClientWidth = 700
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
    object LblFile: TLabel
      Left = 240
      Height = 17
      Top = 9
      Width = 56
      Caption = '(untitled)'
    end
    object BtnEditAxes: TButton
      Left = 310
      Height = 26
      Top = 4
      Width = 110
      Caption = 'Edit Axes...'
      OnClick = BtnEditAxesClick
      TabOrder = 5
    end
    object LblBoardFile: TLabel
      Left = 4
      Height = 17
      Top = 40
      Width = 88
      Caption = 'Board filename'
    end
    object EdBoardFile: TEdit
      Left = 96
      Height = 25
      Top = 36
      Width = 140
      Text = 'config.yaml'
    end
    object BtnDownload: TButton
      Left = 244
      Height = 26
      Top = 35
      Width = 150
      Caption = 'Download from board'
      OnClick = BtnDownloadClick
      TabOrder = 3
    end
    object BtnUpload: TButton
      Left = 400
      Height = 26
      Top = 35
      Width = 120
      Caption = 'Upload to board'
      OnClick = BtnUploadClick
      TabOrder = 4
    end
    object LblStatus: TLabel
      Left = 530
      Height = 17
      Top = 40
      Width = 84
      Caption = 'Not connected'
    end
  end
  object SynEditor: TSynEdit
    Left = 0
    Height = 332
    Top = 68
    Width = 700
    Align = alClient
    Font.Name = 'Monospace'
    ParentFont = False
    TabOrder = 1
  end
end
