object LaserUsageForm: TLaserUsageForm
  Left = 260
  Height = 460
  Top = 160
  Width = 560
  BorderStyle = bsDialog
  Caption = 'Laser Usage'
  ClientHeight = 460
  ClientWidth = 560
  Position = poScreenCenter
  OnCreate = FormCreate
  LCLVersion = '4.8.0.0'
  object ListBox1: TListBox
    Left = 12
    Height = 220
    Top = 12
    Width = 536
    OnSelectionChange = ListBox1SelectionChange
    TabOrder = 0
  end
  object BtnAddNew: TButton
    Left = 12
    Height = 26
    Top = 240
    Width = 90
    Caption = 'Add New'
    OnClick = BtnAddNewClick
    TabOrder = 1
  end
  object BtnDelete: TButton
    Left = 108
    Height = 26
    Top = 240
    Width = 90
    Caption = 'Delete'
    OnClick = BtnDeleteClick
    TabOrder = 2
  end
  object BtnSetActive: TButton
    Left = 204
    Height = 26
    Top = 240
    Width = 110
    Caption = 'Set Active'
    OnClick = BtnSetActiveClick
    TabOrder = 3
  end
  object LblActive: TLabel
    Left = 12
    Height = 17
    Top = 276
    Width = 3
    Caption = ''
  end
  object LblName: TLabel
    Left = 12
    Height = 17
    Top = 304
    Width = 40
    Caption = 'Name'
  end
  object EdName: TEdit
    Left = 90
    Height = 25
    Top = 300
    Width = 180
    OnChange = FieldChange
    TabOrder = 4
  end
  object LblBrand: TLabel
    Left = 290
    Height = 17
    Top = 304
    Width = 38
    Caption = 'Brand'
  end
  object EdBrand: TEdit
    Left = 340
    Height = 25
    Top = 300
    Width = 200
    OnChange = FieldChange
    TabOrder = 5
  end
  object LblModel: TLabel
    Left = 12
    Height = 17
    Top = 336
    Width = 40
    Caption = 'Model'
  end
  object EdModel: TEdit
    Left = 90
    Height = 25
    Top = 332
    Width = 180
    OnChange = FieldChange
    TabOrder = 6
  end
  object LblOpticalPower: TLabel
    Left = 290
    Height = 17
    Top = 336
    Width = 30
    Caption = 'Power'
  end
  object EdOpticalPower: TEdit
    Left = 340
    Height = 25
    Top = 332
    Width = 100
    OnChange = FieldChange
    TabOrder = 7
  end
  object LblOpticalPowerUnit: TLabel
    Left = 446
    Height = 17
    Top = 336
    Width = 16
    Caption = 'W'
  end
  object BtnApply: TButton
    Left = 12
    Height = 26
    Top = 368
    Width = 90
    Caption = 'Apply'
    OnClick = BtnApplyClick
    TabOrder = 8
  end
  object BtnClose: TButton
    Left = 458
    Height = 32
    Top = 416
    Width = 90
    Caption = 'Close'
    Default = True
    ModalResult = 1
    TabOrder = 9
  end
end
