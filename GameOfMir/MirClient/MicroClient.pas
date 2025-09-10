unit MicroClient;

interface

uses
  Windows, SysUtils, Classes, WinSock, SyncObjs, Forms, Controls, 
  MicroShare, MicroDownloadForm;

type
  // 客户端微端管理器
  TMicroClientManager = class
  private
    FMicroSocket: TSocket;
    FMicroAddr: string;
    FMicroPort: Integer;
    FIsConnected: Boolean;
    FReceiveThread: TThread;
    FReceiveBuffer: string;
    FCriticalSection: TCriticalSection;
    FDownloadTasks: TList;
    FResourceList: TStringList;
    FDownloadForm: TFrmMicroDownload;
    
    // 事件
    FOnConnected: TNotifyEvent;
    FOnDisconnected: TNotifyEvent;
    FOnResourceReceived: TNotifyEvent;
    FOnDownloadProgress: TNotifyEvent;
    FOnDownloadComplete: TNotifyEvent;
    FOnDownloadError: TNotifyEvent;
    
    procedure ConnectToMicroGate;
    procedure ReceiveFromMicroGate;
    procedure ProcessMicroMessage(const Buffer: string);
    procedure SendToMicroGate(wMsgType: Word; const Data; dwDataSize: LongWord);
    procedure HandleResourceInfo(const ResourceInfo: TMicroResourceInfo);
    procedure HandleDataChunk(const DataChunk: TMicroDataChunk; pData: Pointer);
    procedure HandleDownloadProgress(const Progress: TMicroDownloadProgress);
    procedure HandleDownloadComplete(dwRequestId: LongWord);
    procedure HandleDownloadError(const ErrorInfo: TMicroErrorInfo);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    // 连接管理
    function Connect(const sAddr: string; nPort: Integer): Boolean;
    procedure Disconnect;
    function IsConnected: Boolean;
    
    // 资源管理
    function CheckResource(const sFileName: string; const sLocalPath: string = ''): Boolean;
    function RequestResource(const sFileName: string; const sFileHash: string = ''; dwFileSize: LongWord = 0): LongWord;
    function CancelDownload(dwRequestId: LongWord): Boolean;
    procedure CancelAllDownloads;
    
    // 资源验证
    function ValidateFile(const sFilePath: string; const sExpectedHash: string): Boolean;
    function CalculateFileHash(const sFilePath: string): string;
    function GetFileSize(const sFilePath: string): LongWord;
    
    // 界面管理
    procedure ShowDownloadDialog;
    procedure HideDownloadDialog;
    function IsDownloadDialogVisible: Boolean;
    
    property MicroAddr: string read FMicroAddr;
    property MicroPort: Integer read FMicroPort;
    
    // 事件属性
    property OnConnected: TNotifyEvent read FOnConnected write FOnConnected;
    property OnDisconnected: TNotifyEvent read FOnDisconnected write FOnDisconnected;
    property OnResourceReceived: TNotifyEvent read FOnResourceReceived write FOnResourceReceived;
    property OnDownloadProgress: TNotifyEvent read FOnDownloadProgress write FOnDownloadProgress;
    property OnDownloadComplete: TNotifyEvent read FOnDownloadComplete write FOnDownloadComplete;
    property OnDownloadError: TNotifyEvent read FOnDownloadError write FOnDownloadError;
  end;

  // 客户端下载任务
  TClientDownloadTask = class
  private
    FRequestId: LongWord;
    FFileName: string;
    FLocalPath: string;
    FFileSize: LongWord;
    FFileHash: string;
    FDownloadedSize: LongWord;
    FProgress: Word;
    FSpeed: LongWord;
    FETA: LongWord;
    FStartTime: TDateTime;
    FLastUpdateTime: TDateTime;
    FIsCompleted: Boolean;
    FIsCancelled: Boolean;
    FErrorMsg: string;
    FFileStream: TFileStream;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure StartDownload(const sLocalPath: string);
    procedure WriteData(pData: Pointer; dwSize: LongWord);
    procedure UpdateProgress(dwDownloadedSize: LongWord; dwSpeed: LongWord; dwETA: LongWord);
    procedure CompleteDownload;
    procedure CancelDownload;
    procedure SetError(const sErrorMsg: string);
    
    property RequestId: LongWord read FRequestId write FRequestId;
    property FileName: string read FFileName write FFileName;
    property LocalPath: string read FLocalPath write FLocalPath;
    property FileSize: LongWord read FFileSize write FFileSize;
    property FileHash: string read FFileHash write FFileHash;
    property DownloadedSize: LongWord read FDownloadedSize;
    property Progress: Word read FProgress;
    property Speed: LongWord read FSpeed;
    property ETA: LongWord read FETA;
    property StartTime: TDateTime read FStartTime;
    property IsCompleted: Boolean read FIsCompleted;
    property IsCancelled: Boolean read FIsCancelled;
    property ErrorMsg: string read FErrorMsg;
  end;

