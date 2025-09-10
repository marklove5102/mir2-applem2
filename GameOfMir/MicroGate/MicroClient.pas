unit MicroClient;

interface

uses
  Windows, SysUtils, Classes, WinSock, SyncObjs, MicroShare;

type
  // 客户端连接管理器
  TMicroClientManager = class
  private
    FListenSocket: TSocket;
    FListenPort: Integer;
    FMaxConnections: Integer;
    FIsRunning: Boolean;
    FAcceptThread: TThread;
    FConnectionList: TList;
    FCriticalSection: TCriticalSection;
    
    // 事件
    FOnConnect: TNotifyEvent;
    FOnDisconnect: TNotifyEvent;
    FOnResourceRequest: TNotifyEvent;
    FOnDataReceived: TNotifyEvent;
    
    procedure AcceptConnections;
    procedure HandleClientConnection(ClientSocket: TSocket; const RemoteAddr: string);
    procedure ProcessClientMessage(Connection: pTMicroConnectionInfo; const Buffer: string);
    procedure SendToClient(Connection: pTMicroConnectionInfo; wMsgType: Word; const Data; dwDataSize: LongWord);
    procedure CleanupConnection(Connection: pTMicroConnectionInfo);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    function Start(nPort: Integer): Boolean;
    procedure Stop;
    procedure DisconnectClient(Connection: pTMicroConnectionInfo);
    procedure DisconnectAll;
    function GetConnectionCount: Integer;
    function GetConnection(nIndex: Integer): pTMicroConnectionInfo;
    
    // 消息发送方法
    procedure SendResourceInfo(Connection: pTMicroConnectionInfo; const ResourceInfo: TMicroResourceInfo);
    procedure SendDataChunk(Connection: pTMicroConnectionInfo; const DataChunk: TMicroDataChunk; const Data: Pointer);
    procedure SendDownloadProgress(Connection: pTMicroConnectionInfo; const Progress: TMicroDownloadProgress);
    procedure SendDownloadComplete(Connection: pTMicroConnectionInfo; dwRequestId: LongWord);
    procedure SendDownloadError(Connection: pTMicroConnectionInfo; dwRequestId: LongWord; dwErrorCode: LongWord; const sErrorMsg: string);
    
    property IsRunning: Boolean read FIsRunning;
    property ListenPort: Integer read FListenPort;
    property MaxConnections: Integer read FMaxConnections write FMaxConnections;
    
    // 事件属性
    property OnConnect: TNotifyEvent read FOnConnect write FOnConnect;
    property OnDisconnect: TNotifyEvent read FOnDisconnect write FOnDisconnect;
    property OnResourceRequest: TNotifyEvent read FOnResourceRequest write FOnResourceRequest;
    property OnDataReceived: TNotifyEvent read FOnDataReceived write FOnDataReceived;
  end;

  // 客户端连接处理线程
  TMicroClientThread = class(TThread)
  private
    FClientSocket: TSocket;
    FRemoteAddr: string;
    FConnection: pTMicroConnectionInfo;
    FManager: TMicroClientManager;
    FReceiveBuffer: string;
    
    procedure ProcessReceiveData;
    procedure HandleResourceRequest(const Request: TMicroResourceRequest);
    procedure HandleVersionCheck(dwRequestId: LongWord);
    procedure HandleDownloadChunk(dwRequestId, dwChunkIndex: LongWord);
    procedure HandleResumeDownload(const Request: TMicroResourceRequest);
    procedure HandleCancelDownload(dwRequestId: LongWord);
    
  protected
    procedure Execute; override;
    
  public
    constructor Create(AManager: TMicroClientManager; AClientSocket: TSocket; const ARemoteAddr: string);
    destructor Destroy; override;
    
    property Connection: pTMicroConnectionInfo read FConnection;
  end;

implementation

uses
  DateUtils;

// TMicroClientManager 实现

constructor TMicroClientManager.Create;
begin
  inherited Create;
  FListenSocket := INVALID_SOCKET;
  FListenPort := 0;
  FMaxConnections := DEFAULT_MAX_CONNECTIONS;
  FIsRunning := False;
  FAcceptThread := nil;
  FConnectionList := TList.Create;
  FCriticalSection := TCriticalSection.Create;
end;

