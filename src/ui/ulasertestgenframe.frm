object LaserTestGenFrame: TLaserTestGenFrame
  Left = 0
  Height = 700
  Top = 0
  Width = 950
  Align = alClient
  ClientHeight = 700
  ClientWidth = 950
  TabOrder = 0
  object TopBar: TPanel
    Left = 0
    Height = 44
    Top = 0
    Width = 950
    Align = alTop
    BevelOuter = bvNone
    ClientHeight = 44
    ClientWidth = 950
    TabOrder = 0
    object LblTestType: TLabel
      Left = 8
      Height = 17
      Top = 12
      Width = 60
      Caption = 'Test type:'
    end
    object CbTestType: TComboBox
      Left = 76
      Height = 25
      Top = 8
      Width = 200
      ItemHeight = 17
      Style = csDropDownList
      OnChange = CbTestTypeChange
      TabOrder = 0
    end
    object LblTitle: TLabel
      Left = 290
      Height = 17
      Top = 12
      Width = 30
      Caption = 'Title:'
    end
    object EdTitle: TEdit
      Left = 326
      Height = 25
      Top = 8
      Width = 200
      TabOrder = 1
    end
    object LblTurnOnCmd: TLabel
      Left = 538
      Height = 17
      Top = 12
      Width = 70
      Caption = 'Turn-on cmd:'
    end
    object EdTurnOnCmd: TEdit
      Left = 616
      Height = 25
      Top = 8
      Width = 60
      Text = 'M4'
      TabOrder = 2
    end
  end
  object BottomBar: TPanel
    Left = 0
    Height = 48
    Top = 652
    Width = 950
    Align = alBottom
    BevelOuter = bvNone
    ClientHeight = 48
    ClientWidth = 950
    TabOrder = 2
    object BtnGenerate: TButton
      Left = 8
      Height = 32
      Top = 8
      Width = 160
      Caption = 'Generate G-Code'
      Font.Style = [fsBold]
      ParentFont = False
      OnClick = BtnGenerateClick
      TabOrder = 0
    end
    object LblStatus: TLabel
      Left = 180
      Height = 17
      Top = 16
      Width = 3
      Caption = ''
    end
  end
  object ScrollBox1: TScrollBox
    Left = 0
    Height = 608
    Top = 44
    Width = 950
    Align = alClient
    ClientHeight = 604
    ClientWidth = 933
    TabOrder = 1
    object PnlCutting: TPanel
      Left = 8
      Height = 220
      Top = 8
      Width = 900
      BevelOuter = bvNone
      ClientHeight = 220
      ClientWidth = 900
      TabOrder = 0
      object LblCutHeader: TLabel
        Left = 0
        Height = 17
        Top = 0
        Width = 150
        Caption = 'Cutting test (feed x pass grid)'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object LblCutFeedColumns: TLabel
        Left = 0
        Height = 17
        Top = 34
        Width = 74
        Caption = 'Feed columns'
      end
      object EdCutFeedColumns: TEdit
        Left = 90
        Height = 25
        Top = 30
        Width = 60
        TabOrder = 0
      end
      object LblCutFeedStart: TLabel
        Left = 160
        Height = 17
        Top = 34
        Width = 56
        Caption = 'Feed start'
      end
      object EdCutFeedStart: TEdit
        Left = 230
        Height = 25
        Top = 30
        Width = 70
        TabOrder = 1
      end
      object LblCutFeedEnd: TLabel
        Left = 310
        Height = 17
        Top = 34
        Width = 52
        Caption = 'Feed end'
      end
      object EdCutFeedEnd: TEdit
        Left = 370
        Height = 25
        Top = 30
        Width = 70
        TabOrder = 2
      end
      object LblCutPassStart: TLabel
        Left = 0
        Height = 17
        Top = 68
        Width = 56
        Caption = 'Pass start'
      end
      object EdCutPassStart: TEdit
        Left = 90
        Height = 25
        Top = 64
        Width = 60
        TabOrder = 3
      end
      object LblCutPassEnd: TLabel
        Left = 160
        Height = 17
        Top = 68
        Width = 52
        Caption = 'Pass end'
      end
      object EdCutPassEnd: TEdit
        Left = 230
        Height = 25
        Top = 64
        Width = 60
        TabOrder = 4
      end
      object LblCutFixedPower: TLabel
        Left = 310
        Height = 17
        Top = 68
        Width = 66
        Caption = 'Fixed power'
      end
      object EdCutFixedPower: TEdit
        Left = 390
        Height = 25
        Top = 64
        Width = 70
        TabOrder = 5
      end
      object LblCutTextFeed: TLabel
        Left = 0
        Height = 17
        Top = 102
        Width = 78
        Caption = 'Label feed rate'
      end
      object EdCutTextFeed: TEdit
        Left = 90
        Height = 25
        Top = 98
        Width = 70
        TabOrder = 6
      end
      object LblCutTextPower: TLabel
        Left = 170
        Height = 17
        Top = 102
        Width = 82
        Caption = 'Label power'
      end
      object EdCutTextPower: TEdit
        Left = 260
        Height = 25
        Top = 98
        Width = 70
        TabOrder = 7
      end
    end
    object PnlGreyscale: TPanel
      Left = 8
      Height = 260
      Top = 8
      Width = 900
      BevelOuter = bvNone
      ClientHeight = 260
      ClientWidth = 900
      TabOrder = 1
      object LblGreyHeader: TLabel
        Left = 0
        Height = 17
        Top = 0
        Width = 130
        Caption = 'Power/speed grid'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object LblGreyFeedRows: TLabel
        Left = 0
        Height = 17
        Top = 34
        Width = 54
        Caption = 'Feed rows'
      end
      object EdGreyFeedRows: TEdit
        Left = 90
        Height = 25
        Top = 30
        Width = 60
        TabOrder = 0
      end
      object LblGreyPowerCols: TLabel
        Left = 160
        Height = 17
        Top = 34
        Width = 62
        Caption = 'Power cols'
      end
      object EdGreyPowerCols: TEdit
        Left = 230
        Height = 25
        Top = 30
        Width = 60
        TabOrder = 1
      end
      object LblGreyFeedStart: TLabel
        Left = 0
        Height = 17
        Top = 68
        Width = 56
        Caption = 'Feed start'
      end
      object EdGreyFeedStart: TEdit
        Left = 90
        Height = 25
        Top = 64
        Width = 70
        TabOrder = 2
      end
      object LblGreyFeedEnd: TLabel
        Left = 170
        Height = 17
        Top = 68
        Width = 52
        Caption = 'Feed end'
      end
      object EdGreyFeedEnd: TEdit
        Left = 230
        Height = 25
        Top = 64
        Width = 70
        TabOrder = 3
      end
      object LblGreyPowerStart: TLabel
        Left = 310
        Height = 17
        Top = 68
        Width = 62
        Caption = 'Power start'
      end
      object EdGreyPowerStart: TEdit
        Left = 390
        Height = 25
        Top = 64
        Width = 70
        TabOrder = 4
      end
      object LblGreyPowerEnd: TLabel
        Left = 470
        Height = 17
        Top = 68
        Width = 58
        Caption = 'Power end'
      end
      object EdGreyPowerEnd: TEdit
        Left = 540
        Height = 25
        Top = 64
        Width = 70
        TabOrder = 5
      end
      object LblGreySizeX: TLabel
        Left = 0
        Height = 17
        Top = 102
        Width = 60
        Caption = 'Size X (mm)'
      end
      object EdGreySizeX: TEdit
        Left = 90
        Height = 25
        Top = 98
        Width = 60
        TabOrder = 6
      end
      object LblGreySizeY: TLabel
        Left = 160
        Height = 17
        Top = 102
        Width = 60
        Caption = 'Size Y (mm)'
      end
      object EdGreySizeY: TEdit
        Left = 230
        Height = 25
        Top = 98
        Width = 60
        TabOrder = 7
      end
      object LblGreyResolution: TLabel
        Left = 300
        Height = 17
        Top = 102
        Width = 80
        Caption = 'Lines/mm'
      end
      object EdGreyResolution: TEdit
        Left = 390
        Height = 25
        Top = 98
        Width = 60
        TabOrder = 8
      end
      object LblGreyGridFeed: TLabel
        Left = 0
        Height = 17
        Top = 136
        Width = 58
        Caption = 'Grid feed'
      end
      object EdGreyGridFeed: TEdit
        Left = 90
        Height = 25
        Top = 132
        Width = 70
        TabOrder = 9
      end
      object LblGreyGridPower: TLabel
        Left = 170
        Height = 17
        Top = 136
        Width = 62
        Caption = 'Grid power'
      end
      object EdGreyGridPower: TEdit
        Left = 240
        Height = 25
        Top = 132
        Width = 60
        TabOrder = 10
      end
      object LblGreyTextFeed: TLabel
        Left = 0
        Height = 17
        Top = 170
        Width = 78
        Caption = 'Label feed rate'
      end
      object EdGreyTextFeed: TEdit
        Left = 90
        Height = 25
        Top = 166
        Width = 70
        TabOrder = 11
      end
      object LblGreyTextPower: TLabel
        Left = 170
        Height = 17
        Top = 170
        Width = 82
        Caption = 'Label power'
      end
      object EdGreyTextPower: TEdit
        Left = 260
        Height = 25
        Top = 166
        Width = 70
        TabOrder = 12
      end
    end
    object PnlShake: TPanel
      Left = 8
      Height = 160
      Top = 8
      Width = 900
      BevelOuter = bvNone
      ClientHeight = 160
      ClientWidth = 900
      TabOrder = 2
      object LblShakeHeader: TLabel
        Left = 0
        Height = 17
        Top = 0
        Width = 130
        Caption = 'Shake test (axis check)'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object LblShakeAxis: TLabel
        Left = 0
        Height = 17
        Top = 34
        Width = 26
        Caption = 'Axis'
      end
      object CbShakeAxis: TComboBox
        Left = 90
        Height = 25
        Top = 30
        Width = 60
        ItemHeight = 17
        Style = csDropDownList
        TabOrder = 0
      end
      object LblShakeFeedLimit: TLabel
        Left = 170
        Height = 17
        Top = 34
        Width = 58
        Caption = 'Feed limit'
      end
      object EdShakeFeedLimit: TEdit
        Left = 240
        Height = 25
        Top = 30
        Width = 70
        TabOrder = 1
      end
      object LblShakeAxisLength: TLabel
        Left = 330
        Height = 17
        Top = 34
        Width = 68
        Caption = 'Axis length'
      end
      object EdShakeAxisLength: TEdit
        Left = 410
        Height = 25
        Top = 30
        Width = 70
        TabOrder = 2
      end
      object LblShakeCrossPower: TLabel
        Left = 0
        Height = 17
        Top = 68
        Width = 70
        Caption = 'Cross power'
      end
      object EdShakeCrossPower: TEdit
        Left = 90
        Height = 25
        Top = 64
        Width = 70
        TabOrder = 3
      end
      object LblShakeCrossSpeed: TLabel
        Left = 180
        Height = 17
        Top = 68
        Width = 70
        Caption = 'Cross speed'
      end
      object EdShakeCrossSpeed: TEdit
        Left = 270
        Height = 25
        Top = 64
        Width = 70
        TabOrder = 4
      end
    end
  end
end