// 全局微端管理器实例
var
  g_MicroClientManager: TMicroClientManager;

// 工具函数
function InitializeMicroClient: Boolean;
procedure FinalizeMicroClient;
function CheckAndDownloadResource(const sFileName: string; const sLocalPath: string = ''): Boolean;

implementation

uses
  DateUtils, MD5, Grobal2;

// TMicroClientManager 实现

constructor TMicroClientManager.Create;
begin
  inherited Create;
  FMicroSocket := INVALID_SOCKET;
  FMicroAddr := '';
  FMicroPort := 0;
  FIsConnected := False;
  FReceiveThread := nil;
  FReceiveBuffer := '';
  FCriticalSection := TCriticalSection.Create;
  FDownloadTasks := TList.Create;
  FResourceList := TStringList.Create;
  FDownloadForm := nil;
end;

destructor TMicroClientManager.Destroy;
begin
  Disconnect;
  
  if FDownloadForm <> nil then begin
    FDownloadForm.Free;
    FDownloadForm := nil;
  end;
  
  FCriticalSection.Free;
  FDownloadTasks.Free;
  FResourceList.Free;
  inherited Destroy;
end;

function TMicroClientManager.Connect(const sAddr: string; nPort: Integer): Boolean;
var
  WSAData: TWSAData;
  SockAddr: TSockAddrIn;
  HostEnt: PHostEnt;
begin
  Result := False;
  
  if FIsConnected then
    Exit;
    
  FMicroAddr := sAddr;
  FMicroPort := nPort;
  
  // 初始化 Winsock
  if WSAStartup(MAKEWORD(2, 2), WSAData) <> 0 then begin
    DebugOutStr('初始化 Winsock 失败');
    Exit;
  end;
  
  try
    // 创建 Socket
    FMicroSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if FMicroSocket = INVALID_SOCKET then begin
      DebugOutStr('创建微端连接 Socket 失败: ' + IntToStr(WSAGetLastError));
      Exit;
    end;
    
    // 解析服务器地址
    FillChar(SockAddr, SizeOf(SockAddr), 0);
    SockAddr.sin_family := AF_INET;
    SockAddr.sin_port := htons(nPort);
    
    SockAddr.sin_addr.s_addr := inet_addr(PAnsiChar(AnsiString(sAddr)));
    if SockAddr.sin_addr.s_addr = INADDR_NONE then begin
      HostEnt := gethostbyname(PAnsiChar(AnsiString(sAddr)));
      if HostEnt = nil then begin
        DebugOutStr('解析微端网关地址失败: ' + sAddr);
        Exit;
      end;
      SockAddr.sin_addr.s_addr := PLongint(HostEnt^.h_addr_list^)^;
    end;
    
    // 连接微端网关
    if connect(FMicroSocket, SockAddr, SizeOf(SockAddr)) = SOCKET_ERROR then begin
      DebugOutStr('连接微端网关失败: ' + IntToStr(WSAGetLastError));
      closesocket(FMicroSocket);
      FMicroSocket := INVALID_SOCKET;
      Exit;
    end;
    
    FIsConnected := True;
    DebugOutStr('成功连接到微端网关: ' + sAddr + ':' + IntToStr(nPort));
    
    // 创建接收线程
    FReceiveThread := TThread.CreateAnonymousThread(ReceiveFromMicroGate);
    FReceiveThread.Start;
    
    // 触发连接事件
    if Assigned(FOnConnected) then
      FOnConnected(Self);
    
    Result := True;
    
  except
    on E: Exception do begin
      DebugOutStr('连接微端网关时出错: ' + E.Message);
      if FMicroSocket <> INVALID_SOCKET then begin
        closesocket(FMicroSocket);
        FMicroSocket := INVALID_SOCKET;
      end;
    end;
  end;
