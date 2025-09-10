unit MicroServer;

interface

uses
  Windows, SysUtils, Classes, WinSock, SyncObjs, MicroShare;

type
  // 微端服务器连接管理器
  TMicroServerManager = class
  private
    FServerSocket: TSocket;
    FServerAddr: string;
    FServerPort: Integer;
    FIsConnected: Boolean;
    FConnectThread: TThread;
    FReceiveThread: TThread;
    FReceiveBuffer: string;
    FCriticalSection: TCriticalSection;
    FReconnectTimer: TTimer;
    FLastHeartbeat: TDateTime;
    
    // 事件
    FOnConnected: TNotifyEvent;
    FOnDisconnected: TNotifyEvent;
    FOnResourceFound: TNotifyEvent;
    FOnFileData: TNotifyEvent;
    FOnResourceNotFound: TNotifyEvent;
    
    procedure ConnectToServer;
    procedure ReceiveFromServer;
    procedure ProcessServerMessage(const Buffer: string);
    procedure SendToServer(wMsgType: Word; const Data; dwDataSize: LongWord);
    procedure HandleHeartbeat;
    procedure OnReconnectTimer(Sender: TObject);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    function Connect(const sAddr: string; nPort: Integer): Boolean;
    procedure Disconnect;
    procedure Reconnect;
    
    // 向微端服务器发送请求
    procedure QueryResource(const sFileName: string; const sFileHash: string);
    procedure GetFileData(const sFileName: string; dwStartPos, dwSize: LongWord);
    procedure CheckFileHash(const sFileName: string);
    procedure UpdateStats(const sFileName: string; dwDownloadSize: LongWord);
    
    property IsConnected: Boolean read FIsConnected;
    property ServerAddr: string read FServerAddr;
    property ServerPort: Integer read FServerPort;
    
    // 事件属性
    property OnConnected: TNotifyEvent read FOnConnected write FOnConnected;
    property OnDisconnected: TNotifyEvent read FOnDisconnected write FOnDisconnected;
    property OnResourceFound: TNotifyEvent read FOnResourceFound write FOnResourceFound;
    property OnFileData: TNotifyEvent read FOnFileData write FOnFileData;
    property OnResourceNotFound: TNotifyEvent read FOnResourceNotFound write FOnResourceNotFound;
  end;

  // 资源查询结果
  TMicroResourceResult = record
    sFileName: string;
    dwFileSize: LongWord;
    sFileHash: string;
    dwVersion: LongWord;
    bFound: Boolean;
    sErrorMsg: string;
  end;
  pTMicroResourceResult = ^TMicroResourceResult;

  // 文件数据结果
  TMicroFileDataResult = record
    sFileName: string;
    dwStartPos: LongWord;
    dwDataSize: LongWord;
    pData: Pointer;
    bSuccess: Boolean;
    sErrorMsg: string;
  end;
  pTMicroFileDataResult = ^TMicroFileDataResult;

implementation

uses
  DateUtils, ExtCtrls;

constructor TMicroServerManager.Create;
begin
  inherited Create;
  FServerSocket := INVALID_SOCKET;
  FServerAddr := '';
  FServerPort := 0;
  FIsConnected := False;
  FConnectThread := nil;
  FReceiveThread := nil;
  FReceiveBuffer := '';
  FCriticalSection := TCriticalSection.Create;
  FLastHeartbeat := Now;
  
  // 创建重连定时器
  FReconnectTimer := TTimer.Create(nil);
  FReconnectTimer.Enabled := False;
  FReconnectTimer.Interval := 30000; // 30秒重连一次
  FReconnectTimer.OnTimer := OnReconnectTimer;
end;

destructor TMicroServerManager.Destroy;
begin
  Disconnect;
  FReconnectTimer.Free;
  FCriticalSection.Free;
  inherited Destroy;
end;

function TMicroServerManager.Connect(const sAddr: string; nPort: Integer): Boolean;
var
  WSAData: TWSAData;
begin
  Result := False;
  
  if FIsConnected then
    Exit;
    
  FServerAddr := sAddr;
  FServerPort := nPort;
  
  // 初始化 Winsock
  if WSAStartup(MAKEWORD(2, 2), WSAData) <> 0 then begin
    WriteLog('初始化 Winsock 失败', True);
    Exit;
  end;
  
  // 创建连接线程
  FConnectThread := TThread.CreateAnonymousThread(ConnectToServer);
  FConnectThread.Start;
  
  Result := True;
end;

procedure TMicroServerManager.Disconnect;
begin
  FIsConnected := False;
  FReconnectTimer.Enabled := False;
  
  // 终止线程
  if FReceiveThread <> nil then begin
    FReceiveThread.Terminate;
    FReceiveThread.WaitFor;
    FReceiveThread.Free;
    FReceiveThread := nil;
  end;
  
  if FConnectThread <> nil then begin
    FConnectThread.Terminate;
    FConnectThread.WaitFor;
    FConnectThread.Free;
    FConnectThread := nil;
  end;
  
  // 关闭 Socket
  if FServerSocket <> INVALID_SOCKET then begin
    closesocket(FServerSocket);
    FServerSocket := INVALID_SOCKET;
  end;
  
  // 清理 Winsock
  WSACleanup;
  
  WriteLog('与微端服务器断开连接');
  
  // 触发断开事件
  if Assigned(FOnDisconnected) then
    FOnDisconnected(Self);
