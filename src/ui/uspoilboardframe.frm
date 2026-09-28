object SpoilboardFrame: TSpoilboardFrame
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
    object LblProfile: TLabel
          Left = 8
          Height = 17
          Top = 12
          Width = 46
          Caption = 'Profile:'
    end
    object CbProfile: TComboBox
          Left = 70
          Height = 25
          Top = 8
          Width = 200
          ItemHeight = 17
          TabOrder = 0
    end
    object BtnProfileLoad: TButton
          Left = 280
          Height = 25
          Top = 8
          Width = 70
          Caption = 'Load'
          OnClick = BtnProfileLoadClick
          TabOrder = 1
    end
    object BtnProfileSave: TButton
          Left = 354
          Height = 25
          Top = 8
          Width = 70
          Caption = 'Save'
          OnClick = BtnProfileSaveClick
          TabOrder = 2
    end
    object BtnProfileDelete: TButton
          Left = 428
          Height = 25
          Top = 8
          Width = 70
          Caption = 'Delete'
          OnClick = BtnProfileDeleteClick
          TabOrder = 3
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
          TabOrder = 33
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
    object LblMachinePreset: TLabel
          Left = 8
          Height = 17
          Top = 8
          Width = 130
          Caption = 'Machine preset:'
    end
    object CbMachinePreset: TComboBox
          Left = 140
          Height = 25
          Top = 4
          Width = 380
          ItemHeight = 17
          Style = csDropDownList
          TabOrder = 34
    end
    object BtnMachineApply: TButton
          Left = 530
          Height = 25
          Top = 4
          Width = 90
          Caption = 'Apply'
          OnClick = BtnMachineApplyClick
          TabOrder = 35
    end
    object BtnSendLimits: TButton
          Left = 630
          Height = 25
          Top = 4
          Width = 170
          Caption = 'Send Travel Limits'
          OnClick = BtnSendLimitsClick
          TabOrder = 36
    end
    object LblMachineInfo: TLabel
          Left = 8
          Height = 34
          Top = 36
          Width = 900
          AutoSize = False
          WordWrap = True
          Caption = ''
    end

    object LblWorkX: TLabel
          Left = 8
          Height = 17
          Top = 88
          Width = 78
          Caption = 'Work X (mm)'
    end
    object EdWorkWidthX: TEdit
          Left = 100
          Height = 25
          Top = 84
          Width = 70
          TabOrder = 4
    end
    object LblWorkY: TLabel
          Left = 180
          Height = 17
          Top = 88
          Width = 78
          Caption = 'Work Y (mm)'
    end
    object EdWorkHeightY: TEdit
          Left = 270
          Height = 25
          Top = 84
          Width = 70
          TabOrder = 5
    end
    object LblSafeZ: TLabel
          Left = 350
          Height = 17
          Top = 88
          Width = 74
          Caption = 'Safe Z (mm)'
    end
    object EdSafeZ: TEdit
          Left = 440
          Height = 25
          Top = 84
          Width = 70
          TabOrder = 6
    end
    object LblFacingHeader: TLabel
          Left = 8
          Height = 17
          Top = 130
          Width = 140
          Caption = 'Facing / Surfacing'
          Font.Style = [fsBold]
          ParentFont = False
    end
    object ChkFacingEnabled: TCheckBox
          Left = 8
          Height = 21
          Top = 154
          Width = 150
          Caption = 'Enabled'
          TabOrder = 7
    end
    object ChkFacingRowsAlongX: TCheckBox
          Left = 170
          Height = 21
          Top = 154
          Width = 220
          Caption = 'Rows along X (else Y)'
          TabOrder = 8
    end
    object LblFacingTool: TLabel
          Left = 8
          Height = 17
          Top = 188
          Width = 44
          Caption = 'Tool '#216
    end
    object EdFacingToolDiameter: TEdit
          Left = 70
          Height = 25
          Top = 184
          Width = 60
          TabOrder = 9
    end
    object LblFacingStepover: TLabel
          Left = 140
          Height = 17
          Top = 188
          Width = 64
          Caption = 'Stepover %'
    end
    object EdFacingStepoverPercent: TEdit
          Left = 220
          Height = 25
          Top = 184
          Width = 60
          TabOrder = 10
    end
    object LblFacingSpindle: TLabel
          Left = 290
          Height = 17
          Top = 188
          Width = 70
          Caption = 'Spindle RPM'
    end
    object EdFacingSpindleRPM: TEdit
          Left = 380
          Height = 25
          Top = 184
          Width = 70
          TabOrder = 11
    end
    object LblFacingDepthPerPass: TLabel
          Left = 8
          Height = 17
          Top = 218
          Width = 62
          Caption = 'Depth/pass'
    end
    object EdFacingDepthPerPass: TEdit
          Left = 90
          Height = 25
          Top = 214
          Width = 60
          TabOrder = 12
    end
    object LblFacingTotalDepth: TLabel
          Left = 160
          Height = 17
          Top = 218
          Width = 62
          Caption = 'Total depth'
    end
    object EdFacingTotalDepth: TEdit
          Left = 250
          Height = 25
          Top = 214
          Width = 60
          TabOrder = 13
    end
    object LblFacingFeedRate: TLabel
          Left = 8
          Height = 17
          Top = 248
          Width = 51
          Caption = 'Feed rate'
    end
    object EdFacingFeedRate: TEdit
          Left = 90
          Height = 25
          Top = 244
          Width = 70
          TabOrder = 14
    end
    object LblFacingPlungeRate: TLabel
          Left = 170
          Height = 17
          Top = 248
          Width = 63
          Caption = 'Plunge rate'
    end
    object EdFacingPlungeRate: TEdit
          Left = 260
          Height = 25
          Top = 244
          Width = 70
          TabOrder = 15
    end
    object LblHolesHeader: TLabel
          Left = 8
          Height = 17
          Top = 286
          Width = 130
          Caption = 'Peg Holes Grid'
          Font.Style = [fsBold]
          ParentFont = False
    end
    object ChkHolesEnabled: TCheckBox
          Left = 8
          Height = 21
          Top = 310
          Width = 100
          Caption = 'Enabled'
          TabOrder = 16
    end
    object ChkHoleStaggered: TCheckBox
          Left = 120
          Height = 21
          Top = 310
          Width = 120
          Caption = 'Staggered'
          TabOrder = 17
    end
    object LblHoleDiameter: TLabel
          Left = 8
          Height = 17
          Top = 344
          Width = 44
          Caption = 'Hole '#216
    end
    object EdHoleDiameter: TEdit
          Left = 70
          Height = 25
          Top = 340
          Width = 60
          TabOrder = 18
    end
    object LblHoleMarginX: TLabel
          Left = 140
          Height = 17
          Top = 344
          Width = 56
          Caption = 'Margin X'
    end
    object EdHoleMarginX: TEdit
          Left = 210
          Height = 25
          Top = 340
          Width = 60
          TabOrder = 19
    end
    object LblHoleMarginY: TLabel
          Left = 280
          Height = 17
          Top = 344
          Width = 56
          Caption = 'Margin Y'
    end
    object EdHoleMarginY: TEdit
          Left = 350
          Height = 25
          Top = 340
          Width = 60
          TabOrder = 20
    end
    object LblHoleSpacingX: TLabel
          Left = 8
          Height = 17
          Top = 374
          Width = 60
          Caption = 'Spacing X'
    end
    object EdHoleSpacingX: TEdit
          Left = 90
          Height = 25
          Top = 370
          Width = 60
          TabOrder = 21
    end
    object LblHoleSpacingY: TLabel
          Left = 160
          Height = 17
          Top = 374
          Width = 60
          Caption = 'Spacing Y'
    end
    object EdHoleSpacingY: TEdit
          Left = 240
          Height = 25
          Top = 370
          Width = 60
          TabOrder = 22
    end
    object LblHoleDrillDepth: TLabel
          Left = 8
          Height = 17
          Top = 404
          Width = 58
          Caption = 'Drill depth'
    end
    object EdHoleDrillDepth: TEdit
          Left = 100
          Height = 25
          Top = 400
          Width = 60
          TabOrder = 23
    end
    object LblHolePeckDepth: TLabel
          Left = 170
          Height = 17
          Top = 404
          Width = 60
          Caption = 'Peck depth'
    end
    object EdHolePeckDepth: TEdit
          Left = 250
          Height = 25
          Top = 400
          Width = 60
          TabOrder = 24
    end
    object LblHolePlungeRate: TLabel
          Left = 320
          Height = 17
          Top = 404
          Width = 63
          Caption = 'Plunge rate'
    end
    object EdHolePlungeRate: TEdit
          Left = 410
          Height = 25
          Top = 400
          Width = 70
          TabOrder = 25
    end
    object LblTracksHeader: TLabel
          Left = 8
          Height = 17
          Top = 442
          Width = 140
          Caption = 'T-Track Channels'
          Font.Style = [fsBold]
          ParentFont = False
    end
    object LblTrackTool: TLabel
          Left = 8
          Height = 17
          Top = 466
          Width = 44
          Caption = 'Tool '#216
    end
    object EdTrackToolDiameter: TEdit
          Left = 70
          Height = 25
          Top = 462
          Width = 60
          TabOrder = 26
    end
    object LblTrackStepover: TLabel
          Left = 140
          Height = 17
          Top = 466
          Width = 64
          Caption = 'Stepover %'
    end
    object EdTrackStepoverPercent: TEdit
          Left = 220
          Height = 25
          Top = 462
          Width = 60
          TabOrder = 27
    end
    object LblTrackFeedRate: TLabel
          Left = 290
          Height = 17
          Top = 466
          Width = 51
          Caption = 'Feed rate'
    end
    object EdTrackFeedRate: TEdit
          Left = 360
          Height = 25
          Top = 462
          Width = 70
          TabOrder = 28
    end
    object LblTrackPlungeRate: TLabel
          Left = 440
          Height = 17
          Top = 466
          Width = 63
          Caption = 'Plunge rate'
    end
    object EdTrackPlungeRate: TEdit
          Left = 530
          Height = 25
          Top = 462
          Width = 70
          TabOrder = 29
    end
    object BtnTrackAdd: TButton
          Left = 8
          Height = 25
          Top = 492
          Width = 100
          Caption = 'Add Track'
          OnClick = BtnTrackAddClick
          TabOrder = 30
    end
    object BtnTrackDelete: TButton
          Left = 114
          Height = 25
          Top = 492
          Width = 100
          Caption = 'Delete Row'
          OnClick = BtnTrackDeleteClick
          TabOrder = 31
    end
    object TrackGrid: TStringGrid
          Left = 8
          Height = 140
          Top = 524
          Width = 900
          ColCount = 6
          FixedRows = 1
          Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goEditing, goSmoothScroll]
          RowCount = 2
          TabOrder = 32
          ColWidths = (
            50
            100
            100
            100
            110
            110
          )
    end
  end
end
