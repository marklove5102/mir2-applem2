unit MicroGateMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, Menus, ActnList, ImgList,
  MicroShare, MicroClient, MicroServer, ResourceManager, DownloadManager;

type
  TFrmMicroGate = class(TForm)
    MainMenu: TMainMenu;
    mnuFile: TMenuItem;
    mnuStart: TMenuItem;
    mnuStop: TMenuItem;
    mnuSep1: TMenuItem;
    mnuExit: TMenuItem;
    mnuConfig: TMenuItem;
    mnuSettings: TMenuItem;
    mnuHelp: TMenuItem;
    mnuAbout: TMenuItem;
    StatusBar: TStatusBar;
    PageControl: TPageControl;
    tsMain: TTabSheet;
    tsConnections: TTabSheet;
    tsDownloads: TTabSheet;
    tsLogs: TTabSheet;
    tsStats: TTabSheet;
    
    // 主页面控件
    pnlMain: TPanel;
    lblStatus: TLabel;
    lblConnections: TLabel;
    lblDownloads: TLabel;
    lblTotalTransfer: TLabel;
    btnStart: TButton;
    btnStop: TButton;
    btnSettings: TButton;
    
    // 连接页面控件
    lvConnections: TListView;
    pnlConnButtons: TPanel;
    btnDisconnect: TButton;
    btnDisconnectAll: TButton;
    btnRefreshConn: TButton;
    
    // 下载页面控件
    lvDownloads: TListView;
    pnlDownloadButtons: TPanel;
    btnCancelDownload: TButton;
    btnCancelAll: TButton;
    btnRefreshDownload: TButton;
    
    // 日志页面控件
    memoLogs: TMemo;
    pnlLogButtons: TPanel;
    btnClearLogs: TButton;
    btnSaveLogs: TButton;
    chkAutoScroll: TCheckBox;
    
    // 统计页面控件
    pnlStats: TPanel;
    lblTotalConnections: TLabel;
    lblTotalDownloads: TLabel;
    lblTotalBytes: TLabel;
    lblAvgSpeed: TLabel;
    lblUptime: TLabel;
    btnResetStats: TButton;
    
    // 定时器
    tmrUpdate: TTimer;
    tmrStats: TTimer;
    
    // 事件处理
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure mnuStartClick(Sender: TObject);
    procedure mnuStopClick(Sender: TObject);
    procedure mnuExitClick(Sender: TObject);
    procedure mnuSettingsClick(Sender: TObject);
    procedure mnuAboutClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnDisconnectAllClick(Sender: TObject);
    procedure btnRefreshConnClick(Sender: TObject);
    procedure btnCancelDownloadClick(Sender: TObject);
    procedure btnCancelAllClick(Sender: TObject);
    procedure btnRefreshDownloadClick(Sender: TObject);
    procedure btnClearLogsClick(Sender: TObject);
    procedure btnSaveLogsClick(Sender: TObject);
    procedure btnResetStatsClick(Sender: TObject);
    procedure tmrUpdateTimer(Sender: TObject);
    procedure tmrStatsTimer(Sender: TObject);
    procedure lvConnectionsDblClick(Sender: TObject);
    procedure lvDownloadsDblClick(Sender: TObject);
    
  private
    FMicroClientManager: TMicroClientManager;
    FMicroServerManager: TMicroServerManager;
    FResourceManager: TResourceManager;
    FDownloadManager: TDownloadManager;
    FStartTime: TDateTime;
    FTotalConnections: Integer;
    FTotalDownloads: Integer;
    FTotalBytes: Int64;
    FIsRunning: Boolean;
    
    procedure InitializeComponents;
    procedure LoadConfig;
    procedure SaveConfig;
    procedure UpdateUI;
    procedure UpdateConnectionsList;
    procedure UpdateDownloadsList;
    procedure UpdateStats;
    procedure AddLog(const sMsg: string; bError: Boolean = False);
    procedure SetRunning(bRunning: Boolean);
    
    // 事件处理方法
    procedure OnClientConnect(Sender: TObject; Connection: pTMicroConnectionInfo);
    procedure OnClientDisconnect(Sender: TObject; Connection: pTMicroConnectionInfo);
    procedure OnResourceRequest(Sender: TObject; Request: pTMicroResourceRequest);
    procedure OnDownloadProgress(Sender: TObject; Task: TMicroDownloadTask);
    procedure OnDownloadComplete(Sender: TObject; Task: TMicroDownloadTask);
    procedure OnDownloadError(Sender: TObject; Task: TMicroDownloadTask; ErrorCode: Integer; const ErrorMsg: string);
    
  public
    property IsRunning: Boolean read FIsRunning;
  end;

