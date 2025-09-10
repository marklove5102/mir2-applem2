unit MicroShare;

interface

uses
  Windows, SysUtils, Classes, SyncObjs;

const
  // 微端系统版本
  MICRO_VERSION = '1.0.0';
  
  // 默认配置
  DEFAULT_MICRO_PORT = 7200;
  DEFAULT_SERVER_PORT = 7300;
  DEFAULT_MAX_CONNECTIONS = 1000;
  DEFAULT_CHUNK_SIZE = 64 * 1024; // 64KB
  DEFAULT_CACHE_SIZE = 100 * 1024 * 1024; // 100MB
  
  // 消息类型定义
  // 客户端到微端网关
  MC_REQUEST_RESOURCE     = $F001;  // 请求资源
  MC_CHECK_VERSION        = $F002;  // 检查版本
  MC_DOWNLOAD_CHUNK       = $F003;  // 下载数据块
  MC_RESUME_DOWNLOAD      = $F004;  // 断点续传
  MC_CANCEL_DOWNLOAD      = $F005;  // 取消下载
  
  // 微端网关到客户端
  MC_RESOURCE_INFO        = $F101;  // 资源信息
  MC_VERSION_INFO         = $F102;  // 版本信息
  MC_DATA_CHUNK          = $F103;  // 数据块
  MC_DOWNLOAD_COMPLETE   = $F104;  // 下载完成
  MC_DOWNLOAD_ERROR      = $F105;  // 下载错误
  MC_DOWNLOAD_PROGRESS   = $F106;  // 下载进度
  
  // 微端网关到微端服务器
  MS_QUERY_RESOURCE      = $F201;  // 查询资源
  MS_GET_FILE_DATA       = $F202;  // 获取文件数据
  MS_CHECK_FILE_HASH     = $F203;  // 检查文件哈希
  MS_UPDATE_STATS        = $F204;  // 更新统计
  
  // 微端服务器到微端网关
  MS_RESOURCE_FOUND      = $F301;  // 资源找到
  MS_FILE_DATA          = $F302;  // 文件数据
  MS_FILE_HASH          = $F303;  // 文件哈希值
  MS_RESOURCE_NOT_FOUND = $F304;  // 资源未找到
  MS_SERVER_BUSY        = $F305;  // 服务器忙
  
  // 压缩类型
  COMPRESS_NONE    = 0;
  COMPRESS_ZLIB    = 1;
  COMPRESS_LZ4     = 2;
  COMPRESS_LZO     = 3;
  
  // 错误代码
  ERROR_SUCCESS           = 0;
  ERROR_FILE_NOT_FOUND    = 1;
  ERROR_INVALID_HASH      = 2;
  ERROR_NETWORK_ERROR     = 3;
  ERROR_SERVER_BUSY       = 4;
  ERROR_INVALID_REQUEST   = 5;
  ERROR_ACCESS_DENIED     = 6;
  ERROR_DISK_FULL         = 7;
  ERROR_MEMORY_FULL       = 8;