end;

procedure TMicroClientManager.Disconnect;
var
  i: Integer;
  Task: TClientDownloadTask;
begin
  if not FIsConnected then
    Exit;
    
  FIsConnected := False;
  
  // 终止接收线程
  if FReceiveThread <> nil then begin
    FReceiveThread.Terminate;
    FReceiveThread.WaitFor;
    FReceiveThread.Free;
    FReceiveThread := nil;
  end;
  
  // 关闭 Socket
  if FMicroSocket <> INVALID_SOCKET then begin
    closesocket(FMicroSocket);
    FMicroSocket := INVALID_SOCKET;
  end;
  
  // 取消所有下载任务
  FCriticalSection.Enter;
  try
    for i := 0 to FDownloadTasks.Count - 1 do begin
      Task := TClientDownloadTask(FDownloadTasks[i]);
      Task.CancelDownload;
      Task.Free;
    end;
    FDownloadTasks.Clear;
  finally
    FCriticalSection.Leave;
  end;
  
  // 清理 Winsock
  WSACleanup;
  
  DebugOutStr('与微端网关断开连接');
  
  // 触发断开事件
  if Assigned(FOnDisconnected) then
    FOnDisconnected(Self);
end;

function TMicroClientManager.IsConnected: Boolean;
begin
  Result := FIsConnected;
end;

procedure TMicroClientManager.ReceiveFromMicroGate;
var
  Buffer: array[0..4095] of Byte;
  nReceived: Integer;
  sData: string;
begin
  try
    while FIsConnected and (FMicroSocket <> INVALID_SOCKET) do begin
      // 接收数据
      nReceived := recv(FMicroSocket, Buffer, SizeOf(Buffer), 0);
      
      if nReceived = SOCKET_ERROR then begin
        if WSAGetLastError <> WSAEWOULDBLOCK then begin
          DebugOutStr('接收微端网关数据失败: ' + IntToStr(WSAGetLastError));
          Break;
        end;
        Sleep(10);
        Continue;
      end;
      
      if nReceived = 0 then begin
        DebugOutStr('微端网关主动断开连接');
        Break;
      end;
      
      // 添加到接收缓冲区
      SetLength(sData, nReceived);
      Move(Buffer, sData[1], nReceived);
      
      FCriticalSection.Enter;
      try
        FReceiveBuffer := FReceiveBuffer + sData;
      finally
        FCriticalSection.Leave;
      end;
      
      // 处理接收到的数据
      ProcessMicroMessage(FReceiveBuffer);
    end;
    
  except
    on E: Exception do begin
      DebugOutStr('接收微端网关数据时出错: ' + E.Message);
    end;
  end;
  
  // 连接断开
  FIsConnected := False;
  if FMicroSocket <> INVALID_SOCKET then begin
    closesocket(FMicroSocket);
    FMicroSocket := INVALID_SOCKET;
  end;
  
  // 触发断开事件
  if Assigned(FOnDisconnected) then
    FOnDisconnected(Self);
end;

procedure TMicroClientManager.ProcessMicroMessage(const Buffer: string);
var
  Header: TMicroMessageHeader;
  Data: Pointer;
  nMessageSize: Integer;
  sMessage: string;
  sProcessBuffer: string;
