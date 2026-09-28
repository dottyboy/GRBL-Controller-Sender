object SettingsForm: TSettingsForm
  Left = 204
  Height = 387
  Top = 465
  Width = 420
  BorderStyle = bsDialog
  Caption = 'Machine Settings'
  ClientHeight = 387
  ClientWidth = 420
  Position = poScreenCenter
  LCLVersion = '4.8.0.0'
  object LblTravel: TLabel
    Left = 16
    Height = 20
    Top = 44
    Width = 95
    Caption = 'Travel (mm)'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object EdTravelX: TEdit
    Left = 200
    Height = 28
    Top = 40
    Width = 60
    TabOrder = 2
    Text = '300'
  end
  object EdTravelY: TEdit
    Left = 268
    Height = 28
    Top = 40
    Width = 60
    TabOrder = 3
    Text = '300'
  end
  object EdTravelZ: TEdit
    Left = 336
    Height = 28
    Top = 40
    Width = 60
    TabOrder = 4
    Text = '60'
  end
  object LblFeedMax: TLabel
    Left = 16
    Height = 20
    Top = 80
    Width = 76
    Caption = 'Max Feed'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object EdFeedMaxX: TEdit
    Left = 200
    Height = 28
    Top = 76
    Width = 60
    TabOrder = 5
    Text = '3000'
  end
  object EdFeedMaxY: TEdit
    Left = 268
    Height = 28
    Top = 76
    Width = 60
    TabOrder = 6
    Text = '3000'
  end
  object EdFeedMaxZ: TEdit
    Left = 336
    Height = 28
    Top = 76
    Width = 60
    TabOrder = 7
    Text = '2000'
  end
  object LblAccel: TLabel
    Left = 16
    Height = 20
    Top = 116
    Width = 105
    Caption = 'Acceleration '
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object EdAccelX: TEdit
    Left = 200
    Height = 28
    Top = 112
    Width = 60
    TabOrder = 8
    Text = '25'
  end
  object EdAccelY: TEdit
    Left = 268
    Height = 28
    Top = 112
    Width = 60
    TabOrder = 9
    Text = '25'
  end
  object EdAccelZ: TEdit
    Left = 336
    Height = 28
    Top = 112
    Width = 60
    TabOrder = 10
    Text = '25'
  end
  object LblSafe: TLabel
    Left = 16
    Height = 20
    Top = 152
    Width = 96
    Caption = 'Safe Z (mm)'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object EdSafe: TEdit
    Left = 336
    Height = 28
    Top = 144
    Width = 60
    TabOrder = 11
    Text = '3'
  end
  object LblDiameter: TLabel
    Left = 16
    Height = 20
    Top = 188
    Width = 111
    Caption = 'Tool diameter'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object EdDiameter: TEdit
    Left = 200
    Height = 28
    Top = 184
    Width = 60
    TabOrder = 12
    Text = '3.175'
  end
  object LblCutFeed: TLabel
    Left = 16
    Height = 20
    Top = 224
    Width = 111
    Caption = 'Cut feed XY/Z'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object EdCutFeed: TEdit
    Left = 200
    Height = 28
    Top = 220
    Width = 60
    TabOrder = 13
    Text = '1000'
  end
  object EdCutFeedZ: TEdit
    Left = 268
    Height = 28
    Top = 220
    Width = 60
    TabOrder = 14
    Text = '500'
  end
  object LblStartup: TLabel
    Left = 16
    Height = 20
    Top = 260
    Width = 118
    Caption = 'Startup g-code'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object EdStartup: TEdit
    Left = 200
    Height = 28
    Top = 256
    Width = 196
    TabOrder = 15
    Text = 'G90'
  end
  object LblGanged: TLabel
    Left = 16
    Height = 20
    Top = 296
    Width = 148
    Caption = 'Ganged (2 motors)'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object ChkGangedX: TCheckBox
    Left = 200
    Height = 23
    Top = 296
    Width = 35
    Caption = 'X'
    Font.Height = -13
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 16
  end
  object ChkGangedY: TCheckBox
    Left = 268
    Height = 23
    Top = 296
    Width = 34
    Caption = 'Y'
    Font.Height = -13
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 17
  end
  object ChkGangedZ: TCheckBox
    Left = 336
    Height = 23
    Top = 296
    Width = 34
    Caption = 'Z'
    Font.Height = -13
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 18
  end
  object BtnOK: TButton
    Left = 216
    Height = 30
    Top = 344
    Width = 90
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 0
  end
  object BtnCancel: TButton
    Left = 314
    Height = 30
    Top = 344
    Width = 90
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 1
  end
  object LblTravel1: TLabel
    Left = 216
    Height = 20
    Top = 16
    Width = 11
    Caption = 'X'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblTravel2: TLabel
    Left = 288
    Height = 20
    Top = 16
    Width = 11
    Caption = 'Y'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LblTravel3: TLabel
    Left = 360
    Height = 20
    Top = 16
    Width = 10
    Caption = 'Z'
    Font.Height = -17
    Font.Name = 'Ubuntu'
    Font.Style = [fsBold]
    ParentFont = False
  end
end