var
  FrmMicroGate: TFrmMicroGate;

implementation

{$R *.dfm}

uses
  IniFiles, DateUtils, ShellAPI;

procedure TFrmMicroGate.FormCreate(Sender: TObject);
begin
  FStartTime := Now;
  FTotalConnections := 0;
  FTotalDownloads := 0;
  FTotalBytes := 0;
  FIsRunning := False;
  
  InitializeComponents;
  LoadConfig;
  
  // 创建管理器实例
  FMicroClientManager := TMicroClientManager.Create;
  FMicroServerManager := TMicroServerManager.Create;
  FResourceManager := TResourceManager.Create;
  FDownloadManager := TDownloadManager.Create;
  
  // 设置事件处理
  FMicroClientManager.OnConnect := OnClientConnect;
  FMicroClientManager.OnDisconnect := OnClientDisconnect;
  FMicroClientManager.OnResourceRequest := OnResourceRequest;
  FDownloadManager.OnProgress := OnDownloadProgress;
  FDownloadManager.OnComplete := OnDownloadComplete;
  FDownloadManager.OnError := OnDownloadError;
  
  UpdateUI;
  AddLog('微端网关启动完成');
end;

procedure TFrmMicroGate.FormDestroy(Sender: TObject);
begin
  if FIsRunning then
    SetRunning(False);
    
  SaveConfig;
  
  FDownloadManager.Free;
  FResourceManager.Free;
  FMicroServerManager.Free;
  FMicroClientManager.Free;
  
  AddLog('微端网关关闭');
end;

procedure TFrmMicroGate.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FIsRunning then begin
    if MessageDlg('服务正在运行，确定要退出吗？', mtConfirmation, [mbYes, mbNo], 0) = mrNo then begin
      Action := caNone;
      Exit;
    end;
  end;
end;

procedure TFrmMicroGate.InitializeComponents;
begin
  // 设置窗体属性
  Caption := '微端网关服务器 v' + MICRO_VERSION;
  
  // 初始化连接列表
  with lvConnections do begin
    ViewStyle := vsReport;
    RowSelect := True;
    GridLines := True;
    FullRowSelect := True;
    
    Columns.Add.Caption := '连接ID';
    Columns.Add.Caption := '远程地址';
    Columns.Add.Caption := '连接时间';
    Columns.Add.Caption := '发送字节';
    Columns.Add.Caption := '接收字节';
    Columns.Add.Caption := '请求数';
    Columns.Add.Caption := '状态';
    
    Columns[0].Width := 80;
    Columns[1].Width := 120;
    Columns[2].Width := 120;
    Columns[3].Width := 100;
    Columns[4].Width := 100;
    Columns[5].Width := 80;
    Columns[6].Width := 80;
  end;
  
  // 初始化下载列表
  with lvDownloads do begin
    ViewStyle := vsReport;
    RowSelect := True;
    GridLines := True;
    FullRowSelect := True;
    
    Columns.Add.Caption := '任务ID';
    Columns.Add.Caption := '文件名';
    Columns.Add.Caption := '文件大小';
    Columns.Add.Caption := '进度';
    Columns.Add.Caption := '速度';
    Columns.Add.Caption := '剩余时间';
    Columns.Add.Caption := '状态';
    
    Columns[0].Width := 80;
    Columns[1].Width := 200;
    Columns[2].Width := 100;
    Columns[3].Width := 100;
    Columns[4].Width := 100;
    Columns[5].Width := 100;
    Columns[6].Width := 80;
  end;
  
  // 设置定时器
  tmrUpdate.Interval := 1000; // 1秒更新一次
  tmrUpdate.Enabled := True;
  
  tmrStats.Interval := 5000; // 5秒更新一次统计
  tmrStats.Enabled := True;
