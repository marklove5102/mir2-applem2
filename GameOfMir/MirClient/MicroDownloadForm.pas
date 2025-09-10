unit MicroDownloadForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Buttons;

type
  TFrmMicroDownload = class(TForm)
    pnlMain: TPanel;
    lblTitle: TLabel;
    lblStatus: TLabel;
    lblFileName: TLabel;
    lblProgress: TLabel;
    lblSpeed: TLabel;
    lblETA: TLabel;
    ProgressBar: TProgressBar;
    btnCancel: TBitBtn;
    btnHide: TBitBtn;
    Timer: TTimer;
    
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnCancelClick(Sender: TObject);
    procedure btnHideClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    
  private
    FMicroManager: TObject; // TMicroClientManager
    FCurrentTask: TObject;  // TClientDownloadTask
    FTotalTasks: Integer;
    FCompletedTasks: Integer;
    
    procedure UpdateDisplay;
    procedure UpdateTaskInfo(Task: TObject);
    function FormatBytes(nBytes: Int64): string;
    function FormatTime(nSeconds: LongWord): string;
    
  public
    procedure SetMicroManager(AMicroManager: TObject);
    procedure OnDownloadProgress(Sender: TObject);
    procedure OnDownloadComplete(Sender: TObject);
    procedure OnDownloadError(Sender: TObject);
    
    property CurrentTask: TObject read FCurrentTask write FCurrentTask;
  end;

var
  FrmMicroDownload: TFrmMicroDownload;

implementation

{$R *.dfm}

uses
  MicroClient;

procedure TFrmMicroDownload.FormCreate(Sender: TObject);
begin
  FMicroManager := nil;
  FCurrentTask := nil;
  FTotalTasks := 0;
  FCompletedTasks := 0;
  
  // 设置窗体属性
  Caption := '微端资源下载';
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  
  // 初始化控件
  lblTitle.Caption := '正在准备下载...';
  lblStatus.Caption := '状态: 等待中';
  lblFileName.Caption := '文件: ';
  lblProgress.Caption := '进度: 0%';
  lblSpeed.Caption := '速度: 0 KB/s';
  lblETA.Caption := '剩余时间: --:--';
  
  ProgressBar.Min := 0;
  ProgressBar.Max := 10000; // 支持小数点后两位
  ProgressBar.Position := 0;
  
  Timer.Interval := 500; // 0.5秒更新一次
  Timer.Enabled := True;
end;

procedure TFrmMicroDownload.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caHide; // 隐藏而不是关闭
end;

procedure TFrmMicroDownload.btnCancelClick(Sender: TObject);
begin
  if (FMicroManager <> nil) and (FCurrentTask <> nil) then begin
    // 取消当前下载任务
    var Manager := TMicroClientManager(FMicroManager);
    var Task := TClientDownloadTask(FCurrentTask);
    Manager.CancelDownload(Task.RequestId);
  end;
  
  Hide;
end;

procedure TFrmMicroDownload.btnHideClick(Sender: TObject);
begin
  Hide;
end;

procedure TFrmMicroDownload.TimerTimer(Sender: TObject);
begin
  UpdateDisplay;
end;

procedure TFrmMicroDownload.SetMicroManager(AMicroManager: TObject);
begin
  FMicroManager := AMicroManager;
  
  if FMicroManager <> nil then begin
    var Manager := TMicroClientManager(FMicroManager);
    Manager.OnDownloadProgress := OnDownloadProgress;
    Manager.OnDownloadComplete := OnDownloadComplete;
    Manager.OnDownloadError := OnDownloadError;
  end;
end;

procedure TFrmMicroDownload.UpdateDisplay;
begin
  if FMicroManager = nil then
    Exit;
    
  var Manager := TMicroClientManager(FMicroManager);
  
  // 更新总体状态
  Manager.FCriticalSection.Enter;
  try
    FTotalTasks := Manager.FDownloadTasks.Count;
    
    // 查找当前活动的任务
    FCurrentTask := nil;
    if FTotalTasks > 0 then begin
      for var i := 0 to FTotalTasks - 1 do begin
        var Task := TClientDownloadTask(Manager.FDownloadTasks[i]);
        if not Task.IsCompleted and not Task.IsCancelled then begin
          FCurrentTask := Task;
          Break;
        end;
      end;
    end;
  finally
    Manager.FCriticalSection.Leave;
  end;
  
  // 更新界面
  if FCurrentTask <> nil then begin
    UpdateTaskInfo(FCurrentTask);
  end else begin
    // 没有活动任务
    lblTitle.Caption := '下载完成';
    lblStatus.Caption := '状态: 完成';
    lblFileName.Caption := '文件: 无';
    lblProgress.Caption := '进度: 100%';
    lblSpeed.Caption := '速度: 0 KB/s';
    lblETA.Caption := '剩余时间: 00:00';
    ProgressBar.Position := ProgressBar.Max;
    
    // 如果没有任务了，可以自动隐藏
    if FTotalTasks = 0 then begin
      Timer.Enabled := False;
      // 延迟隐藏，让用户看到完成状态
      TTimer.Create(Self).OnTimer := procedure(Sender: TObject) begin
        TTimer(Sender).Free;
        Hide;
      end;
      TTimer(Self).Interval := 2000;
      TTimer(Self).Enabled := True;
    end;
  end;
