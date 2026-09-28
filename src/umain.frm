object Form1: TForm1
  Left = 0
  Height = 600
  Top = 0
  Width = 900
  Caption = 'GRBL Controller Sender'
  ClientHeight = 600
  ClientWidth = 900
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  LCLVersion = '4.8.0.0'
  Menu = MainMenu1
  object MainMenu1: TMainMenu
    left = 24
    top = 24
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
    end
    object MenuLanguage: TMenuItem
      Caption = '&Language'
      object MenuLangEN: TMenuItem
        Caption = 'English'
        RadioItem = True
        GroupIndex = 1
        Tag = 0
        OnClick = MenuLangClick
      end
      object MenuLangHR: TMenuItem
        Caption = 'Hrvatski'
        RadioItem = True
        GroupIndex = 1
        Tag = 1
        OnClick = MenuLangClick
      end
      object MenuLangDE: TMenuItem
        Caption = 'Deutsch'
        RadioItem = True
        GroupIndex = 1
        Tag = 2
        OnClick = MenuLangClick
      end
    end
  end
end
