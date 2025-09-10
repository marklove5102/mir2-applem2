unit DownloadManager;

interface

uses
  Windows, SysUtils, Classes, SyncObjs, Contnrs, MicroShare;

type
  // 下载管理器
  TDownloadManager = class
  private
    FDownloadTasks: TObjectList;
    FCriticalSection: TCriticalSection;
    FWorkerThreads: TList;
    FMaxConcurrentDownloads: Integer;
    FIsRunning: Boolean;
    FTotalDownloaded: Int64;
    FTotalUploaded: Int64;
    FActiveDownloads: Integer;
    
    // 事件
    FOnProgress: TNotifyEvent;
    FOnComplete: TNotifyEvent;
    FOnError: TNotifyEvent;
    
    procedure CreateWorkerThreads;
    procedure DestroyWorkerThreads;
    function GetNextTask: TMicroDownloadTask;
    procedure ProcessTask(Task: TMicroDownloadTask);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Start;
    procedure Stop;
    
    // 任务管理
    function AddDownloadTask(Connection: pTMicroConnectionInfo; const Request: TMicroResourceRequest): TMicroDownloadTask;
    procedure CancelDownload(dwRequestId: LongWord);
    procedure CancelAll;
    function GetTask(dwRequestId: LongWord): TMicroDownloadTask;
    function GetTaskCount: Integer;
    function GetActiveTaskCount: Integer;
    
    // 统计信息
    property TotalDownloaded: Int64 read FTotalDownloaded;
    property TotalUploaded: Int64 read FTotalUploaded;
    property ActiveDownloads: Integer read FActiveDownloads;
    property MaxConcurrentDownloads: Integer read FMaxConcurrentDownloads write FMaxConcurrentDownloads;
    
    // 事件属性
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
    property OnComplete: TNotifyEvent read FOnComplete write FOnComplete;
    property OnError: TNotifyEvent read FOnError write FOnError;
  end;

  // 下载工作线程
  TDownloadWorkerThread = class(TThread)
  private
    FManager: TDownloadManager;
    FCurrentTask: TMicroDownloadTask;
    
    procedure ProcessDownloadTask(Task: TMicroDownloadTask);
    procedure SendDataChunk(Task: TMicroDownloadTask; pData: Pointer; dwSize: LongWord; dwChunkIndex: LongWord);
    procedure SendProgress(Task: TMicroDownloadTask);
    procedure SendComplete(Task: TMicroDownloadTask);
    procedure SendError(Task: TMicroDownloadTask; dwErrorCode: LongWord; const sErrorMsg: string);
    
  protected
    procedure Execute; override;
    
  public
    constructor Create(AManager: TDownloadManager);
    destructor Destroy; override;
    
    property CurrentTask: TMicroDownloadTask read FCurrentTask;
  end;

  // 传输统计
  TTransferStats = record
    dwStartTime: LongWord;
    dwEndTime: LongWord;
    dwTotalBytes: LongWord;
    dwTransferredBytes: LongWord;
    dwCurrentSpeed: LongWord;
    dwAverageSpeed: LongWord;
    dwPeakSpeed: LongWord;
  end;

implementation

uses
  DateUtils, Math;

// TDownloadManager 实现

constructor TDownloadManager.Create;
begin
  inherited Create;
  FDownloadTasks := TObjectList.Create(True);
  FCriticalSection := TCriticalSection.Create;
  FWorkerThreads := TList.Create;
  FMaxConcurrentDownloads := g_Config.nMaxConcurrentDownloads;
  FIsRunning := False;
  FTotalDownloaded := 0;
  FTotalUploaded := 0;
  FActiveDownloads := 0;
end;

destructor TDownloadManager.Destroy;
begin
  Stop;
  FCriticalSection.Free;
  FWorkerThreads.Free;
  FDownloadTasks.Free;
  inherited Destroy;
end;

procedure TDownloadManager.Start;
begin
  if FIsRunning then
    Exit;
    
  FIsRunning := True;
  CreateWorkerThreads;
  WriteLog('下载管理器已启动，工作线程数: ' + IntToStr(FMaxConcurrentDownloads));
end;

