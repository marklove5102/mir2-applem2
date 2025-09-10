object FrmMicroGate: TFrmMicroGate
  Left = 0
  Top = 0
  Caption = #24494#31471#32593#20851#26381#21153#22120
  ClientHeight = 600
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object PageControl: TPageControl
    Left = 0
    Top = 0
    Width = 900
    Height = 561
    ActivePage = tsMain
    Align = alClient
    TabOrder = 0
    object tsMain: TTabSheet
      Caption = #20027#39029#38754
      object pnlMain: TPanel
        Left = 0
        Top = 0
        Width = 892
        Height = 533
        Align = alClient
        TabOrder = 0
        object lblStatus: TLabel
          Left = 16
          Top = 16
          Width = 60
          Height = 13
          Caption = #29366#24577': '#24050#20572#27490
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clRed
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object lblConnections: TLabel
          Left = 16
          Top = 40
          Width = 48
          Height = 13
          Caption = #36830#25509#25968': 0'
        end
        object lblDownloads: TLabel
          Left = 16
          Top = 64
          Width = 72
          Height = 13
          Caption = #19979#36733#20219#21153': 0'
        end
        object lblTotalTransfer: TLabel
          Left = 16
          Top = 88
          Width = 60
          Height = 13
          Caption = #24635#20256#36755': 0B'
        end
        object btnStart: TButton
          Left = 16
          Top = 120
          Width = 75
          Height = 25
          Caption = #21551#21160#26381#21153
          TabOrder = 0
          OnClick = btnStartClick
        end
        object btnStop: TButton
          Left = 104
          Top = 120
          Width = 75
          Height = 25
          Caption = #20572#27490#26381#21153
          Enabled = False
          TabOrder = 1
          OnClick = btnStopClick
        end
        object btnSettings: TButton
          Left = 192
          Top = 120
          Width = 75
          Height = 25
          Caption = #35774#32622
          TabOrder = 2
          OnClick = btnSettingsClick
        end
      end
    end
    object tsConnections: TTabSheet
      Caption = #36830#25509#31649#29702
      ImageIndex = 1
      object lvConnections: TListView
        Left = 0
        Top = 0
        Width = 892
        Height = 492
        Align = alClient
        Columns = <
          item
            Caption = #36830#25509'ID'
            Width = 80
          end
          item
            Caption = #36828#31243#22320#22336
            Width = 120
          end
          item
            Caption = #36830#25509#26102#38388
            Width = 120
          end
          item
            Caption = #21457#36865#23383#33410
            Width = 100
          end
          item
            Caption = #25509#25910#23383#33410
            Width = 100
          end
          item
            Caption = #35831#27714#25968
            Width = 80
          end
          item
            Caption = #29366#24577
            Width = 80
          end>
        FullRowSelect = True
        GridLines = True
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnDblClick = lvConnectionsDblClick
      end
      object pnlConnButtons: TPanel
        Left = 0
        Top = 492
        Width = 892
        Height = 41
        Align = alBottom
        TabOrder = 1
        object btnDisconnect: TButton
          Left = 8
          Top = 8
          Width = 75
          Height = 25
          Caption = #26029#24320#36830#25509
          TabOrder = 0
          OnClick = btnDisconnectClick
        end
        object btnDisconnectAll: TButton
          Left = 96
          Top = 8
          Width = 75
          Height = 25
          Caption = #26029#24320#25152#26377
          TabOrder = 1
          OnClick = btnDisconnectAllClick
        end
        object btnRefreshConn: TButton
          Left = 184
          Top = 8
          Width = 75
          Height = 25
          Caption = #21047#26032
          TabOrder = 2
          OnClick = btnRefreshConnClick
        end
      end
    end
    object tsDownloads: TTabSheet
      Caption = #19979#36733#31649#29702
      ImageIndex = 2
      object lvDownloads: TListView
        Left = 0
        Top = 0
        Width = 892
        Height = 492
        Align = alClient
        Columns = <
          item
            Caption = #20219#21153'ID'
            Width = 80
          end
          item
            Caption = #25991#20214#21517
            Width = 200
          end
          item
            Caption = #25991#20214#22823#23567
            Width = 100
          end
          item
            Caption = #36827#24230
            Width = 100
          end
          item
            Caption = #36895#24230
            Width = 100
          end
          item
            Caption = #21097#20313#26102#38388
            Width = 100
          end
          item
            Caption = #29366#24577
            Width = 80
          end>
        FullRowSelect = True
        GridLines = True
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnDblClick = lvDownloadsDblClick
      end
      object pnlDownloadButtons: TPanel
        Left = 0
        Top = 492
        Width = 892
        Height = 41
        Align = alBottom
        TabOrder = 1
        object btnCancelDownload: TButton
          Left = 8
          Top = 8
          Width = 75
          Height = 25
          Caption = #21462#28040#19979#36733
          TabOrder = 0
          OnClick = btnCancelDownloadClick
        end
        object btnCancelAll: TButton
          Left = 96
          Top = 8
          Width = 75
          Height = 25
          Caption = #21462#28040#25152#26377
          TabOrder = 1
          OnClick = btnCancelAllClick
        end
        object btnRefreshDownload: TButton
          Left = 184
          Top = 8
          Width = 75
          Height = 25
          Caption = #21047#26032
          TabOrder = 2
          OnClick = btnRefreshDownloadClick
        end
      end
    end
    object tsLogs: TTabSheet
      Caption = #26085#24535#20449#24687
      ImageIndex = 3
      object memoLogs: TMemo
        Left = 0
        Top = 0
        Width = 892
        Height = 492
        Align = alClient
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
      object pnlLogButtons: TPanel
        Left = 0
        Top = 492
        Width = 892
        Height = 41
        Align = alBottom
        TabOrder = 1
        object btnClearLogs: TButton
          Left = 8
          Top = 8
          Width = 75
          Height = 25
          Caption = #28165#31354#26085#24535
          TabOrder = 0
          OnClick = btnClearLogsClick
        end
        object btnSaveLogs: TButton
          Left = 96
          Top = 8
          Width = 75
          Height = 25
          Caption = #20445#23384#26085#24535
          TabOrder = 1
          OnClick = btnSaveLogsClick
        end
        object chkAutoScroll: TCheckBox
          Left = 184
          Top = 12
          Width = 97
          Height = 17
          Caption = #33258#21160#28378#21160
          Checked = True
          State = cbChecked
          TabOrder = 2
        end
      end
    end
    object tsStats: TTabSheet
      Caption = #32479#35745#20449#24687
      ImageIndex = 4
      object pnlStats: TPanel
        Left = 0
        Top = 0
        Width = 892
        Height = 533
        Align = alClient
        TabOrder = 0
        object lblTotalConnections: TLabel
          Left = 16
          Top = 16
          Width = 72
          Height = 13
          Caption = #24635#36830#25509#25968': 0'
        end
        object lblTotalDownloads: TLabel
          Left = 16
          Top = 40
          Width = 72
          Height = 13
          Caption = #24635#19979#36733#25968': 0'
        end
        object lblTotalBytes: TLabel
          Left = 16
          Top = 64
          Width = 60
          Height = 13
          Caption = #24635#27969#37327': 0B'
        end
        object lblAvgSpeed: TLabel
          Left = 16
          Top = 88
          Width = 84
          Height = 13
          Caption = #24179#22343#36895#24230': 0B/s'
        end
        object lblUptime: TLabel
          Left = 16
          Top = 112
          Width = 84
          Height = 13
          Caption = #36816#34892#26102#38388': 0'#31186
        end
        object btnResetStats: TButton
          Left = 16
          Top = 144
          Width = 75
          Height = 25
          Caption = #37325#32622#32479#35745
          TabOrder = 0
          OnClick = btnResetStatsClick
        end
      end
    end
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 561
    Width = 900
    Height = 39
    Panels = <
      item
        Text = #31471#21475': 0'
        Width = 100
      end
      item
        Text = #36830#25509': 0/0'
        Width = 100
      end
      item
        Text = #20219#21153': 0'
        Width = 100
      end
      item
        Width = 50
      end>
  end
  object MainMenu: TMainMenu
    Left = 32
    Top = 32
    object mnuFile: TMenuItem
      Caption = #25991#20214'(&F)'
      object mnuStart: TMenuItem
        Caption = #21551#21160#26381#21153'(&S)'
        OnClick = mnuStartClick
      end
      object mnuStop: TMenuItem
        Caption = #20572#27490#26381#21153'(&T)'
        Enabled = False
        OnClick = mnuStopClick
      end
      object mnuSep1: TMenuItem
        Caption = '-'
      end
      object mnuExit: TMenuItem
        Caption = #36864#20986'(&X)'
        OnClick = mnuExitClick
      end
    end
    object mnuConfig: TMenuItem
      Caption = #37197#32622'(&C)'
      object mnuSettings: TMenuItem
        Caption = #35774#32622'(&S)'
        OnClick = mnuSettingsClick
      end
    end
    object mnuHelp: TMenuItem
      Caption = #24110#21161'(&H)'
      object mnuAbout: TMenuItem
        Caption = #20851#20110'(&A)'
        OnClick = mnuAboutClick
      end
    end
  end
  object tmrUpdate: TTimer
    Enabled = False
    Interval = 1000
    OnTimer = tmrUpdateTimer
    Left = 80
    Top = 32
  end
  object tmrStats: TTimer
    Enabled = False
    Interval = 5000
    OnTimer = tmrStatsTimer
    Left = 128
    Top = 32
  end
end