type
  // 基础消息头
  TMicroMessageHeader = packed record
    dwSignature: LongWord;      // 消息签名 'MICR'
    wMsgType: Word;             // 消息类型
    wFlags: Word;               // 标志位
    dwDataSize: LongWord;       // 数据大小
    dwCheckSum: LongWord;       // 校验和
    dwTimestamp: LongWord;      // 时间戳
  end;
  pTMicroMessageHeader = ^TMicroMessageHeader;

  // 资源请求结构
  TMicroResourceRequest = packed record
    dwRequestId: LongWord;        // 请求ID
    sFileName: array[0..254] of AnsiChar; // 文件名
    dwFileSize: LongWord;         // 期望文件大小
    sFileHash: array[0..31] of AnsiChar;  // 文件哈希值
    dwStartPos: LongWord;         // 起始位置（断点续传）
    dwChunkSize: LongWord;        // 块大小
    btPriority: Byte;             // 优先级 (0-255)
    btCompress: Byte;             // 压缩类型
    wReserved: Word;              // 保留字段
  end;
  pTMicroResourceRequest = ^TMicroResourceRequest;

  // 资源信息结构
  TMicroResourceInfo = packed record
    dwRequestId: LongWord;        // 请求ID
    sFileName: array[0..254] of AnsiChar; // 文件名
    dwFileSize: LongWord;         // 实际文件大小
    sFileHash: array[0..31] of AnsiChar;  // 文件哈希值
    dwVersion: LongWord;          // 文件版本
    btCompress: Byte;             // 压缩类型
    btEncrypt: Byte;              // 加密类型
    wReserved: Word;              // 保留字段
    dwCompressSize: LongWord;     // 压缩后大小
    dwTotalChunks: LongWord;      // 总块数
  end;
  pTMicroResourceInfo = ^TMicroResourceInfo;

  // 数据块结构
  TMicroDataChunk = packed record
    dwRequestId: LongWord;        // 请求ID
    dwChunkIndex: LongWord;       // 块索引
    dwChunkSize: LongWord;        // 块大小
    dwTotalChunks: LongWord;      // 总块数
    sChunkHash: array[0..31] of AnsiChar; // 块哈希值
    btCompress: Byte;             // 压缩类型
    btReserved: array[0..2] of Byte; // 保留字段
    // 后跟实际数据
  end;
  pTMicroDataChunk = ^TMicroDataChunk;

  // 下载进度结构
  TMicroDownloadProgress = packed record
    dwRequestId: LongWord;        // 请求ID
    dwDownloadedSize: LongWord;   // 已下载大小
    dwTotalSize: LongWord;        // 总大小
    dwSpeed: LongWord;            // 下载速度 (字节/秒)
    dwETA: LongWord;              // 预计剩余时间 (秒)
    wProgress: Word;              // 进度百分比 (0-10000, 表示0.00%-100.00%)
    wReserved: Word;              // 保留字段
  end;
  pTMicroDownloadProgress = ^TMicroDownloadProgress;

  // 错误信息结构
  TMicroErrorInfo = packed record
    dwRequestId: LongWord;        // 请求ID
    dwErrorCode: LongWord;        // 错误代码
    sErrorMsg: array[0..255] of AnsiChar; // 错误消息
  end;
  pTMicroErrorInfo = ^TMicroErrorInfo;

  // 连接信息
  TMicroConnectionInfo = record
    Socket: TSocket;              // Socket句柄
    RemoteAddr: string;           // 远程地址
    ConnectTime: TDateTime;       // 连接时间
    LastActiveTime: TDateTime;    // 最后活动时间
    SendBytes: Int64;             // 发送字节数
    RecvBytes: Int64;             // 接收字节数
    RequestCount: Integer;        // 请求次数
    UserData: Pointer;            // 用户数据
  end;
  pTMicroConnectionInfo = ^TMicroConnectionInfo;

  // 下载任务信息
  TMicroDownloadTask = class
  private
    FRequestId: LongWord;
    FFileName: string;
    FFileSize: LongWord;
    FFileHash: string;
    FStartPos: LongWord;
    FChunkSize: LongWord;
    FCurrentPos: LongWord;
    FDownloadedSize: LongWord;
    FPriority: Byte;
    FCompress: Byte;
    FCreateTime: TDateTime;
    FLastUpdateTime: TDateTime;
    FSpeed: LongWord;
    FConnection: pTMicroConnectionInfo;
    FCriticalSection: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Lock;
    procedure Unlock;
    procedure UpdateProgress(ADownloadedSize: LongWord);
    function GetProgress: Word;
    function GetETA: LongWord;
    
    property RequestId: LongWord read FRequestId write FRequestId;
    property FileName: string read FFileName write FFileName;
    property FileSize: LongWord read FFileSize write FFileSize;
    property FileHash: string read FFileHash write FFileHash;
    property StartPos: LongWord read FStartPos write FStartPos;
    property ChunkSize: LongWord read FChunkSize write FChunkSize;
    property CurrentPos: LongWord read FCurrentPos write FCurrentPos;
    property DownloadedSize: LongWord read FDownloadedSize write FDownloadedSize;
    property Priority: Byte read FPriority write FPriority;
    property Compress: Byte read FCompress write FCompress;
    property CreateTime: TDateTime read FCreateTime;
    property LastUpdateTime: TDateTime read FLastUpdateTime;
    property Speed: LongWord read FSpeed;
    property Connection: pTMicroConnectionInfo read FConnection write FConnection;
  end;

  // 配置信息
  TMicroGateConfig = record
    nListenPort: Integer;         // 监听端口
    nServerPort: Integer;         // 服务器端口
    sServerAddr: string;          // 服务器地址
    nMaxConnections: Integer;     // 最大连接数
    nChunkSize: Integer;          // 块大小
    nCacheSize: Integer;          // 缓存大小
    nTimeOut: Integer;            // 超时时间
    nMaxDownloadSpeed: Integer;   // 最大下载速度 (字节/秒)
    nMaxConcurrentDownloads: Integer; // 最大并发下载数
    bEnableCompress: Boolean;     // 启用压缩
    bEnableEncrypt: Boolean;      // 启用加密
    bEnableLog: Boolean;          // 启用日志
    sLogPath: string;             // 日志路径
  end;

// 全局变量
var
  g_Config: TMicroGateConfig;
  g_ConnectionList: TList;
  g_DownloadTasks: TList;
  g_CriticalSection: TCriticalSection;