begin
  FCriticalSection.Enter;
  try
    sProcessBuffer := Buffer;
  finally
    FCriticalSection.Leave;
  end;
  
  while Length(sProcessBuffer) >= SizeOf(TMicroMessageHeader) do begin
    // 解析消息头
    Move(sProcessBuffer[1], Header, SizeOf(Header));
    
    // 验证消息签名
    if Header.dwSignature <> $5243494D then begin
      DebugOutStr('收到无效的微端消息签名');
      FCriticalSection.Enter;
      try
        FReceiveBuffer := '';
      finally
        FCriticalSection.Leave;
      end;
      Break;
    end;
    
    // 检查消息完整性
    nMessageSize := SizeOf(Header) + Integer(Header.dwDataSize);
    if Length(sProcessBuffer) < nMessageSize then
      Break; // 等待更多数据
      
    // 提取完整消息
    sMessage := Copy(sProcessBuffer, 1, nMessageSize);
    Delete(sProcessBuffer, 1, nMessageSize);
    
    // 更新缓冲区
    FCriticalSection.Enter;
    try
      FReceiveBuffer := sProcessBuffer;
    finally
      FCriticalSection.Leave;
    end;
    
    // 解析消息数据
    if not ParseMicroMessage(sMessage, Header, Data) then begin
      DebugOutStr('解析微端消息失败');
      Continue;
    end;
    
    // 处理不同类型的消息
    try
      case Header.wMsgType of
        MC_RESOURCE_INFO:
          begin
            if Header.dwDataSize = SizeOf(TMicroResourceInfo) then
              HandleResourceInfo(pTMicroResourceInfo(Data)^);
          end;
        MC_DATA_CHUNK:
          begin
            if Header.dwDataSize >= SizeOf(TMicroDataChunk) then begin
              var pChunk := pTMicroDataChunk(Data);
              var pChunkData := Pointer(Integer(Data) + SizeOf(TMicroDataChunk));
              HandleDataChunk(pChunk^, pChunkData);
            end;
          end;
        MC_DOWNLOAD_PROGRESS:
          begin
            if Header.dwDataSize = SizeOf(TMicroDownloadProgress) then
              HandleDownloadProgress(pTMicroDownloadProgress(Data)^);
          end;
        MC_DOWNLOAD_COMPLETE:
          begin
            if Header.dwDataSize = SizeOf(LongWord) then
              HandleDownloadComplete(pLongWord(Data)^);
          end;
        MC_DOWNLOAD_ERROR:
          begin
            if Header.dwDataSize = SizeOf(TMicroErrorInfo) then
              HandleDownloadError(pTMicroErrorInfo(Data)^);
          end;
      end;
    except
      on E: Exception do begin
        DebugOutStr('处理微端消息时出错: ' + E.Message);
      end;
    end;
  end;
end;

procedure TMicroClientManager.SendToMicroGate(wMsgType: Word; const Data; dwDataSize: LongWord);
var
  sMessage: string;
  nSent: Integer;
begin
  if not FIsConnected or (FMicroSocket = INVALID_SOCKET) then
    Exit;
    
  try
    sMessage := MakeMicroMessage(wMsgType, Data, dwDataSize);
    nSent := send(FMicroSocket, sMessage[1], Length(sMessage), 0);
    
    if nSent = SOCKET_ERROR then begin
      DebugOutStr('发送数据到微端网关失败: ' + IntToStr(WSAGetLastError));
      // 连接可能已断开
      FIsConnected := False;
    end;
    
  except
    on E: Exception do begin
      DebugOutStr('发送数据到微端网关时出错: ' + E.Message);
    end;
  end;
end;

function TMicroClientManager.CheckResource(const sFileName: string; const sLocalPath: string): Boolean;
var
  sFullPath: string;
  sFileHash: string;
  dwFileSize: LongWord;
begin
  Result := True;
  
  // 确定本地文件路径
  if sLocalPath <> '' then
    sFullPath := sLocalPath
  else
    sFullPath := ExtractFilePath(ParamStr(0)) + sFileName;
    
  // 检查文件是否存在
  if not FileExists(sFullPath) then begin
    DebugOutStr('资源文件不存在: ' + sFullPath);
    Result := False;
    Exit;
  end;
  
  // 检查文件大小和哈希（如果有预期值）
  dwFileSize := GetFileSize(sFullPath);
  sFileHash := CalculateFileHash(sFullPath);
  
  // 这里可以添加更多的验证逻辑
  // 比如与服务器上的文件信息进行比较
  
  DebugOutStr('资源文件检查通过: ' + sFileName + ', 大小: ' + IntToStr(dwFileSize) + ', 哈希: ' + sFileHash);
end;

function TMicroClientManager.RequestResource(const sFileName: string; const sFileHash: string; dwFileSize: LongWord): LongWord;
var
  Request: TMicroResourceRequest;
  Task: TClientDownloadTask;