destructor TMicroClientManager.Destroy;
begin
  Stop;
  FCriticalSection.Free;
  FConnectionList.Free;
  inherited Destroy;
end;

function TMicroClientManager.Start(nPort: Integer): Boolean;
var
  WSAData: TWSAData;
  SockAddr: TSockAddrIn;
  nResult: Integer;
begin
  Result := False;
  
  if FIsRunning then
    Exit;
    
  // 初始化 Winsock
  if WSAStartup(MAKEWORD(2, 2), WSAData) <> 0 then begin
    WriteLog('初始化 Winsock 失败', True);
    Exit;
  end;
  
  try
    // 创建监听 Socket
    FListenSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if FListenSocket = INVALID_SOCKET then begin
      WriteLog('创建监听 Socket 失败: ' + IntToStr(WSAGetLastError), True);
      Exit;
    end;
    
    // 设置 Socket 选项
    nResult := 1;
    setsockopt(FListenSocket, SOL_SOCKET, SO_REUSEADDR, @nResult, SizeOf(nResult));
    
    // 绑定端口
    FillChar(SockAddr, SizeOf(SockAddr), 0);
    SockAddr.sin_family := AF_INET;
    SockAddr.sin_addr.s_addr := INADDR_ANY;
    SockAddr.sin_port := htons(nPort);
    
    if bind(FListenSocket, SockAddr, SizeOf(SockAddr)) = SOCKET_ERROR then begin
      WriteLog('绑定端口失败: ' + IntToStr(WSAGetLastError), True);
      closesocket(FListenSocket);
      FListenSocket := INVALID_SOCKET;
      Exit;
    end;
    
    // 开始监听
    if listen(FListenSocket, SOMAXCONN) = SOCKET_ERROR then begin
      WriteLog('开始监听失败: ' + IntToStr(WSAGetLastError), True);
      closesocket(FListenSocket);
      FListenSocket := INVALID_SOCKET;
      Exit;
    end;
    
    FListenPort := nPort;
    FIsRunning := True;
    
    // 创建接受连接线程
    FAcceptThread := TThread.CreateAnonymousThread(AcceptConnections);
    FAcceptThread.Start;
    
    WriteLog('微端网关启动成功，监听端口: ' + IntToStr(nPort));
    Result := True;
    
  except
    on E: Exception do begin
      WriteLog('启动微端网关失败: ' + E.Message, True);
      if FListenSocket <> INVALID_SOCKET then begin
        closesocket(FListenSocket);
        FListenSocket := INVALID_SOCKET;
      end;
    end;
  end;
end;

procedure TMicroClientManager.Stop;
var
  i: Integer;
  Connection: pTMicroConnectionInfo;
begin
  if not FIsRunning then
    Exit;
    
  FIsRunning := False;
  
  // 关闭监听 Socket
  if FListenSocket <> INVALID_SOCKET then begin
    closesocket(FListenSocket);
    FListenSocket := INVALID_SOCKET;
  end;
  
  // 等待接受线程结束
  if FAcceptThread <> nil then begin
    FAcceptThread.Terminate;
    FAcceptThread.WaitFor;
    FAcceptThread.Free;
    FAcceptThread := nil;
  end;
  
  // 断开所有连接
  FCriticalSection.Enter;
  try
    for i := FConnectionList.Count - 1 downto 0 do begin
      Connection := FConnectionList[i];
      if Connection <> nil then
        CleanupConnection(Connection);
    end;
    FConnectionList.Clear;
  finally
    FCriticalSection.Leave;
  end;
  
  // 清理 Winsock
  WSACleanup;
  
  WriteLog('微端网关已停止');
end;

procedure TMicroClientManager.AcceptConnections;
var
  ClientSocket: TSocket;
  ClientAddr: TSockAddrIn;
  nAddrLen: Integer;
  sRemoteAddr: string;
