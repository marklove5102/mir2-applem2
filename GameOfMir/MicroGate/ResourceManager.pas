unit ResourceManager;

interface

uses
  Windows, SysUtils, Classes, SyncObjs, Contnrs, MicroShare;

type
  // 资源缓存项
  TResourceCacheItem = class
  private
    FFileName: string;
    FFileSize: LongWord;
    FFileHash: string;
    FData: Pointer;
    FDataSize: LongWord;
    FLastAccess: TDateTime;
    FAccessCount: Integer;
    FIsCompressed: Boolean;
    FCompressType: Byte;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure SetData(AData: Pointer; ASize: LongWord; bCompress: Boolean = False; btCompressType: Byte = COMPRESS_NONE);
    function GetData: Pointer;
    procedure UpdateAccess;
    
    property FileName: string read FFileName write FFileName;
    property FileSize: LongWord read FFileSize write FFileSize;
    property FileHash: string read FFileHash write FFileHash;
    property DataSize: LongWord read FDataSize;
    property LastAccess: TDateTime read FLastAccess;
    property AccessCount: Integer read FAccessCount;
    property IsCompressed: Boolean read FIsCompressed;
    property CompressType: Byte read FCompressType;
  end;

  // 资源管理器
  TResourceManager = class
  private
    FCacheList: TObjectList;
    FCriticalSection: TCriticalSection;
    FMaxCacheSize: Int64;
    FCurrentCacheSize: Int64;
    FHitCount: Integer;
    FMissCount: Integer;
    FCleanupTimer: TTimer;
    
    function FindCacheItem(const sFileName: string): TResourceCacheItem;
    procedure AddCacheItem(Item: TResourceCacheItem);
    procedure RemoveCacheItem(Item: TResourceCacheItem);
    procedure CleanupCache;
    procedure OnCleanupTimer(Sender: TObject);
    function GetCacheHitRate: Double;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Initialize;
    procedure Finalize;
    
    // 缓存管理
    function GetResource(const sFileName: string; const sFileHash: string): TResourceCacheItem;
    procedure CacheResource(const sFileName: string; const sFileHash: string; AData: Pointer; ASize: LongWord);
    procedure RemoveResource(const sFileName: string);
    procedure ClearCache;
    
    // 统计信息
    function GetCacheCount: Integer;
    function GetCacheSize: Int64;
    function GetCacheInfo: string;
    
    property MaxCacheSize: Int64 read FMaxCacheSize write FMaxCacheSize;
    property CurrentCacheSize: Int64 read FCurrentCacheSize;
    property CacheHitRate: Double read GetCacheHitRate;
    property HitCount: Integer read FHitCount;
    property MissCount: Integer read FMissCount;
  end;

  // 资源请求处理器
  TResourceRequestHandler = class
  private
    FResourceManager: TResourceManager;
    FServerManager: TMicroServerManager;
    FPendingRequests: TList;
    FCriticalSection: TCriticalSection;
    
    procedure OnResourceFound(Sender: TObject);
    procedure OnFileData(Sender: TObject);
    procedure OnResourceNotFound(Sender: TObject);
    
  public
    constructor Create(AResourceManager: TResourceManager; AServerManager: TMicroServerManager);
    destructor Destroy; override;
    
    procedure HandleResourceRequest(Connection: pTMicroConnectionInfo; const Request: TMicroResourceRequest);
    procedure CancelRequest(dwRequestId: LongWord);
    procedure CancelAllRequests;
  end;

  // 待处理请求
  TPendingRequest = record
    dwRequestId: LongWord;
    Connection: pTMicroConnectionInfo;
    Request: TMicroResourceRequest;
    CreateTime: TDateTime;
    LastUpdateTime: TDateTime;
  end;
  pTPendingRequest = ^TPendingRequest;

implementation

uses
  DateUtils, ExtCtrls, MD5;

// TResourceCacheItem 实现

