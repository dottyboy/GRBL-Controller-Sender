object ParametricToolFrame: TParametricToolFrame
  Left = 0
  Height = 340
  Top = 0
  Width = 360
  ClientHeight = 340
  ClientWidth = 360
  TabOrder = 0
  object LblShape: TLabel
    Left = 16
    Height = 15
    Top = 16
    Width = 40
    Caption = 'Shape'
  end
  object CboShape: TComboBox
    Left = 16
    Height = 26
    Top = 34
    Width = 200
    Style = csDropDownList
    OnChange = CboShapeChange
    TabOrder = 0
  end
  object LblDiameter: TLabel
    Left = 16
    Height = 15
    Top = 72
    Width = 90
    Caption = 'Diameter (mm)'
  end
  object EdDiameter: TFloatSpinEdit
    Left = 16
    Height = 24
    Top = 90
    Width = 120
    DecimalPlaces = 3
    Increment = 0.1
    MaxValue = 200
    MinValue = 0.01
    TabOrder = 1
  end
  object LblShankDiameter: TLabel
    Left = 160
    Height = 15
    Top = 72
    Width = 120
    Caption = 'Shank diameter (mm)'
  end
  object EdShankDiameter: TFloatSpinEdit
    Left = 160
    Height = 24
    Top = 90
    Width = 120
    DecimalPlaces = 2
    Increment = 0.1
    MaxValue = 200
    MinValue = 0.1
    TabOrder = 2
  end
  object LblLength: TLabel
    Left = 16
    Height = 15
    Top = 126
    Width = 80
    Caption = 'Length (mm)'
  end
  object EdLength: TFloatSpinEdit
    Left = 16
    Height = 24
    Top = 144
    Width = 120
    DecimalPlaces = 1
    Increment = 1
    MaxValue = 500
    MinValue = 1
    TabOrder = 3
  end
  object LblCuttingEdgeAngle: TLabel
    Left = 160
    Height = 15
    Top = 126
    Width = 130
    Caption = 'Included angle (deg)'
  end
  object EdCuttingEdgeAngle: TFloatSpinEdit
    Left = 160
    Height = 24
    Top = 144
    Width = 120
    DecimalPlaces = 1
    Increment = 1
    MaxValue = 179
    MinValue = 1
    TabOrder = 4
  end
  object LblTipDiameter: TLabel
    Left = 16
    Height = 15
    Top = 180
    Width = 100
    Caption = 'Tip diameter (mm)'
  end
  object EdTipDiameter: TFloatSpinEdit
    Left = 16
    Height = 24
    Top = 198
    Width = 120
    DecimalPlaces = 2
    Increment = 0.05
    MaxValue = 50
    MinValue = 0
    TabOrder = 5
  end
  object LblCornerRadius: TLabel
    Left = 160
    Height = 15
    Top = 180
    Width = 100
    Caption = 'Corner radius (mm)'
  end
  object EdCornerRadius: TFloatSpinEdit
    Left = 160
    Height = 24
    Top = 198
    Width = 120
    DecimalPlaces = 2
    Increment = 0.1
    MaxValue = 50
    MinValue = 0.01
    TabOrder = 6
  end
  object LblTipAngle: TLabel
    Left = 16
    Height = 15
    Top = 234
    Width = 110
    Caption = 'Tip point angle (deg)'
  end
  object EdTipAngle: TFloatSpinEdit
    Left = 16
    Height = 24
    Top = 252
    Width = 120
    DecimalPlaces = 1
    Increment = 1
    MaxValue = 179
    MinValue = 1
    TabOrder = 7
  end
  object BtnAddToTools: TButton
    Left = 16
    Height = 30
    Top = 292
    Width = 160
    Caption = 'Add to Tool Table'
    OnClick = BtnAddToToolsClick
    TabOrder = 8
  end
  object LblStatus: TLabel
    Left = 190
    Height = 17
    Top = 298
    Width = 3
    Caption = ''
  end
end