// 工具函数
function MakeMicroMessage(wMsgType: Word; const Data; dwDataSize: LongWord): string;
function ParseMicroMessage(const Buffer: string; var Header: TMicroMessageHeader; var Data: Pointer): Boolean;
function CalculateCheckSum(const Data; dwSize: LongWord): LongWord;
function GetCurrentTimestamp: LongWord;
function GenerateRequestId: LongWord;
function HashToString(const Hash: array of AnsiChar): string;
function StringToHash(const HashStr: string): string;
function CompressData(const Data: Pointer; dwSize: LongWord; btCompress: Byte): string;
function DecompressData(const Data: string; btCompress: Byte): string;

// 日志函数
procedure WriteLog(const sMsg: string; bError: Boolean = False);
procedure WriteDebugLog(const sMsg: string);

implementation

uses
  MD5, ZLib;

// TMicroDownloadTask 实现
constructor TMicroDownloadTask.Create;
begin
  inherited Create;
  FCriticalSection := TCriticalSection.Create;
  FCreateTime := Now;
  FLastUpdateTime := Now;
  FRequestId := GenerateRequestId;
end;

destructor TMicroDownloadTask.Destroy;
begin
  FCriticalSection.Free;
  inherited Destroy;
end;

procedure TMicroDownloadTask.Lock;
begin
  FCriticalSection.Enter;
end;

procedure TMicroDownloadTask.Unlock;
begin
  FCriticalSection.Leave;
end;

procedure TMicroDownloadTask.UpdateProgress(ADownloadedSize: LongWord);
var
  dwElapsed: LongWord;
  dtNow: TDateTime;
begin
  Lock;
  try
    dtNow := Now;
    dwElapsed := MilliSecondsBetween(dtNow, FLastUpdateTime);
    
    if dwElapsed > 0 then begin
      FSpeed := (ADownloadedSize - FDownloadedSize) * 1000 div dwElapsed;
    end;
    
    FDownloadedSize := ADownloadedSize;
    FLastUpdateTime := dtNow;
  finally
    Unlock;
  end;
end;

function TMicroDownloadTask.GetProgress: Word;
begin
  if FFileSize > 0 then
    Result := (FDownloadedSize * 10000) div FFileSize
  else
    Result := 0;
end;

function TMicroDownloadTask.GetETA: LongWord;
begin
  if (FSpeed > 0) and (FFileSize > FDownloadedSize) then
    Result := (FFileSize - FDownloadedSize) div FSpeed
  else
    Result := 0;
end;

// 工具函数实现
function MakeMicroMessage(wMsgType: Word; const Data; dwDataSize: LongWord): string;
var
  Header: TMicroMessageHeader;
begin
  FillChar(Header, SizeOf(Header), 0);
  Header.dwSignature := $5243494D; // 'MICR'
  Header.wMsgType := wMsgType;
  Header.wFlags := 0;
  Header.dwDataSize := dwDataSize;
  Header.dwCheckSum := CalculateCheckSum(Data, dwDataSize);
  Header.dwTimestamp := GetCurrentTimestamp;
  
  SetLength(Result, SizeOf(Header) + dwDataSize);
  Move(Header, Result[1], SizeOf(Header));
  if dwDataSize > 0 then
    Move(Data, Result[1 + SizeOf(Header)], dwDataSize);
end;

function ParseMicroMessage(const Buffer: string; var Header: TMicroMessageHeader; var Data: Pointer): Boolean;
begin
  Result := False;
  Data := nil;
  
  if Length(Buffer) < SizeOf(TMicroMessageHeader) then
    Exit;
    
  Move(Buffer[1], Header, SizeOf(Header));
  
  // 验证签名
  if Header.dwSignature <> $5243494D then
    Exit;
    
  // 验证数据大小
  if Length(Buffer) < SizeOf(Header) + Integer(Header.dwDataSize) then
    Exit;
    
  // 验证校验和
  if Header.dwDataSize > 0 then begin
    Data := @Buffer[1 + SizeOf(Header)];
    if CalculateCheckSum(Data^, Header.dwDataSize) <> Header.dwCheckSum then
      Exit;
  end;
  
  Result := True;
end;

function CalculateCheckSum(const Data; dwSize: LongWord): LongWord;
var
  i: Integer;
  pData: PByte;
begin
  Result := 0;
  pData := @Data;
  for i := 0 to Integer(dwSize) - 1 do begin
    Result := Result xor pData^;
    Result := (Result shl 1) or (Result shr 31);
    Inc(pData);
  end;
end;

function GetCurrentTimestamp: LongWord;
begin
  Result := GetTickCount;
end;

var
  g_RequestIdCounter: LongWord = 0;

function GenerateRequestId: LongWord;
begin
  InterlockedIncrement(g_RequestIdCounter);
  Result := g_RequestIdCounter;
end;