begin
  while FIsRunning do begin
    try
      nAddrLen := SizeOf(ClientAddr);
      ClientSocket := accept(FListenSocket, @ClientAddr, @nAddrLen);
      
      if ClientSocket = INVALID_SOCKET then begin
        if FIsRunning then
          WriteLog('接受连接失败: ' + IntToStr(WSAGetLastError), True);
        Continue;
      end;
      
      // 检查连接数限制
      if GetConnectionCount >= FMaxConnections then begin
        WriteLog('连接数已达上限，拒绝新连接', True);
        closesocket(ClientSocket);
        Continue;
      end;
      
      // 获取远程地址
      sRemoteAddr := inet_ntoa(ClientAddr.sin_addr) + ':' + IntToStr(ntohs(ClientAddr.sin_port));
      
      // 处理客户端连接
      HandleClientConnection(ClientSocket, sRemoteAddr);
      
    except
      on E: Exception do begin
        WriteLog('处理连接时出错: ' + E.Message, True);
      end;
    end;
  end;
end;

procedure TMicroClientManager.HandleClientConnection(ClientSocket: TSocket; const RemoteAddr: string);
var
  ClientThread: TMicroClientThread;
begin
  try
    // 创建客户端处理线程
    ClientThread := TMicroClientThread.Create(Self, ClientSocket, RemoteAddr);
    
    // 添加到连接列表
    FCriticalSection.Enter;
    try
      FConnectionList.Add(ClientThread.Connection);
    finally
      FCriticalSection.Leave;
    end;
    
    // 触发连接事件
    if Assigned(FOnConnect) then
      FOnConnect(ClientThread.Connection);
      
    WriteDebugLog('新客户端连接: ' + RemoteAddr);
    
  except
    on E: Exception do begin
      WriteLog('处理客户端连接失败: ' + E.Message, True);
      closesocket(ClientSocket);
    end;
  end;
end;

procedure TMicroClientManager.ProcessClientMessage(Connection: pTMicroConnectionInfo; const Buffer: string);
var
  Header: TMicroMessageHeader;
  Data: Pointer;
  Request: pTMicroResourceRequest;
begin
  if not ParseMicroMessage(Buffer, Header, Data) then begin
    WriteLog('解析客户端消息失败', True);
    Exit;
  end;
  
  try
    case Header.wMsgType of
      MC_REQUEST_RESOURCE:
        begin
          if Header.dwDataSize = SizeOf(TMicroResourceRequest) then begin
            Request := Data;
            if Assigned(FOnResourceRequest) then
              FOnResourceRequest(Request);
          end;
        end;
      MC_CHECK_VERSION:
        begin
          // 处理版本检查
          WriteDebugLog('收到版本检查请求');
        end;
      MC_DOWNLOAD_CHUNK:
        begin
          // 处理下载块请求
          WriteDebugLog('收到下载块请求');
        end;
      MC_RESUME_DOWNLOAD:
        begin
          // 处理断点续传请求
          WriteDebugLog('收到断点续传请求');
        end;
      MC_CANCEL_DOWNLOAD:
        begin
          // 处理取消下载请求
          WriteDebugLog('收到取消下载请求');
        end;
    end;
    
    // 更新连接统计
    Connection.LastActiveTime := Now;
    Inc(Connection.RequestCount);
    
  except
    on E: Exception do begin
      WriteLog('处理客户端消息时出错: ' + E.Message, True);
    end;
  end;
end;

procedure TMicroClientManager.SendToClient(Connection: pTMicroConnectionInfo; wMsgType: Word; const Data; dwDataSize: LongWord);
var
  sMessage: string;
  nSent: Integer;
begin
  if (Connection = nil) or (Connection.Socket = INVALID_SOCKET) then
    Exit;
    
  try
    sMessage := MakeMicroMessage(wMsgType, Data, dwDataSize);
    nSent := send(Connection.Socket, sMessage[1], Length(sMessage), 0);
    
    if nSent = SOCKET_ERROR then begin
      WriteLog('发送数据到客户端失败: ' + IntToStr(WSAGetLastError), True);
    end else begin
      Connection.SendBytes := Connection.SendBytes + nSent;
    end;
    
  except
    on E: Exception do begin
      WriteLog('发送数据到客户端时出错: ' + E.Message, True);
    end;
  end;
end;

procedure TMicroClientManager.CleanupConnection(Connection: pTMicroConnectionInfo);
begin
  if Connection = nil then
    Exit;
    
  try
    // 关闭 Socket
    if Connection.Socket <> INVALID_SOCKET then begin
      closesocket(Connection.Socket);
      Connection.Socket := INVALID_SOCKET;
    end;
    
    // 从连接列表中移除
    FCriticalSection.Enter;
    try
      FConnectionList.Remove(Connection);
    finally
      FCriticalSection.Leave;
    end;
    
    // 触发断开事件
    if Assigned(FOnDisconnect) then
      FOnDisconnect(Connection);
    
    // 释放内存
    Dispose(Connection);
    
  except
    on E: Exception do begin
      WriteLog('清理连接时出错: ' + E.Message, True);
    end;
  end;