begin
  Result := 0;
  
  if not FIsConnected then begin
    DebugOutStr('未连接到微端网关，无法请求资源');
    Exit;
  end;
  
  // 创建下载任务
  Task := TClientDownloadTask.Create;
  Task.RequestId := GenerateRequestId;
  Task.FileName := sFileName;
  Task.FileHash := sFileHash;
  Task.FileSize := dwFileSize;
  
  FCriticalSection.Enter;
  try
    FDownloadTasks.Add(Task);
  finally
    FCriticalSection.Leave;
  end;
  
  // 构建请求
  FillChar(Request, SizeOf(Request), 0);
  Request.dwRequestId := Task.RequestId;
  StrPLCopy(Request.sFileName, AnsiString(sFileName), SizeOf(Request.sFileName) - 1);
  Request.dwFileSize := dwFileSize;
  StrPLCopy(Request.sFileHash, AnsiString(sFileHash), SizeOf(Request.sFileHash) - 1);
  Request.dwStartPos := 0;
  Request.dwChunkSize := 64 * 1024; // 64KB
  Request.btPriority := 128; // 中等优先级
  Request.btCompress := COMPRESS_ZLIB;
  
  // 发送请求
  SendToMicroGate(MC_REQUEST_RESOURCE, Request, SizeOf(Request));
  
  Result := Task.RequestId;
  DebugOutStr('请求资源: ' + sFileName + ', 请求ID: ' + IntToStr(Result));
end;

function TMicroClientManager.CancelDownload(dwRequestId: LongWord): Boolean;
var
  i: Integer;
  Task: TClientDownloadTask;
begin
  Result := False;
  
  FCriticalSection.Enter;
  try
    for i := FDownloadTasks.Count - 1 downto 0 do begin
      Task := TClientDownloadTask(FDownloadTasks[i]);
      if Task.RequestId = dwRequestId then begin
        Task.CancelDownload;
        FDownloadTasks.Delete(i);
        Task.Free;
        Result := True;
        Break;
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
  
  if Result then begin
    // 发送取消请求到服务器
    SendToMicroGate(MC_CANCEL_DOWNLOAD, dwRequestId, SizeOf(dwRequestId));
    DebugOutStr('取消下载: ' + IntToStr(dwRequestId));
  end;
end;

procedure TMicroClientManager.CancelAllDownloads;
var
  i: Integer;
  Task: TClientDownloadTask;
begin
  FCriticalSection.Enter;
  try
    for i := 0 to FDownloadTasks.Count - 1 do begin
      Task := TClientDownloadTask(FDownloadTasks[i]);
      Task.CancelDownload;
      Task.Free;
    end;
    FDownloadTasks.Clear;
  finally
    FCriticalSection.Leave;
  end;
  
  DebugOutStr('取消所有下载任务');
end;

function TMicroClientManager.ValidateFile(const sFilePath: string; const sExpectedHash: string): Boolean;
var
  sActualHash: string;
begin
  Result := False;
  
  if not FileExists(sFilePath) then
    Exit;
    
  if sExpectedHash = '' then begin
    Result := True; // 没有期望哈希，只检查文件存在
    Exit;
  end;
  
  sActualHash := CalculateFileHash(sFilePath);
  Result := (sActualHash = sExpectedHash);
  
  if not Result then
    DebugOutStr('文件哈希验证失败: ' + sFilePath + ', 期望: ' + sExpectedHash + ', 实际: ' + sActualHash);
end;

function TMicroClientManager.CalculateFileHash(const sFilePath: string): string;
var
  FileStream: TFileStream;
  MD5Context: TMD5Context;
  MD5Digest: TMD5Digest;
  Buffer: array[0..8191] of Byte;
  BytesRead: Integer;
begin
  Result := '';
  
  try
    FileStream := TFileStream.Create(sFilePath, fmOpenRead or fmShareDenyWrite);
    try
      MD5Init(MD5Context);
      
      repeat
        BytesRead := FileStream.Read(Buffer, SizeOf(Buffer));
        if BytesRead > 0 then
          MD5Update(MD5Context, Buffer, BytesRead);
      until BytesRead = 0;
      
      MD5Final(MD5Context, MD5Digest);
      Result := MD5Print(MD5Digest);
      
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do begin
      DebugOutStr('计算文件哈希失败: ' + sFilePath + ' - ' + E.Message);
    end;
  end;