end;

procedure TFrmMicroGate.LoadConfig;
var
  IniFile: TIniFile;
  sConfigFile: string;
begin
  sConfigFile := ExtractFilePath(ParamStr(0)) + 'MicroGate.ini';
  IniFile := TIniFile.Create(sConfigFile);
  try
    g_Config.nListenPort := IniFile.ReadInteger('Server', 'ListenPort', DEFAULT_MICRO_PORT);
    g_Config.nServerPort := IniFile.ReadInteger('Server', 'ServerPort', DEFAULT_SERVER_PORT);
    g_Config.sServerAddr := IniFile.ReadString('Server', 'ServerAddr', '127.0.0.1');
    g_Config.nMaxConnections := IniFile.ReadInteger('Server', 'MaxConnections', DEFAULT_MAX_CONNECTIONS);
    g_Config.nChunkSize := IniFile.ReadInteger('Transfer', 'ChunkSize', DEFAULT_CHUNK_SIZE);
    g_Config.nCacheSize := IniFile.ReadInteger('Transfer', 'CacheSize', DEFAULT_CACHE_SIZE);
    g_Config.nTimeOut := IniFile.ReadInteger('Transfer', 'TimeOut', 30000);
    g_Config.nMaxDownloadSpeed := IniFile.ReadInteger('Transfer', 'MaxDownloadSpeed', 0);
    g_Config.nMaxConcurrentDownloads := IniFile.ReadInteger('Transfer', 'MaxConcurrentDownloads', 10);
    g_Config.bEnableCompress := IniFile.ReadBool('Options', 'EnableCompress', True);
    g_Config.bEnableEncrypt := IniFile.ReadBool('Options', 'EnableEncrypt', False);
    g_Config.bEnableLog := IniFile.ReadBool('Options', 'EnableLog', True);
    g_Config.sLogPath := IniFile.ReadString('Options', 'LogPath', ExtractFilePath(ParamStr(0)) + 'Logs');
  finally
    IniFile.Free;
  end;
end;

procedure TFrmMicroGate.SaveConfig;
var
  IniFile: TIniFile;
  sConfigFile: string;
begin
  sConfigFile := ExtractFilePath(ParamStr(0)) + 'MicroGate.ini';
  IniFile := TIniFile.Create(sConfigFile);
  try
    IniFile.WriteInteger('Server', 'ListenPort', g_Config.nListenPort);
    IniFile.WriteInteger('Server', 'ServerPort', g_Config.nServerPort);
    IniFile.WriteString('Server', 'ServerAddr', g_Config.sServerAddr);
    IniFile.WriteInteger('Server', 'MaxConnections', g_Config.nMaxConnections);
    IniFile.WriteInteger('Transfer', 'ChunkSize', g_Config.nChunkSize);
    IniFile.WriteInteger('Transfer', 'CacheSize', g_Config.nCacheSize);
    IniFile.WriteInteger('Transfer', 'TimeOut', g_Config.nTimeOut);
    IniFile.WriteInteger('Transfer', 'MaxDownloadSpeed', g_Config.nMaxDownloadSpeed);
    IniFile.WriteInteger('Transfer', 'MaxConcurrentDownloads', g_Config.nMaxConcurrentDownloads);
    IniFile.WriteBool('Options', 'EnableCompress', g_Config.bEnableCompress);
    IniFile.WriteBool('Options', 'EnableEncrypt', g_Config.bEnableEncrypt);
    IniFile.WriteBool('Options', 'EnableLog', g_Config.bEnableLog);
    IniFile.WriteString('Options', 'LogPath', g_Config.sLogPath);
  finally
    IniFile.Free;
  end;
end;