procedure TDownloadManager.Stop;
begin
  if not FIsRunning then
    Exit;
    
  FIsRunning := False;
  DestroyWorkerThreads;
  CancelAll;
  WriteLog('下载管理器已停止');
end;

procedure TDownloadManager.CreateWorkerThreads;
var
  i: Integer;
  WorkerThread: TDownloadWorkerThread;
begin
  for i := 0 to FMaxConcurrentDownloads - 1 do begin
    WorkerThread := TDownloadWorkerThread.Create(Self);
    FWorkerThreads.Add(WorkerThread);
  end;
end;

procedure TDownloadManager.DestroyWorkerThreads;
var
  i: Integer;
  WorkerThread: TDownloadWorkerThread;
begin
  // 终止所有工作线程
  for i := 0 to FWorkerThreads.Count - 1 do begin
    WorkerThread := TDownloadWorkerThread(FWorkerThreads[i]);
    WorkerThread.Terminate;
  end;
  
  // 等待所有线程结束
  for i := 0 to FWorkerThreads.Count - 1 do begin
    WorkerThread := TDownloadWorkerThread(FWorkerThreads[i]);
    WorkerThread.WaitFor;
    WorkerThread.Free;
  end;
  
  FWorkerThreads.Clear;
end;

function TDownloadManager.GetNextTask: TMicroDownloadTask;
var
  i: Integer;
  Task: TMicroDownloadTask;
  HighestPriorityTask: TMicroDownloadTask;
  nHighestPriority: Integer;
begin
  Result := nil;
  HighestPriorityTask := nil;
  nHighestPriority := -1;
  
  FCriticalSection.Enter;
  try
    for i := 0 to FDownloadTasks.Count - 1 do begin
      Task := TMicroDownloadTask(FDownloadTasks[i]);
      if (Task <> nil) and (Task.CurrentPos < Task.FileSize) then begin
        if Task.Priority > nHighestPriority then begin
          nHighestPriority := Task.Priority;
          HighestPriorityTask := Task;
        end;
      end;
    end;
    
    Result := HighestPriorityTask;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TDownloadManager.ProcessTask(Task: TMicroDownloadTask);
begin
  if Task = nil then
    Exit;
    
  try
    // 更新活动下载数
    InterlockedIncrement(FActiveDownloads);
    
    // 处理下载任务的具体逻辑
    // 这里会从资源管理器或微端服务器获取数据
    
    // 模拟下载过程
    while (Task.CurrentPos < Task.FileSize) and FIsRunning do begin
      // 计算本次传输的数据块大小
      var dwChunkSize := Min(Task.ChunkSize, Task.FileSize - Task.CurrentPos);
      
      // 模拟数据传输
      Sleep(10); // 模拟网络延迟
      
      // 更新进度
      Task.CurrentPos := Task.CurrentPos + dwChunkSize;
      Task.UpdateProgress(Task.CurrentPos);
      
      // 触发进度事件
      if Assigned(FOnProgress) then
        FOnProgress(Task);
        
      // 更新统计
      FTotalUploaded := FTotalUploaded + dwChunkSize;
    end;
    
    // 下载完成
    if Task.CurrentPos >= Task.FileSize then begin
      if Assigned(FOnComplete) then
        FOnComplete(Task);
    end;
    
  except
    on E: Exception do begin
      WriteLog('处理下载任务时出错: ' + E.Message, True);
      if Assigned(FOnError) then
        FOnError(Task);
    end;
  end;
  
  // 更新活动下载数
  InterlockedDecrement(FActiveDownloads);
end;

function TDownloadManager.AddDownloadTask(Connection: pTMicroConnectionInfo; const Request: TMicroResourceRequest): TMicroDownloadTask;
var
  Task: TMicroDownloadTask;
begin
  Task := TMicroDownloadTask.Create;
  Task.RequestId := Request.dwRequestId;
  Task.FileName := string(Request.sFileName);
  Task.FileSize := Request.dwFileSize;
  Task.FileHash := string(Request.sFileHash);
  Task.StartPos := Request.dwStartPos;
  Task.ChunkSize := Request.dwChunkSize;
  Task.CurrentPos := Request.dwStartPos;
  Task.Priority := Request.btPriority;
  Task.Compress := Request.btCompress;
  Task.Connection := Connection;
  
  FCriticalSection.Enter;
  try
    FDownloadTasks.Add(Task);
  finally
    FCriticalSection.Leave;
  end;
  
  WriteDebugLog('添加下载任务: ' + Task.FileName + ', ID: ' + IntToStr(Task.RequestId));
  Result := Task;
