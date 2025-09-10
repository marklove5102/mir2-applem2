object FrmMicroDownload: TFrmMicroDownload
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #24494#31471#36164#28304#19979#36733
  ClientHeight = 200
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 400
    Height = 200
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 16
      Width = 84
      Height = 13
      Caption = #27491#22312#20934#22791#19979#36733'...'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblStatus: TLabel
      Left = 16
      Top = 40
      Width = 60
      Height = 13
      Caption = #29366#24577': '#31561#24453#20013
    end
    object lblFileName: TLabel
      Left = 16
      Top = 64
      Width = 36
      Height = 13
      Caption = #25991#20214': '
    end
    object lblProgress: TLabel
      Left = 16
      Top = 88
      Width = 48
      Height = 13
      Caption = #36827#24230': 0%'
    end
    object lblSpeed: TLabel
      Left = 16
      Top = 112
      Width = 60
      Height = 13
      Caption = #36895#24230': 0 KB/s'
    end
    object lblETA: TLabel
      Left = 16
      Top = 136
      Width = 84
      Height = 13
      Caption = #21097#20313#26102#38388': --:--'
    end
    object ProgressBar: TProgressBar
      Left = 200
      Top = 88
      Width = 180
      Height = 17
      Max = 10000
      TabOrder = 0
    end
    object btnCancel: TBitBtn
      Left = 225
      Top = 160
      Width = 75
      Height = 25
      Caption = #21462#28040
      Kind = bkCancel
      NumGlyphs = 2
      TabOrder = 1
      OnClick = btnCancelClick
    end
    object btnHide: TBitBtn
      Left = 310
      Top = 160
      Width = 75
      Height = 25
      Caption = #38544#34255
      TabOrder = 2
      OnClick = btnHideClick
    end
  end
  object Timer: TTimer
    Interval = 500
    OnTimer = TimerTimer
    Left = 32
    Top = 160
  end
end