end;

procedure TMicroServerManager.Reconnect;
begin
  WriteLog('尝试重新连接微端服务器...');
  Disconnect;
  Connect(FServerAddr, FServerPort);
end;

procedure TMicroServerManager.ConnectToServer;
var
  SockAddr: TSockAddrIn;
  HostEnt: PHostEnt;
  nResult: Integer;
begin
  try
    // 创建 Socket
    FServerSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if FServerSocket = INVALID_SOCKET then begin
      WriteLog('创建服务器连接 Socket 失败: ' + IntToStr(WSAGetLastError), True);
      Exit;
    end;
    
    // 设置 Socket 选项
    nResult := 1;
    setsockopt(FServerSocket, SOL_SOCKET, SO_KEEPALIVE, @nResult, SizeOf(nResult));
    
    // 解析服务器地址
    FillChar(SockAddr, SizeOf(SockAddr), 0);
    SockAddr.sin_family := AF_INET;
    SockAddr.sin_port := htons(FServerPort);
    
    SockAddr.sin_addr.s_addr := inet_addr(PAnsiChar(AnsiString(FServerAddr)));
    if SockAddr.sin_addr.s_addr = INADDR_NONE then begin
      HostEnt := gethostbyname(PAnsiChar(AnsiString(FServerAddr)));
      if HostEnt = nil then begin
        WriteLog('解析服务器地址失败: ' + FServerAddr, True);
        Exit;
      end;
      SockAddr.sin_addr.s_addr := PLongint(HostEnt^.h_addr_list^)^;
    end;
    
    // 连接服务器
    if connect(FServerSocket, SockAddr, SizeOf(SockAddr)) = SOCKET_ERROR then begin
      WriteLog('连接微端服务器失败: ' + IntToStr(WSAGetLastError), True);
      closesocket(FServerSocket);
      FServerSocket := INVALID_SOCKET;
      
      // 启动重连定时器
      FReconnectTimer.Enabled := True;
      Exit;
    end;
    
    FIsConnected := True;
    FLastHeartbeat := Now;
    WriteLog('成功连接到微端服务器: ' + FServerAddr + ':' + IntToStr(FServerPort));
    
    // 触发连接事件
    if Assigned(FOnConnected) then
      FOnConnected(Self);
    
    // 创建接收线程
    FReceiveThread := TThread.CreateAnonymousThread(ReceiveFromServer);
    FReceiveThread.Start;
    
  except
    on E: Exception do begin
      WriteLog('连接微端服务器时出错: ' + E.Message, True);
      if FServerSocket <> INVALID_SOCKET then begin
        closesocket(FServerSocket);
        FServerSocket := INVALID_SOCKET;
      end;
      FReconnectTimer.Enabled := True;
    end;
  end;
end;

procedure TMicroServerManager.ReceiveFromServer;
var
  Buffer: array[0..4095] of Byte;
  nReceived: Integer;
  sData: string;
begin
  try
    while FIsConnected and (FServerSocket <> INVALID_SOCKET) do begin
      // 接收数据
      nReceived := recv(FServerSocket, Buffer, SizeOf(Buffer), 0);
      
      if nReceived = SOCKET_ERROR then begin
        if WSAGetLastError <> WSAEWOULDBLOCK then begin
          WriteLog('接收服务器数据失败: ' + IntToStr(WSAGetLastError), True);
          Break;
        end;
        Sleep(10);
        Continue;
      end;
      
      if nReceived = 0 then begin
        WriteLog('微端服务器主动断开连接');
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
      ProcessServerMessage(FReceiveBuffer);
      
      // 更新心跳时间
      FLastHeartbeat := Now;
    end;
    
  except
    on E: Exception do begin
      WriteLog('接收服务器数据时出错: ' + E.Message, True);
    end;
  end;
  
  // 连接断开，启动重连
  FIsConnected := False;
  if FServerSocket <> INVALID_SOCKET then begin
    closesocket(FServerSocket);
    FServerSocket := INVALID_SOCKET;
  end;
  
  FReconnectTimer.Enabled := True;
  
  // 触发断开事件
  if Assigned(FOnDisconnected) then
    FOnDisconnected(Self);
end;

