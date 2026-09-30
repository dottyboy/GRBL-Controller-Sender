object MainForm: TMainForm
  Left = 516
  Height = 664
  Top = 213
  Width = 1259
  Caption = 'GRBL Controller Sender'
  ClientHeight = 664
  ClientWidth = 1259
  KeyPreview = True
  Menu = MainMenu1
  Position = poScreenCenter
  LCLVersion = '9.0'
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  object plStatusBarEx1: TplStatusBarEx
    Left = 0
    Height = 32
    Top = 632
    Width = 1259
    Panels = <>
    SizeGrip = True
    SimplePanel = True
    UseSystemFont = True
    Color = clSkyBlue
    Constraints.MaxHeight = 32
    Constraints.MinHeight = 32
    ParentColor = False
    ParentFont = False
  end
  object RxClock1: TRxClock
    AnchorSideTop.Control = plStatusBarEx1
    AnchorSideRight.Control = plStatusBarEx1
    AnchorSideRight.Side = asrBottom
    AnchorSideBottom.Control = plStatusBarEx1
    AnchorSideBottom.Side = asrBottom
    Left = 1107
    Height = 26
    Top = 636
    Width = 150
    Anchors = [akTop, akRight, akBottom]
    Constraints.MaxWidth = 150
    Constraints.MinWidth = 150
    Color = clMoneyGreen
    Font.Height = -19
    Font.Name = 'JetBrains Mono'
    ParentColor = False
    ParentFont = False
  end
  object JobProgress: TProgressBar
    AnchorSideTop.Control = plStatusBarEx1
    AnchorSideRight.Control = RxClock1
    AnchorSideBottom.Control = plStatusBarEx1
    AnchorSideBottom.Side = asrBottom
    Left = 899
    Height = 24
    Top = 636
    Width = 200
    Anchors = [akTop, akRight, akBottom]
    BorderSpacing.Top = 4
    BorderSpacing.Right = 8
    BorderSpacing.Bottom = 4
    BorderWidth = 1
    Color = clMoneyGreen
    Constraints.MaxWidth = 200
    Constraints.MinWidth = 200
    DragMode = dmAutomatic
    Font.Height = -15
    Font.Name = 'JetBrains Mono'
    Font.Style = [fsBold]
    ParentColor = False
    ParentFont = False
    Smooth = True
    Step = 1
    TabOrder = 2
    BarShowText = True
  end
  object JobStatusText: TLabel
    AnchorSideTop.Control = JobProgress
    AnchorSideRight.Control = JobProgress
    AnchorSideBottom.Control = JobProgress
    AnchorSideBottom.Side = asrBottom
    Left = 572
    Height = 24
    Top = 636
    Width = 319
    Align = alCustom
    Alignment = taRightJustify
    Anchors = [akTop, akRight, akBottom]
    BorderSpacing.Right = 8
    Caption = 'Idle/Connected/Progress/STOP'
    Font.Height = -19
    Font.Name = 'JetBrains Mono'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object MainMenu1: TMainMenu
    Left = 24
    Top = 24
    object MenuFile: TMenuItem
      Caption = '&File'
      object MenuFileExit: TMenuItem
        Caption = 'E&xit'
        OnClick = MenuFileExitClick
      end
    end
    object MenuTools: TMenuItem
      Caption = '&Tools'
      object MenuToolsSettings: TMenuItem
        Caption = '&Settings...'
        OnClick = MenuToolsSettingsClick
      end
      object MenuToolsLaserUsage: TMenuItem
        Caption = '&Laser Usage...'
        OnClick = MenuToolsLaserUsageClick
      end
      object MenuToolsAxisCalibration: TMenuItem
        Caption = '&Axis Calibration...'
        OnClick = MenuToolsAxisCalibrationClick
      end
    end
    object MenuLanguage: TMenuItem
      Caption = '&Language'
      object MenuLangEN: TMenuItem
        Caption = 'English'
        GroupIndex = 1
        RadioItem = True
        OnClick = MenuLangClick
      end
      object MenuLangHR: TMenuItem
        Tag = 1
        Caption = 'Hrvatski'
        GroupIndex = 1
        RadioItem = True
        OnClick = MenuLangClick
      end
      object MenuLangDE: TMenuItem
        Tag = 2
        Caption = 'Deutsch'
        GroupIndex = 1
        RadioItem = True
        OnClick = MenuLangClick
      end
    end
  end
end
