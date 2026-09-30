object ChecklistFrame: TChecklistFrame
  Left = 0
  Height = 360
  Top = 0
  Width = 420
  ClientHeight = 360
  ClientWidth = 420
  TabOrder = 0
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
    OnClick = BtnProceedClick
    TabOrder = 3
  end
  object BtnCancel: TButton
    Left = 316
    Height = 32
    Top = 312
    Width = 92
    Caption = 'Cancel'
    OnClick = BtnCancelClick
    TabOrder = 4
  end
end