end;

procedure TFrmMicroDownload.UpdateTaskInfo(Task: TObject);
var
  ClientTask: TClientDownloadTask;
  sProgress, sSpeed, sETA: string;
  nProgressPercent: Integer;
begin
  if Task = nil then
    Exit;
    
  ClientTask := TClientDownloadTask(Task);
  
  // 更新文件名
  lblFileName.Caption := '文件: ' + ExtractFileName(ClientTask.FileName);
  
  // 更新进度
  nProgressPercent := ClientTask.Progress div 100; // 转换为百分比
  sProgress := Format('进度: %d%% (%s / %s)', [
    nProgressPercent,
    FormatBytes(ClientTask.DownloadedSize),
    FormatBytes(ClientTask.FileSize)
  ]);
  lblProgress.Caption := sProgress;
  ProgressBar.Position := ClientTask.Progress;
  
  // 更新速度
  sSpeed := '速度: ' + FormatBytes(ClientTask.Speed) + '/s';
  lblSpeed.Caption := sSpeed;
  
  // 更新剩余时间
  sETA := '剩余时间: ' + FormatTime(ClientTask.ETA);
  lblETA.Caption := sETA;
  
  // 更新状态
  if ClientTask.ErrorMsg <> '' then begin
    lblStatus.Caption := '状态: 错误 - ' + ClientTask.ErrorMsg;
    lblStatus.Font.Color := clRed;
  end else if ClientTask.IsCancelled then begin
    lblStatus.Caption := '状态: 已取消';
    lblStatus.Font.Color := clGray;
  end else if ClientTask.IsCompleted then begin
    lblStatus.Caption := '状态: 完成';
    lblStatus.Font.Color := clGreen;
  end else begin
    lblStatus.Caption := '状态: 下载中';
    lblStatus.Font.Color := clBlue;
  end;
  
  // 更新标题
  lblTitle.Caption := Format('正在下载 (%d/%d)', [FCompletedTasks + 1, FTotalTasks]);
end;

function TFrmMicroDownload.FormatBytes(nBytes: Int64): string;
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

function TFrmMicroDownload.FormatTime(nSeconds: LongWord): string;
var
  nHours, nMins, nSecs: LongWord;
begin
  if nSeconds = 0 then begin
    Result := '--:--';
    Exit;
  end;
  
  nHours := nSeconds div 3600;
  nMins := (nSeconds mod 3600) div 60;
  nSecs := nSeconds mod 60;
  
  if nHours > 0 then
    Result := Format('%d:%02d:%02d', [nHours, nMins, nSecs])
  else
    Result := Format('%02d:%02d', [nMins, nSecs]);
end;

// 事件处理方法
procedure TFrmMicroDownload.OnDownloadProgress(Sender: TObject);
begin
  // 进度更新会通过Timer自动刷新，这里不需要特别处理
end;

procedure TFrmMicroDownload.OnDownloadComplete(Sender: TObject);
begin
  Inc(FCompletedTasks);
  
  // 显示完成消息
  var Task := TClientDownloadTask(Sender);
  var sMsg := '文件下载完成: ' + ExtractFileName(Task.FileName);
  
  // 这里可以添加完成提示
  Application.MessageBox(PChar(sMsg), '下载完成', MB_ICONINFORMATION);
end;

procedure TFrmMicroDownload.OnDownloadError(Sender: TObject);
begin
  // 显示错误消息
  var Task := TClientDownloadTask(Sender);
  var sMsg := '文件下载失败: ' + ExtractFileName(Task.FileName) + #13#10 + 
              '错误信息: ' + Task.ErrorMsg;
              
  Application.MessageBox(PChar(sMsg), '下载错误', MB_ICONERROR);
end;

end.