procedure TFrmMicroGate.UpdateUI;
begin
  // 更新主界面状态
  if FIsRunning then begin
    lblStatus.Caption := '状态: 运行中';
    lblStatus.Font.Color := clGreen;
    btnStart.Enabled := False;
    btnStop.Enabled := True;
    mnuStart.Enabled := False;
    mnuStop.Enabled := True;
  end else begin
    lblStatus.Caption := '状态: 已停止';
    lblStatus.Font.Color := clRed;
    btnStart.Enabled := True;
    btnStop.Enabled := False;
    mnuStart.Enabled := True;
    mnuStop.Enabled := False;
  end;
  
  // 更新连接数
  lblConnections.Caption := '连接数: ' + IntToStr(g_ConnectionList.Count);
  
  // 更新下载数
  lblDownloads.Caption := '下载任务: ' + IntToStr(g_DownloadTasks.Count);
  
  // 更新传输量
  lblTotalTransfer.Caption := '总传输: ' + FormatBytes(FTotalBytes);
  
  // 更新状态栏
  StatusBar.Panels[0].Text := '端口: ' + IntToStr(g_Config.nListenPort);
  StatusBar.Panels[1].Text := '连接: ' + IntToStr(g_ConnectionList.Count) + '/' + IntToStr(g_Config.nMaxConnections);
  StatusBar.Panels[2].Text := '任务: ' + IntToStr(g_DownloadTasks.Count);
  StatusBar.Panels[3].Text := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
end;

procedure TFrmMicroGate.UpdateConnectionsList;
var
  i: Integer;
  Connection: pTMicroConnectionInfo;
  Item: TListItem;
begin
  lvConnections.Items.BeginUpdate;
  try
    lvConnections.Items.Clear;
    
    g_CriticalSection.Enter;
    try
      for i := 0 to g_ConnectionList.Count - 1 do begin
        Connection := g_ConnectionList[i];
        if Connection <> nil then begin
          Item := lvConnections.Items.Add;
          Item.Caption := IntToStr(i + 1);
          Item.SubItems.Add(Connection.RemoteAddr);
          Item.SubItems.Add(FormatDateTime('hh:nn:ss', Connection.ConnectTime));
          Item.SubItems.Add(FormatBytes(Connection.SendBytes));
          Item.SubItems.Add(FormatBytes(Connection.RecvBytes));
          Item.SubItems.Add(IntToStr(Connection.RequestCount));
          Item.SubItems.Add('活动');
          Item.Data := Connection;
        end;
      end;
    finally
      g_CriticalSection.Leave;
    end;
  finally
    lvConnections.Items.EndUpdate;
  end;
end;

procedure TFrmMicroGate.UpdateDownloadsList;
var
  i: Integer;
  Task: TMicroDownloadTask;
  Item: TListItem;
  sProgress, sSpeed, sETA: string;
begin
  lvDownloads.Items.BeginUpdate;
  try
    lvDownloads.Items.Clear;
    
    g_CriticalSection.Enter;
    try
      for i := 0 to g_DownloadTasks.Count - 1 do begin
        Task := TMicroDownloadTask(g_DownloadTasks[i]);
        if Task <> nil then begin
          Item := lvDownloads.Items.Add;
          Item.Caption := IntToStr(Task.RequestId);
          Item.SubItems.Add(ExtractFileName(Task.FileName));
          Item.SubItems.Add(FormatBytes(Task.FileSize));
          
          sProgress := Format('%.1f%%', [Task.GetProgress / 100.0]);
          Item.SubItems.Add(sProgress);
          
          sSpeed := FormatBytes(Task.Speed) + '/s';
          Item.SubItems.Add(sSpeed);
          
          if Task.GetETA > 0 then
            sETA := FormatDateTime('nn:ss', Task.GetETA / SecsPerDay)
          else
            sETA := '--:--';
          Item.SubItems.Add(sETA);
          
          if Task.GetProgress >= 10000 then
            Item.SubItems.Add('完成')
          else
            Item.SubItems.Add('下载中');
            
          Item.Data := Task;
        end;
      end;
    finally
      g_CriticalSection.Leave;
    end;
  finally
    lvDownloads.Items.EndUpdate;
  end;