procedure TMicroServerManager.ProcessServerMessage(const Buffer: string);
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
      WriteLog('收到无效的服务器消息签名', True);
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
      WriteLog('解析服务器消息失败', True);
      Continue;
    end;
    
    // 处理不同类型的消息
    try
      case Header.wMsgType of
        MS_RESOURCE_FOUND:
          begin
            WriteDebugLog('收到资源找到消息');
            if Assigned(FOnResourceFound) then
              FOnResourceFound(Data);
          end;
        MS_FILE_DATA:
          begin
            WriteDebugLog('收到文件数据消息');
            if Assigned(FOnFileData) then
              FOnFileData(Data);
          end;
        MS_FILE_HASH:
          begin
            WriteDebugLog('收到文件哈希消息');
          end;
        MS_RESOURCE_NOT_FOUND:
          begin
            WriteDebugLog('收到资源未找到消息');
            if Assigned(FOnResourceNotFound) then
              FOnResourceNotFound(Data);
          end;
        MS_SERVER_BUSY:
          begin
            WriteLog('微端服务器忙，请稍后重试');
          end;
      end;
    except
      on E: Exception do begin
        WriteLog('处理服务器消息时出错: ' + E.Message, True);
      end;
    end;
  end;
end;

procedure TMicroServerManager.SendToServer(wMsgType: Word; const Data; dwDataSize: LongWord);
var
  sMessage: string;
  nSent: Integer;
begin
  if not FIsConnected or (FServerSocket = INVALID_SOCKET) then
    Exit;
    
  try
    sMessage := MakeMicroMessage(wMsgType, Data, dwDataSize);
    nSent := send(FServerSocket, sMessage[1], Length(sMessage), 0);
    
    if nSent = SOCKET_ERROR then begin
      WriteLog('发送数据到服务器失败: ' + IntToStr(WSAGetLastError), True);
      // 连接可能已断开，触发重连
      FIsConnected := False;
      FReconnectTimer.Enabled := True;
    end;
    
  except
    on E: Exception do begin
      WriteLog('发送数据到服务器时出错: ' + E.Message, True);
    end;
  end;
end;

procedure TMicroServerManager.HandleHeartbeat;
var
  dwTimestamp: LongWord;
begin
  dwTimestamp := GetCurrentTimestamp;
  SendToServer($F000, dwTimestamp, SizeOf(dwTimestamp)); // 心跳消息
end;

procedure TMicroServerManager.OnReconnectTimer(Sender: TObject);
begin
  FReconnectTimer.Enabled := False;
  
  if not FIsConnected then begin
    WriteLog('尝试重新连接微端服务器...');
    ConnectToServer;
  end;
end;

// 向微端服务器发送请求的方法实现
procedure TMicroServerManager.QueryResource(const sFileName: string; const sFileHash: string);
var
  Request: record
    sFileName: array[0..254] of AnsiChar;
    sFileHash: array[0..31] of AnsiChar;
  end;
begin
  FillChar(Request, SizeOf(Request), 0);
  StrPLCopy(Request.sFileName, AnsiString(sFileName), SizeOf(Request.sFileName) - 1);
  StrPLCopy(Request.sFileHash, AnsiString(sFileHash), SizeOf(Request.sFileHash) - 1);
  
  SendToServer(MS_QUERY_RESOURCE, Request, SizeOf(Request));
  WriteDebugLog('查询资源: ' + sFileName);
end;

procedure TMicroServerManager.GetFileData(const sFileName: string; dwStartPos, dwSize: LongWord);
var
  Request: record
    sFileName: array[0..254] of AnsiChar;
    dwStartPos: LongWord;
    dwSize: LongWord;
  end;
begin
  FillChar(Request, SizeOf(Request), 0);
  StrPLCopy(Request.sFileName, AnsiString(sFileName), SizeOf(Request.sFileName) - 1);
  Request.dwStartPos := dwStartPos;
  Request.dwSize := dwSize;
  
  SendToServer(MS_GET_FILE_DATA, Request, SizeOf(Request));
  WriteDebugLog('获取文件数据: ' + sFileName + ', 位置: ' + IntToStr(dwStartPos) + ', 大小: ' + IntToStr(dwSize));
end;

procedure TMicroServerManager.CheckFileHash(const sFileName: string);
var
  Request: array[0..254] of AnsiChar;
begin
  FillChar(Request, SizeOf(Request), 0);
  StrPLCopy(Request, AnsiString(sFileName), SizeOf(Request) - 1);
  
  SendToServer(MS_CHECK_FILE_HASH, Request, SizeOf(Request));
  WriteDebugLog('检查文件哈希: ' + sFileName);
end;

procedure TMicroServerManager.UpdateStats(const sFileName: string; dwDownloadSize: LongWord);
var
  Request: record
    sFileName: array[0..254] of AnsiChar;
    dwDownloadSize: LongWord;
    dwTimestamp: LongWord;
  end;
begin
  FillChar(Request, SizeOf(Request), 0);
  StrPLCopy(Request.sFileName, AnsiString(sFileName), SizeOf(Request.sFileName) - 1);
  Request.dwDownloadSize := dwDownloadSize;
  Request.dwTimestamp := GetCurrentTimestamp;
  
  SendToServer(MS_UPDATE_STATS, Request, SizeOf(Request));
  WriteDebugLog('更新统计: ' + sFileName + ', 大小: ' + IntToStr(dwDownloadSize));
end;

end.