end;

procedure TMicroClientManager.DisconnectClient(Connection: pTMicroConnectionInfo);
begin
  if Connection <> nil then
    CleanupConnection(Connection);
end;

procedure TMicroClientManager.DisconnectAll;
var
  i: Integer;
  Connection: pTMicroConnectionInfo;
begin
  FCriticalSection.Enter;
  try
    for i := FConnectionList.Count - 1 downto 0 do begin
      Connection := FConnectionList[i];
      if Connection <> nil then
        CleanupConnection(Connection);
    end;
    FConnectionList.Clear;
  finally
    FCriticalSection.Leave;
  end;
end;

function TMicroClientManager.GetConnectionCount: Integer;
begin
  FCriticalSection.Enter;
  try
    Result := FConnectionList.Count;
  finally
    FCriticalSection.Leave;
  end;
end;

function TMicroClientManager.GetConnection(nIndex: Integer): pTMicroConnectionInfo;
begin
  Result := nil;
  FCriticalSection.Enter;
  try
    if (nIndex >= 0) and (nIndex < FConnectionList.Count) then
      Result := FConnectionList[nIndex];
  finally
    FCriticalSection.Leave;
  end;
end;

// 消息发送方法实现
procedure TMicroClientManager.SendResourceInfo(Connection: pTMicroConnectionInfo; const ResourceInfo: TMicroResourceInfo);
begin
  SendToClient(Connection, MC_RESOURCE_INFO, ResourceInfo, SizeOf(ResourceInfo));
end;

procedure TMicroClientManager.SendDataChunk(Connection: pTMicroConnectionInfo; const DataChunk: TMicroDataChunk; const Data: Pointer);
var
  sBuffer: string;
begin
  // 组合数据块头和数据
  SetLength(sBuffer, SizeOf(DataChunk) + DataChunk.dwChunkSize);
  Move(DataChunk, sBuffer[1], SizeOf(DataChunk));
  if (Data <> nil) and (DataChunk.dwChunkSize > 0) then
    Move(Data^, sBuffer[1 + SizeOf(DataChunk)], DataChunk.dwChunkSize);
    
  SendToClient(Connection, MC_DATA_CHUNK, sBuffer[1], Length(sBuffer));
end;

procedure TMicroClientManager.SendDownloadProgress(Connection: pTMicroConnectionInfo; const Progress: TMicroDownloadProgress);
begin
  SendToClient(Connection, MC_DOWNLOAD_PROGRESS, Progress, SizeOf(Progress));
end;

procedure TMicroClientManager.SendDownloadComplete(Connection: pTMicroConnectionInfo; dwRequestId: LongWord);
begin
  SendToClient(Connection, MC_DOWNLOAD_COMPLETE, dwRequestId, SizeOf(dwRequestId));
end;

procedure TMicroClientManager.SendDownloadError(Connection: pTMicroConnectionInfo; dwRequestId: LongWord; dwErrorCode: LongWord; const sErrorMsg: string);
var
  ErrorInfo: TMicroErrorInfo;
begin
  FillChar(ErrorInfo, SizeOf(ErrorInfo), 0);
  ErrorInfo.dwRequestId := dwRequestId;
  ErrorInfo.dwErrorCode := dwErrorCode;
  StrPLCopy(ErrorInfo.sErrorMsg, sErrorMsg, SizeOf(ErrorInfo.sErrorMsg) - 1);
  
  SendToClient(Connection, MC_DOWNLOAD_ERROR, ErrorInfo, SizeOf(ErrorInfo));
end;

// TMicroClientThread 实现

