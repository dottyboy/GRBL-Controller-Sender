object OpenGL3DFrame: TOpenGL3DFrame
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
    object BtnRefresh: TButton
      Left = 4
      Height = 26
      Top = 4
      Width = 130
      Caption = 'Refresh from Editor'
      OnClick = BtnRefreshClick
      TabOrder = 0
    end
    object BtnResetView: TButton
      Left = 140
      Height = 26
      Top = 4
      Width = 90
      Caption = 'Reset View'
      OnClick = BtnResetViewClick
      TabOrder = 1
    end
    object LblInfo: TLabel
      Left = 240
      Height = 17
      Top = 9
      Width = 100
      Caption = '0 segments'
    end
  end
  object GLBox: TOpenGLControl
    Left = 0
    Height = 366
    Top = 34
    Width = 600
    Align = alClient
    OnMouseDown = GLBoxMouseDown
    OnMouseMove = GLBoxMouseMove
    OnMouseUp = GLBoxMouseUp
    OnMouseWheel = GLBoxMouseWheel
    OnPaint = GLBoxPaint
  end
end