end;

procedure TFrmMicroGate.UpdateStats;
var
  dwUptime: LongWord;
  sUptime: string;
  nAvgSpeed: Integer;
begin
  // 更新运行时间
  dwUptime := SecondsBetween(Now, FStartTime);
  sUptime := Format('%d天 %d小时 %d分钟', [
    dwUptime div SecsPerDay,
    (dwUptime mod SecsPerDay) div SecsPerHour,
    (dwUptime mod SecsPerHour) div SecsPerMin
  ]);
  lblUptime.Caption := '运行时间: ' + sUptime;
  
  // 更新统计信息
  lblTotalConnections.Caption := '总连接数: ' + IntToStr(FTotalConnections);
  lblTotalDownloads.Caption := '总下载数: ' + IntToStr(FTotalDownloads);
  lblTotalBytes.Caption := '总流量: ' + FormatBytes(FTotalBytes);
  
  // 计算平均速度
  if dwUptime > 0 then
    nAvgSpeed := FTotalBytes div dwUptime
  else
    nAvgSpeed := 0;
  lblAvgSpeed.Caption := '平均速度: ' + FormatBytes(nAvgSpeed) + '/s';
end;

procedure TFrmMicroGate.AddLog(const sMsg: string; bError: Boolean);
var
  sLogMsg: string;
begin
  sLogMsg := FormatDateTime('[hh:nn:ss] ', Now) + sMsg;
  
  memoLogs.Lines.Add(sLogMsg);
  
  // 自动滚动到底部
  if chkAutoScroll.Checked then begin
    memoLogs.SelStart := Length(memoLogs.Text);
    memoLogs.SelLength := 0;
    SendMessage(memoLogs.Handle, EM_SCROLLCARET, 0, 0);
  end;
  
  // 限制日志行数
  while memoLogs.Lines.Count > 1000 do
    memoLogs.Lines.Delete(0);
    
  // 写入日志文件
  WriteLog(sMsg, bError);
end;

procedure TFrmMicroGate.SetRunning(bRunning: Boolean);
begin
  FIsRunning := bRunning;
  
  if bRunning then begin
    try
      // 启动服务
      FMicroClientManager.Start(g_Config.nListenPort);
      FMicroServerManager.Connect(g_Config.sServerAddr, g_Config.nServerPort);
      FResourceManager.Initialize;
      FDownloadManager.Start;
      
      AddLog('微端网关服务启动成功，监听端口: ' + IntToStr(g_Config.nListenPort));
    except
      on E: Exception do begin
        AddLog('启动服务失败: ' + E.Message, True);
        FIsRunning := False;
        raise;
      end;
    end;
  end else begin
    try
      // 停止服务
      FDownloadManager.Stop;
      FResourceManager.Finalize;
      FMicroServerManager.Disconnect;
      FMicroClientManager.Stop;
      
      AddLog('微端网关服务已停止');
    except
      on E: Exception do begin
        AddLog('停止服务时出错: ' + E.Message, True);
      end;
    end;
  end;
  
  UpdateUI;
end;

// 事件处理方法实现
procedure TFrmMicroGate.OnClientConnect(Sender: TObject; Connection: pTMicroConnectionInfo);
begin
  Inc(FTotalConnections);
  AddLog('客户端连接: ' + Connection.RemoteAddr);
end;

procedure TFrmMicroGate.OnClientDisconnect(Sender: TObject; Connection: pTMicroConnectionInfo);
begin
  AddLog('客户端断开: ' + Connection.RemoteAddr);
end;

procedure TFrmMicroGate.OnResourceRequest(Sender: TObject; Request: pTMicroResourceRequest);
begin
  AddLog('资源请求: ' + string(Request.sFileName));
  // 这里会调用下载管理器来处理请求
end;

procedure TFrmMicroGate.OnDownloadProgress(Sender: TObject; Task: TMicroDownloadTask);
begin
  // 更新下载进度，这个事件会频繁触发，所以不记录日志