function HashToString(const Hash: array of AnsiChar): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to 31 do begin
    if Hash[i] = #0 then
      Break;
    Result := Result + Hash[i];
  end;
end;

function StringToHash(const HashStr: string): string;
var
  i: Integer;
begin
  SetLength(Result, 32);
  FillChar(Result[1], 32, 0);
  for i := 1 to Min(Length(HashStr), 32) do
    Result[i] := HashStr[i];
end;

function CompressData(const Data: Pointer; dwSize: LongWord; btCompress: Byte): string;
var
  CompressedStream: TMemoryStream;
  CompressionStream: TCompressionStream;
begin
  Result := '';
  
  case btCompress of
    COMPRESS_NONE:
      begin
        SetLength(Result, dwSize);
        Move(Data^, Result[1], dwSize);
      end;
    COMPRESS_ZLIB:
      begin
        CompressedStream := TMemoryStream.Create;
        try
          CompressionStream := TCompressionStream.Create(clDefault, CompressedStream);
          try
            CompressionStream.Write(Data^, dwSize);
          finally
            CompressionStream.Free;
          end;
          
          SetLength(Result, CompressedStream.Size);
          Move(CompressedStream.Memory^, Result[1], CompressedStream.Size);
        finally
          CompressedStream.Free;
        end;
      end;
    else
      begin
        // 其他压缩算法的实现
        SetLength(Result, dwSize);
        Move(Data^, Result[1], dwSize);
      end;
  end;
end;

function DecompressData(const Data: string; btCompress: Byte): string;
var
  DataStream: TMemoryStream;
  DecompressionStream: TDecompressionStream;
  Buffer: array[0..4095] of Byte;
  BytesRead: Integer;
begin
  Result := '';
  
  case btCompress of
    COMPRESS_NONE:
      Result := Data;
    COMPRESS_ZLIB:
      begin
        DataStream := TMemoryStream.Create;
        try
          DataStream.Write(Data[1], Length(Data));
          DataStream.Position := 0;
          
          DecompressionStream := TDecompressionStream.Create(DataStream);
          try
            repeat
              BytesRead := DecompressionStream.Read(Buffer, SizeOf(Buffer));
              if BytesRead > 0 then
                Result := Result + Copy(string(Buffer), 1, BytesRead);
            until BytesRead = 0;
          finally
            DecompressionStream.Free;
          end;
        finally
          DataStream.Free;
        end;
      end;
    else
      Result := Data;
  end;
end;

procedure WriteLog(const sMsg: string; bError: Boolean = False);
var
  sLogFile: string;
  FileHandle: TextFile;
  sLogMsg: string;
begin
  if not g_Config.bEnableLog then
    Exit;
    
  try
    sLogFile := g_Config.sLogPath + '\MicroGate_' + FormatDateTime('yyyymmdd', Now) + '.log';
    AssignFile(FileHandle, sLogFile);
    
    if FileExists(sLogFile) then
      Append(FileHandle)
    else
      Rewrite(FileHandle);
      
    sLogMsg := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ';
    if bError then
      sLogMsg := sLogMsg + '[ERROR] '
    else
      sLogMsg := sLogMsg + '[INFO] ';
    sLogMsg := sLogMsg + sMsg;
    
    Writeln(FileHandle, sLogMsg);
    CloseFile(FileHandle);
  except
    // 忽略日志写入错误
  end;
end;

procedure WriteDebugLog(const sMsg: string);
begin
  {$IFDEF DEBUG}
  WriteLog('[DEBUG] ' + sMsg);
  {$ENDIF}
end;

initialization
  // 初始化全局变量
  FillChar(g_Config, SizeOf(g_Config), 0);
  g_Config.nListenPort := DEFAULT_MICRO_PORT;
  g_Config.nServerPort := DEFAULT_SERVER_PORT;
  g_Config.sServerAddr := '127.0.0.1';
  g_Config.nMaxConnections := DEFAULT_MAX_CONNECTIONS;
  g_Config.nChunkSize := DEFAULT_CHUNK_SIZE;
  g_Config.nCacheSize := DEFAULT_CACHE_SIZE;
  g_Config.nTimeOut := 30000; // 30秒
  g_Config.nMaxDownloadSpeed := 0; // 不限制
  g_Config.nMaxConcurrentDownloads := 10;
  g_Config.bEnableCompress := True;
  g_Config.bEnableEncrypt := False;
  g_Config.bEnableLog := True;
  g_Config.sLogPath := ExtractFilePath(ParamStr(0)) + 'Logs';
  
  g_ConnectionList := TList.Create;
  g_DownloadTasks := TList.Create;
  g_CriticalSection := TCriticalSection.Create;

finalization
  g_CriticalSection.Free;
  g_DownloadTasks.Free;
  g_ConnectionList.Free;

end.