end;

procedure TDownloadManager.CancelDownload(dwRequestId: LongWord);
var
  i: Integer;
  Task: TMicroDownloadTask;
begin
  FCriticalSection.Enter;
  try
    for i := FDownloadTasks.Count - 1 downto 0 do begin
      Task := TMicroDownloadTask(FDownloadTasks[i]);
      if Task.RequestId = dwRequestId then begin
        WriteDebugLog('取消下载任务: ' + Task.FileName + ', ID: ' + IntToStr(dwRequestId));
        FDownloadTasks.Delete(i);
        Break;
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TDownloadManager.CancelAll;
begin
  FCriticalSection.Enter;
  try
    FDownloadTasks.Clear;
    WriteLog('取消所有下载任务');
  finally
    FCriticalSection.Leave;
  end;
end;

function TDownloadManager.GetTask(dwRequestId: LongWord): TMicroDownloadTask;
var
  i: Integer;
  Task: TMicroDownloadTask;
begin
  Result := nil;
  
  FCriticalSection.Enter;
  try
    for i := 0 to FDownloadTasks.Count - 1 do begin
      Task := TMicroDownloadTask(FDownloadTasks[i]);
      if Task.RequestId = dwRequestId then begin
        Result := Task;
        Break;
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

function TDownloadManager.GetTaskCount: Integer;
begin
  FCriticalSection.Enter;
  try
    Result := FDownloadTasks.Count;
  finally
    FCriticalSection.Leave;
  end;
end;

function TDownloadManager.GetActiveTaskCount: Integer;
begin
  Result := FActiveDownloads;
end;

// TDownloadWorkerThread 实现