end;

procedure TFrmMicroGate.OnDownloadComplete(Sender: TObject; Task: TMicroDownloadTask);
begin
  Inc(FTotalDownloads);
  FTotalBytes := FTotalBytes + Task.FileSize;
  AddLog('下载完成: ' + ExtractFileName(Task.FileName));
end;

procedure TFrmMicroGate.OnDownloadError(Sender: TObject; Task: TMicroDownloadTask; ErrorCode: Integer; const ErrorMsg: string);
begin
  AddLog('下载错误: ' + ExtractFileName(Task.FileName) + ' - ' + ErrorMsg, True);
end;

// 菜单和按钮事件处理
procedure TFrmMicroGate.mnuStartClick(Sender: TObject);
begin
  btnStartClick(Sender);
end;

procedure TFrmMicroGate.mnuStopClick(Sender: TObject);
begin
  btnStopClick(Sender);
end;

procedure TFrmMicroGate.mnuExitClick(Sender: TObject);
begin
  Close;
end;

procedure TFrmMicroGate.mnuSettingsClick(Sender: TObject);
begin
  btnSettingsClick(Sender);
end;

procedure TFrmMicroGate.mnuAboutClick(Sender: TObject);
begin
  MessageDlg('微端网关服务器 v' + MICRO_VERSION + #13#10#13#10 +
             '用于传奇游戏的微端资源下载服务' + #13#10 +
             'Copyright (c) 2024', mtInformation, [mbOK], 0);
end;