constructor TMicroClientThread.Create(AManager: TMicroClientManager; AClientSocket: TSocket; const ARemoteAddr: string);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  
  FManager := AManager;
  FClientSocket := AClientSocket;
  FRemoteAddr := ARemoteAddr;
  FReceiveBuffer := '';
  
  // 创建连接信息
  New(FConnection);
  FillChar(FConnection^, SizeOf(TMicroConnectionInfo), 0);
  FConnection.Socket := AClientSocket;
  FConnection.RemoteAddr := ARemoteAddr;
  FConnection.ConnectTime := Now;
  FConnection.LastActiveTime := Now;
  FConnection.SendBytes := 0;
  FConnection.RecvBytes := 0;
  FConnection.RequestCount := 0;
  FConnection.UserData := Self;
end;

destructor TMicroClientThread.Destroy;
begin
  if FConnection <> nil then begin
    FManager.CleanupConnection(FConnection);
    FConnection := nil;
  end;
  inherited Destroy;
end;

procedure TMicroClientThread.Execute;
var
  Buffer: array[0..4095] of Byte;
  nReceived: Integer;
  sData: string;
begin
  try
    while not Terminated do begin
      // 接收数据
      nReceived := recv(FClientSocket, Buffer, SizeOf(Buffer), 0);
      
      if nReceived = SOCKET_ERROR then begin
        if WSAGetLastError <> WSAEWOULDBLOCK then begin
          WriteLog('接收客户端数据失败: ' + IntToStr(WSAGetLastError), True);
          Break;
        end;
        Sleep(10);
        Continue;
      end;
      
      if nReceived = 0 then begin
        WriteDebugLog('客户端主动断开连接: ' + FRemoteAddr);
        Break;
      end;
      
      // 更新接收字节数
      FConnection.RecvBytes := FConnection.RecvBytes + nReceived;
      
      // 添加到接收缓冲区
      SetLength(sData, nReceived);
      Move(Buffer, sData[1], nReceived);
      FReceiveBuffer := FReceiveBuffer + sData;
      
      // 处理接收到的数据
      ProcessReceiveData;
    end;
    
  except
    on E: Exception do begin
      WriteLog('客户端线程异常: ' + E.Message, True);
    end;
  end;
  
  WriteDebugLog('客户端连接结束: ' + FRemoteAddr);
end;

procedure TMicroClientThread.ProcessReceiveData;
var
  Header: TMicroMessageHeader;
  Data: Pointer;
  nMessageSize: Integer;
  sMessage: string;
begin
  while Length(FReceiveBuffer) >= SizeOf(TMicroMessageHeader) do begin
    // 解析消息头
    Move(FReceiveBuffer[1], Header, SizeOf(Header));
    
    // 验证消息签名
    if Header.dwSignature <> $5243494D then begin
      WriteLog('收到无效的消息签名', True);
      FReceiveBuffer := '';
      Break;
    end;
    
    // 检查消息完整性
    nMessageSize := SizeOf(Header) + Integer(Header.dwDataSize);
    if Length(FReceiveBuffer) < nMessageSize then
      Break; // 等待更多数据
      
    // 提取完整消息
    sMessage := Copy(FReceiveBuffer, 1, nMessageSize);
    Delete(FReceiveBuffer, 1, nMessageSize);
    
    // 处理消息
    FManager.ProcessClientMessage(FConnection, sMessage);
  end;
end;

procedure TMicroClientThread.HandleResourceRequest(const Request: TMicroResourceRequest);
begin
  // 这里会调用资源管理器来处理请求
  WriteDebugLog('处理资源请求: ' + string(Request.sFileName));
end;

procedure TMicroClientThread.HandleVersionCheck(dwRequestId: LongWord);
begin
  // 处理版本检查请求
  WriteDebugLog('处理版本检查请求: ' + IntToStr(dwRequestId));
end;

procedure TMicroClientThread.HandleDownloadChunk(dwRequestId, dwChunkIndex: LongWord);
begin
  // 处理下载块请求
  WriteDebugLog('处理下载块请求: ' + IntToStr(dwRequestId) + ', 块: ' + IntToStr(dwChunkIndex));
end;

procedure TMicroClientThread.HandleResumeDownload(const Request: TMicroResourceRequest);
begin
  // 处理断点续传请求
  WriteDebugLog('处理断点续传请求: ' + string(Request.sFileName));
end;

procedure TMicroClientThread.HandleCancelDownload(dwRequestId: LongWord);
begin
  // 处理取消下载请求
  WriteDebugLog('处理取消下载请求: ' + IntToStr(dwRequestId));
end;

end.