constructor TDownloadWorkerThread.Create(AManager: TDownloadManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FManager := AManager;
  FCurrentTask := nil;
end;

destructor TDownloadWorkerThread.Destroy;
begin
  inherited Destroy;
end;

procedure TDownloadWorkerThread.Execute;
var
  Task: TMicroDownloadTask;
begin
  while not Terminated and FManager.FIsRunning do begin
    try
      // 获取下一个任务
      Task := FManager.GetNextTask;
      if Task <> nil then begin
        FCurrentTask := Task;
        ProcessDownloadTask(Task);
        FCurrentTask := nil;
      end else begin
        // 没有任务，休眠一段时间
        Sleep(100);
      end;
    except
      on E: Exception do begin
        WriteLog('下载工作线程异常: ' + E.Message, True);
        FCurrentTask := nil;
      end;
    end;
  end;
end;

procedure TDownloadWorkerThread.ProcessDownloadTask(Task: TMicroDownloadTask);
var
  dwChunkSize: LongWord;
  dwChunkIndex: LongWord;
  pChunkData: Pointer;
  dwBytesRead: LongWord;
  dwStartTime: LongWord;
begin
  if Task = nil then
    Exit;
    
  WriteDebugLog('开始处理下载任务: ' + Task.FileName);
  
  try
    dwStartTime := GetTickCount;
    dwChunkIndex := 0;
    
    while (Task.CurrentPos < Task.FileSize) and not Terminated and FManager.FIsRunning do begin
      // 计算本次传输的数据块大小
      dwChunkSize := Min(Task.ChunkSize, Task.FileSize - Task.CurrentPos);
      
      // 分配数据缓冲区
      GetMem(pChunkData, dwChunkSize);
      try
        // 这里应该从资源管理器或微端服务器读取实际数据
        // 现在先用模拟数据
        FillChar(pChunkData^, dwChunkSize, $AA);
        dwBytesRead := dwChunkSize;
        
        // 发送数据块
        SendDataChunk(Task, pChunkData, dwBytesRead, dwChunkIndex);
        
        // 更新进度
        Task.CurrentPos := Task.CurrentPos + dwBytesRead;
        Task.UpdateProgress(Task.CurrentPos);
        
        // 发送进度更新
        SendProgress(Task);
        
        // 更新统计
        FManager.FTotalUploaded := FManager.FTotalUploaded + dwBytesRead;
        
        Inc(dwChunkIndex);
        
        // 速度控制
        if g_Config.nMaxDownloadSpeed > 0 then begin
          var dwElapsed := GetTickCount - dwStartTime;
          var dwExpectedTime := (Task.CurrentPos - Task.StartPos) * 1000 div g_Config.nMaxDownloadSpeed;
          if dwElapsed < dwExpectedTime then
            Sleep(dwExpectedTime - dwElapsed);
        end;
        
      finally
        FreeMem(pChunkData);
      end;
    end;
    
    // 检查是否完成
    if Task.CurrentPos >= Task.FileSize then begin
      SendComplete(Task);
      WriteDebugLog('下载任务完成: ' + Task.FileName);
    end;
    
  except
    on E: Exception do begin
      WriteLog('处理下载任务时出错: ' + E.Message, True);
      SendError(Task, ERROR_NETWORK_ERROR, E.Message);
    end;
  end;
end;

procedure TDownloadWorkerThread.SendDataChunk(Task: TMicroDownloadTask; pData: Pointer; dwSize: LongWord; dwChunkIndex: LongWord);
var
  DataChunk: TMicroDataChunk;
  sChunkHash: string;
begin
  if (Task = nil) or (Task.Connection = nil) or (pData = nil) or (dwSize = 0) then
    Exit;
    
  // 计算数据块哈希
  sChunkHash := MD5Print(MD5Buffer(pData^, dwSize));
  
  // 填充数据块结构
  FillChar(DataChunk, SizeOf(DataChunk), 0);
  DataChunk.dwRequestId := Task.RequestId;
  DataChunk.dwChunkIndex := dwChunkIndex;
  DataChunk.dwChunkSize := dwSize;
  DataChunk.dwTotalChunks := (Task.FileSize + Task.ChunkSize - 1) div Task.ChunkSize;
  StrPLCopy(DataChunk.sChunkHash, AnsiString(sChunkHash), SizeOf(DataChunk.sChunkHash) - 1);
  DataChunk.btCompress := Task.Compress;
  
  // 这里需要通过客户端管理器发送数据
  // TODO: 需要客户端管理器的引用
  WriteDebugLog('发送数据块: ' + IntToStr(dwChunkIndex) + ', 大小: ' + IntToStr(dwSize));
end;

procedure TDownloadWorkerThread.SendProgress(Task: TMicroDownloadTask);
var
  Progress: TMicroDownloadProgress;
begin
  if (Task = nil) or (Task.Connection = nil) then
    Exit;
    
  FillChar(Progress, SizeOf(Progress), 0);
  Progress.dwRequestId := Task.RequestId;
  Progress.dwDownloadedSize := Task.DownloadedSize;
  Progress.dwTotalSize := Task.FileSize;
  Progress.dwSpeed := Task.Speed;
  Progress.dwETA := Task.GetETA;
  Progress.wProgress := Task.GetProgress;
  
  // 这里需要通过客户端管理器发送进度
  // TODO: 需要客户端管理器的引用
  WriteDebugLog('发送进度: ' + IntToStr(Progress.wProgress div 100) + '%');
end;

procedure TDownloadWorkerThread.SendComplete(Task: TMicroDownloadTask);
begin
  if (Task = nil) or (Task.Connection = nil) then
    Exit;
    
  // 这里需要通过客户端管理器发送完成消息
  // TODO: 需要客户端管理器的引用
  WriteDebugLog('发送完成消息: ' + Task.FileName);
  
  // 触发完成事件
  if Assigned(FManager.FOnComplete) then
    FManager.FOnComplete(Task);
end;

procedure TDownloadWorkerThread.SendError(Task: TMicroDownloadTask; dwErrorCode: LongWord; const sErrorMsg: string);
begin
  if (Task = nil) or (Task.Connection = nil) then
    Exit;
    
  // 这里需要通过客户端管理器发送错误消息
  // TODO: 需要客户端管理器的引用
  WriteLog('下载错误: ' + Task.FileName + ' - ' + sErrorMsg, True);
  
  // 触发错误事件
  if Assigned(FManager.FOnError) then
    FManager.FOnError(Task);
end;

end.