constructor TResourceCacheItem.Create;
begin
  inherited Create;
  FFileName := '';
  FFileSize := 0;
  FFileHash := '';
  FData := nil;
  FDataSize := 0;
  FLastAccess := Now;
  FAccessCount := 0;
  FIsCompressed := False;
  FCompressType := COMPRESS_NONE;
end;

destructor TResourceCacheItem.Destroy;
begin
  if FData <> nil then begin
    FreeMem(FData);
    FData := nil;
  end;
  inherited Destroy;
end;

procedure TResourceCacheItem.SetData(AData: Pointer; ASize: LongWord; bCompress: Boolean; btCompressType: Byte);
begin
  // 释放旧数据
  if FData <> nil then begin
    FreeMem(FData);
    FData := nil;
  end;
  
  if (AData <> nil) and (ASize > 0) then begin
    // 分配新内存并复制数据
    GetMem(FData, ASize);
    Move(AData^, FData^, ASize);
    FDataSize := ASize;
    FIsCompressed := bCompress;
    FCompressType := btCompressType;
  end else begin
    FDataSize := 0;
    FIsCompressed := False;
    FCompressType := COMPRESS_NONE;
  end;
  
  UpdateAccess;
end;

function TResourceCacheItem.GetData: Pointer;
begin
  UpdateAccess;
  Result := FData;
end;

procedure TResourceCacheItem.UpdateAccess;
begin
  FLastAccess := Now;
  Inc(FAccessCount);
end;

// TResourceManager 实现

constructor TResourceManager.Create;
begin
  inherited Create;
  FCacheList := TObjectList.Create(True);
  FCriticalSection := TCriticalSection.Create;
  FMaxCacheSize := g_Config.nCacheSize;
  FCurrentCacheSize := 0;
  FHitCount := 0;
  FMissCount := 0;
  
  // 创建清理定时器
  FCleanupTimer := TTimer.Create(nil);
  FCleanupTimer.Enabled := False;
  FCleanupTimer.Interval := 60000; // 1分钟清理一次
  FCleanupTimer.OnTimer := OnCleanupTimer;
end;

destructor TResourceManager.Destroy;
begin
  Finalize;
  FCleanupTimer.Free;
  FCriticalSection.Free;
  FCacheList.Free;
  inherited Destroy;
end;

procedure TResourceManager.Initialize;
begin
  WriteLog('资源管理器初始化');
  FCleanupTimer.Enabled := True;
end;

procedure TResourceManager.Finalize;
begin
  FCleanupTimer.Enabled := False;
  ClearCache;
  WriteLog('资源管理器已关闭');
end;

function TResourceManager.FindCacheItem(const sFileName: string): TResourceCacheItem;
var
  i: Integer;
  Item: TResourceCacheItem;
begin
  Result := nil;
  
  FCriticalSection.Enter;
  try
    for i := 0 to FCacheList.Count - 1 do begin
      Item := TResourceCacheItem(FCacheList[i]);
      if CompareText(Item.FileName, sFileName) = 0 then begin
        Result := Item;
        Break;
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TResourceManager.AddCacheItem(Item: TResourceCacheItem);
begin
  if Item = nil then
    Exit;
    
  FCriticalSection.Enter;
  try
    // 检查是否已存在
    if FindCacheItem(Item.FileName) <> nil then
      Exit;
      
    // 检查缓存大小限制
    while (FCurrentCacheSize + Item.DataSize > FMaxCacheSize) and (FCacheList.Count > 0) do
      CleanupCache;
      
    FCacheList.Add(Item);
    FCurrentCacheSize := FCurrentCacheSize + Item.DataSize;
    
    WriteDebugLog('缓存资源: ' + Item.FileName + ', 大小: ' + IntToStr(Item.DataSize));
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TResourceManager.RemoveCacheItem(Item: TResourceCacheItem);
begin
  if Item = nil then
    Exit;
    
  FCriticalSection.Enter;
  try
    if FCacheList.IndexOf(Item) >= 0 then begin
      FCurrentCacheSize := FCurrentCacheSize - Item.DataSize;
      FCacheList.Remove(Item);
      WriteDebugLog('移除缓存: ' + Item.FileName);
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TResourceManager.CleanupCache;
var
  i: Integer;
  Item: TResourceCacheItem;
  OldestItem: TResourceCacheItem;
  OldestTime: TDateTime;