end;

function TMicroClientManager.GetFileSize(const sFilePath: string): LongWord;
var
  SearchRec: TSearchRec;
begin
  Result := 0;
  
  if FindFirst(sFilePath, faAnyFile, SearchRec) = 0 then begin
    Result := SearchRec.Size;
    FindClose(SearchRec);
  end;
end;

procedure TMicroClientManager.ShowDownloadDialog;
begin
  if FDownloadForm = nil then
    FDownloadForm := TFrmMicroDownload.Create(nil);
    
  FDownloadForm.SetMicroManager(Self);
  FDownloadForm.Show;
end;

procedure TMicroClientManager.HideDownloadDialog;
begin
  if FDownloadForm <> nil then
    FDownloadForm.Hide;
end;

function TMicroClientManager.IsDownloadDialogVisible: Boolean;
begin
  Result := (FDownloadForm <> nil) and FDownloadForm.Visible;
end;

// 消息处理方法
procedure TMicroClientManager.HandleResourceInfo(const ResourceInfo: TMicroResourceInfo);
var
  Task: TClientDownloadTask;
  i: Integer;
  sLocalPath: string;
begin
  // 查找对应的下载任务
  Task := nil;
  FCriticalSection.Enter;
  try
    for i := 0 to FDownloadTasks.Count - 1 do begin
      Task := TClientDownloadTask(FDownloadTasks[i]);
      if Task.RequestId = ResourceInfo.dwRequestId then
        Break;
      Task := nil;
    end;
  finally
    FCriticalSection.Leave;
  end;
  
  if Task = nil then begin
    DebugOutStr('收到未知请求的资源信息: ' + IntToStr(ResourceInfo.dwRequestId));
    Exit;
  end;
  
  // 更新任务信息
  Task.FileSize := ResourceInfo.dwFileSize;
  Task.FileHash := string(ResourceInfo.sFileHash);
  
  // 确定本地保存路径
  sLocalPath := ExtractFilePath(ParamStr(0)) + string(ResourceInfo.sFileName);
  Task.StartDownload(sLocalPath);
  
  DebugOutStr('开始下载资源: ' + string(ResourceInfo.sFileName) + ', 大小: ' + IntToStr(ResourceInfo.dwFileSize));
  
  // 触发事件
  if Assigned(FOnResourceReceived) then
    FOnResourceReceived(Task);
end;

procedure TMicroClientManager.HandleDataChunk(const DataChunk: TMicroDataChunk; pData: Pointer);
var
  Task: TClientDownloadTask;
  i: Integer;
begin
  // 查找对应的下载任务
  Task := nil;
  FCriticalSection.Enter;
  try
    for i := 0 to FDownloadTasks.Count - 1 do begin
      Task := TClientDownloadTask(FDownloadTasks[i]);
      if Task.RequestId = DataChunk.dwRequestId then
        Break;
      Task := nil;
    end;
  finally
    FCriticalSection.Leave;
  end;
  
  if Task = nil then begin
    DebugOutStr('收到未知请求的数据块: ' + IntToStr(DataChunk.dwRequestId));
    Exit;
  end;
  
  // 写入数据
  if (pData <> nil) and (DataChunk.dwChunkSize > 0) then begin
    Task.WriteData(pData, DataChunk.dwChunkSize);
  end;
  
  DebugOutStr('接收数据块: ' + IntToStr(DataChunk.dwChunkIndex) + '/' + IntToStr(DataChunk.dwTotalChunks) + 
             ', 大小: ' + IntToStr(DataChunk.dwChunkSize));
end;

procedure TMicroClientManager.HandleDownloadProgress(const Progress: TMicroDownloadProgress);
var
  Task: TClientDownloadTask;
  i: Integer;
