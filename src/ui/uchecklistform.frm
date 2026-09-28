object ChecklistForm: TChecklistForm
  Left = 300
  Height = 360
  Top = 200
  Width = 420
  BorderStyle = bsDialog
  Caption = 'Pre-flight Checklist'
  ClientHeight = 360
  ClientWidth = 420
  Position = poScreenCenter
  OnCreate = FormCreate
  LCLVersion = '4.8.0.0'
  object CheckListBox1: TCheckListBox
    Left = 12
    Height = 220
    Top = 12
    Width = 396
    OnClickCheck = CheckListBox1ClickCheck
    TabOrder = 0
  end
  object BtnAddItem: TButton
    Left = 12
    Height = 26
    Top = 240
    Width = 90
    Caption = 'Add Item'
    OnClick = BtnAddItemClick
    TabOrder = 1
  end
  object BtnDeleteItem: TButton
    Left = 108
    Height = 26
    Top = 240
    Width = 90
    Caption = 'Delete'
    OnClick = BtnDeleteItemClick
    TabOrder = 2
  end
  object BtnProceed: TButton
    Left = 216
    Height = 32
    Top = 312
    Width = 90
    Caption = 'Proceed'
    Default = True
    ModalResult = 1
    TabOrder = 3
  end
  object BtnCancel: TButton
    Left = 316
    Height = 32
    Top = 312
    Width = 92
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 4
  end
end