begin
  FCriticalSection.Enter;
  try
    if FCacheList.Count = 0 then
      Exit;
      
    // 找到最久未访问的项目
    OldestItem := nil;
    OldestTime := Now;
    
    for i := 0 to FCacheList.Count - 1 do begin
      Item := TResourceCacheItem(FCacheList[i]);
      if Item.LastAccess < OldestTime then begin
        OldestTime := Item.LastAccess;
        OldestItem := Item;
      end;
    end;
    
    // 移除最久未访问的项目
    if OldestItem <> nil then begin
      FCurrentCacheSize := FCurrentCacheSize - OldestItem.DataSize;
      FCacheList.Remove(OldestItem);
      WriteDebugLog('清理缓存: ' + OldestItem.FileName);
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TResourceManager.OnCleanupTimer(Sender: TObject);
var
  i: Integer;
  Item: TResourceCacheItem;
  dtExpireTime: TDateTime;
  ItemsToRemove: TList;
begin
  // 清理过期的缓存项（超过30分钟未访问）
  dtExpireTime := Now - (30 / (24 * 60)); // 30分钟前
  ItemsToRemove := TList.Create;
  try
    FCriticalSection.Enter;
    try
      for i := 0 to FCacheList.Count - 1 do begin
        Item := TResourceCacheItem(FCacheList[i]);
        if Item.LastAccess < dtExpireTime then
          ItemsToRemove.Add(Item);
      end;
      
      for i := 0 to ItemsToRemove.Count - 1 do begin
        Item := TResourceCacheItem(ItemsToRemove[i]);
        FCurrentCacheSize := FCurrentCacheSize - Item.DataSize;
        FCacheList.Remove(Item);
      end;
    finally
      FCriticalSection.Leave;
    end;
    
    if ItemsToRemove.Count > 0 then
      WriteDebugLog('清理过期缓存项: ' + IntToStr(ItemsToRemove.Count) + ' 个');
      
  finally
    ItemsToRemove.Free;
  end;
end;

function TResourceManager.GetCacheHitRate: Double;
var
  nTotal: Integer;
begin
  nTotal := FHitCount + FMissCount;
  if nTotal > 0 then
    Result := FHitCount / nTotal * 100.0
  else
    Result := 0.0;
end;

function TResourceManager.GetResource(const sFileName: string; const sFileHash: string): TResourceCacheItem;
begin
  Result := FindCacheItem(sFileName);
  
  if Result <> nil then begin
    // 验证文件哈希
    if (sFileHash <> '') and (Result.FileHash <> sFileHash) then begin
      WriteLog('缓存文件哈希不匹配，移除缓存: ' + sFileName, True);
      RemoveCacheItem(Result);
      Result := nil;
      Inc(FMissCount);
    end else begin
      Inc(FHitCount);
      WriteDebugLog('缓存命中: ' + sFileName);
    end;
  end else begin
    Inc(FMissCount);
    WriteDebugLog('缓存未命中: ' + sFileName);
  end;
end;

procedure TResourceManager.CacheResource(const sFileName: string; const sFileHash: string; AData: Pointer; ASize: LongWord);
var
  Item: TResourceCacheItem;
  sCompressedData: string;
  pCompressedData: Pointer;
  dwCompressedSize: LongWord;