begin
  // 查找对应的下载任务
  Task := nil;
  FCriticalSection.Enter;
  try
    for i := 0 to FDownloadTasks.Count - 1 do begin
      Task := TClientDownloadTask(FDownloadTasks[i]);
      if Task.RequestId = Progress.dwRequestId then
        Break;
      Task := nil;
    end;
  finally
    FCriticalSection.Leave;
  end;
  
  if Task = nil then
    Exit;
    
  // 更新进度
  Task.UpdateProgress(Progress.dwDownloadedSize, Progress.dwSpeed, Progress.dwETA);
  
  // 触发事件
  if Assigned(FOnDownloadProgress) then
    FOnDownloadProgress(Task);
end;

procedure TMicroClientManager.HandleDownloadComplete(dwRequestId: LongWord);
var
  Task: TClientDownloadTask;
  i: Integer;
begin
  // 查找对应的下载任务
  Task := nil;
  FCriticalSection.Enter;
  try
    for i := 0 to FDownloadTasks.Count - 1 do begin
      Task := TClientDownloadTask(FDownloadTasks[i]);
      if Task.RequestId = dwRequestId then begin
        FDownloadTasks.Delete(i);
        Break;
      end;
      Task := nil;
    end;
  finally
    FCriticalSection.Leave;
  end;
  
  if Task = nil then
    Exit;
    
  try
    Task.CompleteDownload;
    DebugOutStr('下载完成: ' + Task.FileName);
    
    // 触发事件
    if Assigned(FOnDownloadComplete) then
      FOnDownloadComplete(Task);
      
  finally
    Task.Free;
  end;
end;

procedure TMicroClientManager.HandleDownloadError(const ErrorInfo: TMicroErrorInfo);
var
  Task: TClientDownloadTask;
  i: Integer;
begin
  // 查找对应的下载任务
  Task := nil;
  FCriticalSection.Enter;
  try
    for i := 0 to FDownloadTasks.Count - 1 do begin
      Task := TClientDownloadTask(FDownloadTasks[i]);
      if Task.RequestId = ErrorInfo.dwRequestId then begin
        FDownloadTasks.Delete(i);
        Break;
      end;
      Task := nil;
    end;
  finally
    FCriticalSection.Leave;
  end;
  
  if Task = nil then
    Exit;
    
  try
    Task.SetError(string(ErrorInfo.sErrorMsg));
    DebugOutStr('下载错误: ' + Task.FileName + ' - ' + string(ErrorInfo.sErrorMsg));
    
    // 触发事件
    if Assigned(FOnDownloadError) then
      FOnDownloadError(Task);
      
  finally
    Task.Free;
  end;
end;

// TClientDownloadTask 实现

constructor TClientDownloadTask.Create;
begin
  inherited Create;
  FRequestId := 0;
  FFileName := '';
  FLocalPath := '';
  FFileSize := 0;
  FFileHash := '';
  FDownloadedSize := 0;
  FProgress := 0;
  FSpeed := 0;
  FETA := 0;
  FStartTime := Now;
  FLastUpdateTime := Now;
  FIsCompleted := False;
  FIsCancelled := False;
  FErrorMsg := '';
  FFileStream := nil;
end;

destructor TClientDownloadTask.Destroy;
begin
  if FFileStream <> nil then begin
    FFileStream.Free;
    FFileStream := nil;
  end;
  inherited Destroy;
end;

procedure TClientDownloadTask.StartDownload(const sLocalPath: string);
begin
  FLocalPath := sLocalPath;
  FStartTime := Now;
  FLastUpdateTime := Now;
  
  try
    // 创建目录
    ForceDirectories(ExtractFilePath(sLocalPath));
    
    // 创建文件流
    FFileStream := TFileStream.Create(sLocalPath, fmCreate);
    
    DebugOutStr('开始下载到: ' + sLocalPath);
  except
    on E: Exception do begin
      SetError('创建本地文件失败: ' + E.Message);
    end;
  end;
end;

procedure TClientDownloadTask.WriteData(pData: Pointer; dwSize: LongWord);
begin
  if (FFileStream = nil) or (pData = nil) or (dwSize = 0) then
    Exit;
    
  try
    FFileStream.Write(pData^, dwSize);
    FDownloadedSize := FDownloadedSize + dwSize;
    
    // 更新进度
    if FFileSize > 0 then
      FProgress := (FDownloadedSize * 10000) div FFileSize;
      
  except
    on E: Exception do begin
      SetError('写入文件数据失败: ' + E.Message);
    end;
  end;