procedure TFrmMicroGate.btnStartClick(Sender: TObject);
begin
  try
    SetRunning(True);
  except
    on E: Exception do begin
      MessageDlg('启动服务失败: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFrmMicroGate.btnStopClick(Sender: TObject);
begin
  try
    SetRunning(False);
  except
    on E: Exception do begin
      MessageDlg('停止服务失败: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFrmMicroGate.btnSettingsClick(Sender: TObject);
begin
  // TODO: 实现设置对话框
  MessageDlg('设置功能尚未实现', mtInformation, [mbOK], 0);
end;

procedure TFrmMicroGate.btnDisconnectClick(Sender: TObject);
var
  Connection: pTMicroConnectionInfo;
begin
  if lvConnections.Selected <> nil then begin
    Connection := lvConnections.Selected.Data;
    if Connection <> nil then begin
      FMicroClientManager.DisconnectClient(Connection);
      AddLog('手动断开连接: ' + Connection.RemoteAddr);
    end;
  end;
end;

procedure TFrmMicroGate.btnDisconnectAllClick(Sender: TObject);
begin
  if MessageDlg('确定要断开所有连接吗？', mtConfirmation, [mbYes, mbNo], 0) = mrYes then begin
    FMicroClientManager.DisconnectAll;
    AddLog('断开所有连接');
  end;
end;

procedure TFrmMicroGate.btnRefreshConnClick(Sender: TObject);
begin
  UpdateConnectionsList;
end;

procedure TFrmMicroGate.btnCancelDownloadClick(Sender: TObject);
var
  Task: TMicroDownloadTask;
begin
  if lvDownloads.Selected <> nil then begin
    Task := lvDownloads.Selected.Data;
    if Task <> nil then begin
      FDownloadManager.CancelDownload(Task.RequestId);
      AddLog('取消下载: ' + ExtractFileName(Task.FileName));
    end;
  end;
end;

procedure TFrmMicroGate.btnCancelAllClick(Sender: TObject);
begin
  if MessageDlg('确定要取消所有下载任务吗？', mtConfirmation, [mbYes, mbNo], 0) = mrYes then begin
    FDownloadManager.CancelAll;
    AddLog('取消所有下载任务');
  end;
end;

procedure TFrmMicroGate.btnRefreshDownloadClick(Sender: TObject);
begin
  UpdateDownloadsList;
end;

procedure TFrmMicroGate.btnClearLogsClick(Sender: TObject);
begin
  memoLogs.Clear;
end;

procedure TFrmMicroGate.btnSaveLogsClick(Sender: TObject);
var
  SaveDialog: TSaveDialog;
begin
  SaveDialog := TSaveDialog.Create(Self);
  try
    SaveDialog.Filter := '文本文件|*.txt|所有文件|*.*';
    SaveDialog.DefaultExt := 'txt';
    SaveDialog.FileName := 'MicroGate_Log_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.txt';
    
    if SaveDialog.Execute then begin
      memoLogs.Lines.SaveToFile(SaveDialog.FileName);
      AddLog('日志已保存到: ' + SaveDialog.FileName);
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TFrmMicroGate.btnResetStatsClick(Sender: TObject);
begin
  if MessageDlg('确定要重置统计信息吗？', mtConfirmation, [mbYes, mbNo], 0) = mrYes then begin
    FStartTime := Now;
    FTotalConnections := 0;
    FTotalDownloads := 0;
    FTotalBytes := 0;
    UpdateStats;
    AddLog('统计信息已重置');
  end;
end;

procedure TFrmMicroGate.tmrUpdateTimer(Sender: TObject);
begin
  UpdateUI;
  if PageControl.ActivePage = tsConnections then
    UpdateConnectionsList;
  if PageControl.ActivePage = tsDownloads then
    UpdateDownloadsList;
end;

procedure TFrmMicroGate.tmrStatsTimer(Sender: TObject);
begin
  if PageControl.ActivePage = tsStats then
    UpdateStats;
end;

procedure TFrmMicroGate.lvConnectionsDblClick(Sender: TObject);
var
  Connection: pTMicroConnectionInfo;
  sInfo: string;
begin
  if lvConnections.Selected <> nil then begin
    Connection := lvConnections.Selected.Data;
    if Connection <> nil then begin
      sInfo := '连接详细信息:' + #13#10 +
               '远程地址: ' + Connection.RemoteAddr + #13#10 +
               '连接时间: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Connection.ConnectTime) + #13#10 +
               '最后活动: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Connection.LastActiveTime) + #13#10 +
               '发送字节: ' + FormatBytes(Connection.SendBytes) + #13#10 +
               '接收字节: ' + FormatBytes(Connection.RecvBytes) + #13#10 +
               '请求次数: ' + IntToStr(Connection.RequestCount);
      MessageDlg(sInfo, mtInformation, [mbOK], 0);
    end;
  end;
end;

procedure TFrmMicroGate.lvDownloadsDblClick(Sender: TObject);
var
  Task: TMicroDownloadTask;
  sInfo: string;
begin
  if lvDownloads.Selected <> nil then begin
    Task := lvDownloads.Selected.Data;
    if Task <> nil then begin
      sInfo := '下载任务详细信息:' + #13#10 +
               '任务ID: ' + IntToStr(Task.RequestId) + #13#10 +
               '文件名: ' + Task.FileName + #13#10 +
               '文件大小: ' + FormatBytes(Task.FileSize) + #13#10 +
               '已下载: ' + FormatBytes(Task.DownloadedSize) + #13#10 +
               '进度: ' + Format('%.2f%%', [Task.GetProgress / 100.0]) + #13#10 +
               '速度: ' + FormatBytes(Task.Speed) + '/s' + #13#10 +
               '创建时间: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Task.CreateTime);
      MessageDlg(sInfo, mtInformation, [mbOK], 0);
    end;
  end;
end;

// 工具函数
function FormatBytes(nBytes: Int64): string;
const
  Sizes: array[0..4] of string = ('B', 'KB', 'MB', 'GB', 'TB');
var
  i: Integer;
  dSize: Double;
begin
  dSize := nBytes;
  i := 0;
  while (dSize >= 1024) and (i < High(Sizes)) do begin
    dSize := dSize / 1024;
    Inc(i);
  end;
  
  if i = 0 then
    Result := IntToStr(nBytes) + ' ' + Sizes[i]
  else
    Result := Format('%.1f %s', [dSize, Sizes[i]]);
end;

end.