begin
  if (AData = nil) or (ASize = 0) then
    Exit;
    
  // 检查是否已存在
  Item := FindCacheItem(sFileName);
  if Item <> nil then begin
    WriteDebugLog('资源已存在于缓存中: ' + sFileName);
    Exit;
  end;
  
  // 创建新的缓存项
  Item := TResourceCacheItem.Create;
  Item.FileName := sFileName;
  Item.FileSize := ASize;
  Item.FileHash := sFileHash;
  
  // 尝试压缩数据
  if g_Config.bEnableCompress and (ASize > 1024) then begin
    try
      sCompressedData := CompressData(AData, ASize, COMPRESS_ZLIB);
      dwCompressedSize := Length(sCompressedData);
      
      if dwCompressedSize < ASize then begin
        // 压缩有效，使用压缩数据
        GetMem(pCompressedData, dwCompressedSize);
        Move(sCompressedData[1], pCompressedData^, dwCompressedSize);
        Item.SetData(pCompressedData, dwCompressedSize, True, COMPRESS_ZLIB);
        FreeMem(pCompressedData);
        WriteDebugLog('压缩资源: ' + sFileName + ', 原始: ' + IntToStr(ASize) + ', 压缩: ' + IntToStr(dwCompressedSize));
      end else begin
        // 压缩无效，使用原始数据
        Item.SetData(AData, ASize, False, COMPRESS_NONE);
      end;
    except
      on E: Exception do begin
        WriteLog('压缩资源失败: ' + E.Message, True);
        Item.SetData(AData, ASize, False, COMPRESS_NONE);
      end;
    end;
  end else begin
    // 不压缩，直接缓存
    Item.SetData(AData, ASize, False, COMPRESS_NONE);
  end;
  
  // 添加到缓存
  AddCacheItem(Item);
end;

procedure TResourceManager.RemoveResource(const sFileName: string);
var
  Item: TResourceCacheItem;
begin
  Item := FindCacheItem(sFileName);
  if Item <> nil then
    RemoveCacheItem(Item);
end;

procedure TResourceManager.ClearCache;
begin
  FCriticalSection.Enter;
  try
    FCacheList.Clear;
    FCurrentCacheSize := 0;
    FHitCount := 0;
    FMissCount := 0;
    WriteLog('缓存已清空');
  finally
    FCriticalSection.Leave;
  end;
end;

function TResourceManager.GetCacheCount: Integer;
begin
  FCriticalSection.Enter;
  try
    Result := FCacheList.Count;
  finally
    FCriticalSection.Leave;
  end;
end;

function TResourceManager.GetCacheSize: Int64;
begin
  Result := FCurrentCacheSize;
end;

function TResourceManager.GetCacheInfo: string;
begin
  Result := Format('缓存项: %d, 大小: %s, 命中率: %.1f%%, 命中: %d, 未命中: %d',
    [GetCacheCount, FormatBytes(FCurrentCacheSize), GetCacheHitRate, FHitCount, FMissCount]);
end;

// TResourceRequestHandler 实现

constructor TResourceRequestHandler.Create(AResourceManager: TResourceManager; AServerManager: TMicroServerManager);
begin
  inherited Create;
  FResourceManager := AResourceManager;
  FServerManager := AServerManager;
  FPendingRequests := TList.Create;
  FCriticalSection := TCriticalSection.Create;
  
  // 设置服务器事件处理
  if FServerManager <> nil then begin
    FServerManager.OnResourceFound := OnResourceFound;
    FServerManager.OnFileData := OnFileData;
    FServerManager.OnResourceNotFound := OnResourceNotFound;
  end;
end;

destructor TResourceRequestHandler.Destroy;
begin
  CancelAllRequests;
  FCriticalSection.Free;
  FPendingRequests.Free;
  inherited Destroy;
end;

procedure TResourceRequestHandler.HandleResourceRequest(Connection: pTMicroConnectionInfo; const Request: TMicroResourceRequest);
var
  CacheItem: TResourceCacheItem;
  PendingRequest: pTPendingRequest;
  ResourceInfo: TMicroResourceInfo;
  sFileName, sFileHash: string;