end;

procedure TClientDownloadTask.UpdateProgress(dwDownloadedSize: LongWord; dwSpeed: LongWord; dwETA: LongWord);
begin
  FDownloadedSize := dwDownloadedSize;
  FSpeed := dwSpeed;
  FETA := dwETA;
  FLastUpdateTime := Now;
  
  if FFileSize > 0 then
    FProgress := (FDownloadedSize * 10000) div FFileSize;
end;

procedure TClientDownloadTask.CompleteDownload;
begin
  if FFileStream <> nil then begin
    FFileStream.Free;
    FFileStream := nil;
  end;
  
  FIsCompleted := True;
  FProgress := 10000; // 100%
  
  // 验证文件哈希
  if (FFileHash <> '') and (FLocalPath <> '') then begin
    var sActualHash := g_MicroClientManager.CalculateFileHash(FLocalPath);
    if sActualHash <> FFileHash then begin
      SetError('文件哈希验证失败');
      Exit;
    end;
  end;
  
  DebugOutStr('文件下载并验证完成: ' + FFileName);
end;

procedure TClientDownloadTask.CancelDownload;
begin
  FIsCancelled := True;
  
  if FFileStream <> nil then begin
    FFileStream.Free;
    FFileStream := nil;
  end;
  
  // 删除未完成的文件
  if (FLocalPath <> '') and FileExists(FLocalPath) and not FIsCompleted then begin
    try
      DeleteFile(FLocalPath);
    except
      // 忽略删除错误
    end;
  end;
end;

procedure TClientDownloadTask.SetError(const sErrorMsg: string);
begin
  FErrorMsg := sErrorMsg;
  
  if FFileStream <> nil then begin
    FFileStream.Free;
    FFileStream := nil;
  end;
  
  // 删除错误的文件
  if (FLocalPath <> '') and FileExists(FLocalPath) then begin
    try
      DeleteFile(FLocalPath);
    except
      // 忽略删除错误
    end;
  end;
end;

// 全局函数实现

function InitializeMicroClient: Boolean;
begin
  Result := False;
  
  if g_MicroClientManager <> nil then begin
    Result := True;
    Exit;
  end;
  
  try
    g_MicroClientManager := TMicroClientManager.Create;
    Result := True;
    DebugOutStr('微端客户端管理器初始化成功');
  except
    on E: Exception do begin
      DebugOutStr('初始化微端客户端管理器失败: ' + E.Message);
    end;
  end;
end;

procedure FinalizeMicroClient;
begin
  if g_MicroClientManager <> nil then begin
    g_MicroClientManager.Free;
    g_MicroClientManager := nil;
    DebugOutStr('微端客户端管理器已关闭');
  end;
end;

function CheckAndDownloadResource(const sFileName: string; const sLocalPath: string): Boolean;
var
  sFullPath: string;
  dwRequestId: LongWord;
begin
  Result := False;
  
  if g_MicroClientManager = nil then begin
    DebugOutStr('微端客户端管理器未初始化');
    Exit;
  end;
  
  // 确定本地文件路径
  if sLocalPath <> '' then
    sFullPath := sLocalPath
  else
    sFullPath := ExtractFilePath(ParamStr(0)) + sFileName;
    
  // 检查文件是否已存在且有效
  if g_MicroClientManager.CheckResource(sFileName, sFullPath) then begin
    Result := True;
    Exit;
  end;
  
  // 连接到微端网关（如果尚未连接）
  if not g_MicroClientManager.IsConnected then begin
    if not g_MicroClientManager.Connect('127.0.0.1', 7200) then begin
      DebugOutStr('连接微端网关失败');
      Exit;
    end;
  end;
  
  // 请求下载资源
  dwRequestId := g_MicroClientManager.RequestResource(sFileName);
  if dwRequestId > 0 then begin
    DebugOutStr('已请求下载资源: ' + sFileName + ', 请求ID: ' + IntToStr(dwRequestId));
    // 这里可以显示下载对话框
    g_MicroClientManager.ShowDownloadDialog;
    Result := True;
  end;
end;

initialization
  g_MicroClientManager := nil;

finalization
  FinalizeMicroClient;

end.