begin
  sFileName := string(Request.sFileName);
  sFileHash := string(Request.sFileHash);
  
  WriteDebugLog('处理资源请求: ' + sFileName);
  
  // 首先检查缓存
  CacheItem := FResourceManager.GetResource(sFileName, sFileHash);
  if CacheItem <> nil then begin
    // 缓存命中，直接返回资源信息
    FillChar(ResourceInfo, SizeOf(ResourceInfo), 0);
    ResourceInfo.dwRequestId := Request.dwRequestId;
    StrPLCopy(ResourceInfo.sFileName, AnsiString(CacheItem.FileName), SizeOf(ResourceInfo.sFileName) - 1);
    ResourceInfo.dwFileSize := CacheItem.FileSize;
    StrPLCopy(ResourceInfo.sFileHash, AnsiString(CacheItem.FileHash), SizeOf(ResourceInfo.sFileHash) - 1);
    ResourceInfo.dwVersion := 1;
    ResourceInfo.btCompress := Byte(CacheItem.IsCompressed);
    ResourceInfo.btEncrypt := 0;
    ResourceInfo.dwCompressSize := CacheItem.DataSize;
    ResourceInfo.dwTotalChunks := (CacheItem.DataSize + Request.dwChunkSize - 1) div Request.dwChunkSize;
    
    // 发送资源信息给客户端
    // TODO: 这里需要客户端管理器的引用来发送消息
    WriteDebugLog('从缓存返回资源: ' + sFileName);
    Exit;
  end;
  
  // 缓存未命中，向微端服务器请求
  New(PendingRequest);
  PendingRequest.dwRequestId := Request.dwRequestId;
  PendingRequest.Connection := Connection;
  PendingRequest.Request := Request;
  PendingRequest.CreateTime := Now;
  PendingRequest.LastUpdateTime := Now;
  
  FCriticalSection.Enter;
  try
    FPendingRequests.Add(PendingRequest);
  finally
    FCriticalSection.Leave;
  end;
  
  // 向微端服务器查询资源
  if FServerManager <> nil then
    FServerManager.QueryResource(sFileName, sFileHash);
end;

procedure TResourceRequestHandler.CancelRequest(dwRequestId: LongWord);
var
  i: Integer;
  PendingRequest: pTPendingRequest;
begin
  FCriticalSection.Enter;
  try
    for i := FPendingRequests.Count - 1 downto 0 do begin
      PendingRequest := FPendingRequests[i];
      if PendingRequest.dwRequestId = dwRequestId then begin
        Dispose(PendingRequest);
        FPendingRequests.Delete(i);
        WriteDebugLog('取消请求: ' + IntToStr(dwRequestId));
        Break;
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TResourceRequestHandler.CancelAllRequests;
var
  i: Integer;
  PendingRequest: pTPendingRequest;
begin
  FCriticalSection.Enter;
  try
    for i := 0 to FPendingRequests.Count - 1 do begin
      PendingRequest := FPendingRequests[i];
      Dispose(PendingRequest);
    end;
    FPendingRequests.Clear;
    WriteDebugLog('取消所有待处理请求');
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TResourceRequestHandler.OnResourceFound(Sender: TObject);
begin
  // 处理资源找到事件
  WriteDebugLog('资源找到事件');
  // TODO: 实现具体的处理逻辑
end;

procedure TResourceRequestHandler.OnFileData(Sender: TObject);
begin
  // 处理文件数据事件
  WriteDebugLog('文件数据事件');
  // TODO: 实现具体的处理逻辑
end;

procedure TResourceRequestHandler.OnResourceNotFound(Sender: TObject);
begin
  // 处理资源未找到事件
  WriteDebugLog('资源未找到事件');
  // TODO: 实现具体的处理逻辑
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
