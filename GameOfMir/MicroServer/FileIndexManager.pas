unit FileIndexManager;

interface

uses
  Windows, SysUtils, Classes, SyncObjs, DB, ADODB, Contnrs, MicroShare;

type
  // 文件索引项
  TFileIndexItem = class
  private
    FFileId: Integer;
    FFileName: string;
    FFilePath: string;
    FFileSize: Int64;
    FFileHash: string;
    FVersion: Integer;
    FCreateTime: TDateTime;
    FUpdateTime: TDateTime;
    FCompressType: Byte;
    FCompressSize: Int64;
    FDependencies: string;
    FAccessCount: Integer;
    FLastAccess: TDateTime;
  public
    constructor Create;
    
    property FileId: Integer read FFileId write FFileId;
    property FileName: string read FFileName write FFileName;
    property FilePath: string read FFilePath write FFilePath;
    property FileSize: Int64 read FFileSize write FFileSize;
    property FileHash: string read FFileHash write FFileHash;
    property Version: Integer read FVersion write FVersion;
    property CreateTime: TDateTime read FCreateTime write FCreateTime;
    property UpdateTime: TDateTime read FUpdateTime write FUpdateTime;
    property CompressType: Byte read FCompressType write FCompressType;
    property CompressSize: Int64 read FCompressSize write FCompressSize;
    property Dependencies: string read FDependencies write FDependencies;
    property AccessCount: Integer read FAccessCount write FAccessCount;
    property LastAccess: TDateTime read FLastAccess write FLastAccess;
  end;

  // 文件索引管理器
  TFileIndexManager = class
  private
    FConnection: TADOConnection;
    FIndexList: TObjectList;
    FHashIndex: TStringList; // 文件哈希索引
    FNameIndex: TStringList; // 文件名索引
    FCriticalSection: TCriticalSection;
    FDatabasePath: string;
    FIsInitialized: Boolean;
    FUpdateTimer: TTimer;
    
    procedure InitializeDatabase;
    procedure CreateTables;
    procedure LoadFileIndex;
    procedure BuildIndexes;
    procedure UpdateIndexes;
    procedure OnUpdateTimer(Sender: TObject);
    function FindItemByHash(const sFileHash: string): TFileIndexItem;
    function FindItemByName(const sFileName: string): TFileIndexItem;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Initialize(const sDatabasePath: string);
    procedure Finalize;
    
    // 文件索引管理
    function AddFile(const sFileName, sFilePath: string; nFileSize: Int64; const sFileHash: string): TFileIndexItem;
    function UpdateFile(Item: TFileIndexItem): Boolean;
    function RemoveFile(const sFileName: string): Boolean;
    function FindFile(const sFileName: string): TFileIndexItem; overload;
    function FindFile(const sFileName, sFileHash: string): TFileIndexItem; overload;
    function GetFileList(const sPattern: string = ''): TList;
    
    // 批量操作
    function ScanDirectory(const sDirectory: string; bRecursive: Boolean = True): Integer;
    function RebuildIndex: Integer;
    function CleanupIndex: Integer;
    
    // 统计信息
    function GetFileCount: Integer;
    function GetTotalSize: Int64;
    function GetIndexInfo: string;
    
    // 数据库操作
    function ExecuteSQL(const sSQL: string): Boolean;
    function QuerySQL(const sSQL: string): TADOQuery;
    
    property IsInitialized: Boolean read FIsInitialized;
    property DatabasePath: string read FDatabasePath;
  end;

  // 文件扫描器
  TFileScanner = class
  private
    FIndexManager: TFileIndexManager;
    FRootPath: string;
    FFileCount: Integer;
    FTotalSize: Int64;
    FOnProgress: TNotifyEvent;
    FOnFileFound: TNotifyEvent;
    
    procedure ScanPath(const sPath: string; bRecursive: Boolean);
    function CalculateFileHash(const sFilePath: string): string;
    function ShouldSkipFile(const sFileName: string): Boolean;
    
  public
    constructor Create(AIndexManager: TFileIndexManager);
    
    function ScanDirectory(const sRootPath: string; bRecursive: Boolean = True): Integer;
    
    property FileCount: Integer read FFileCount;
    property TotalSize: Int64 read FTotalSize;
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
    property OnFileFound: TNotifyEvent read FOnFileFound write FOnFileFound;
  end;

implementation

uses
  DateUtils, ExtCtrls, MD5, FileCtrl;

// TFileIndexItem 实现

constructor TFileIndexItem.Create;
begin
  inherited Create;
  FFileId := 0;
  FFileName := '';
  FFilePath := '';
  FFileSize := 0;
  FFileHash := '';
  FVersion := 1;
  FCreateTime := Now;
  FUpdateTime := Now;
  FCompressType := COMPRESS_NONE;
  FCompressSize := 0;
  FDependencies := '';
  FAccessCount := 0;
  FLastAccess := Now;
end;

// TFileIndexManager 实现

constructor TFileIndexManager.Create;
begin
  inherited Create;
  FConnection := TADOConnection.Create(nil);
  FIndexList := TObjectList.Create(True);
  FHashIndex := TStringList.Create;
  FNameIndex := TStringList.Create;
  FCriticalSection := TCriticalSection.Create;
  FDatabasePath := '';
  FIsInitialized := False;
  
  // 设置索引排序
  FHashIndex.Sorted := True;
  FHashIndex.Duplicates := dupIgnore;
  FNameIndex.Sorted := True;
  FNameIndex.Duplicates := dupIgnore;
  
  // 创建更新定时器
  FUpdateTimer := TTimer.Create(nil);
  FUpdateTimer.Enabled := False;
  FUpdateTimer.Interval := 300000; // 5分钟更新一次
  FUpdateTimer.OnTimer := OnUpdateTimer;
end;

destructor TFileIndexManager.Destroy;
begin
  Finalize;
  FUpdateTimer.Free;
  FCriticalSection.Free;
  FNameIndex.Free;
  FHashIndex.Free;
  FIndexList.Free;
  FConnection.Free;
  inherited Destroy;
end;

procedure TFileIndexManager.Initialize(const sDatabasePath: string);
begin
  if FIsInitialized then
    Exit;
    
  FDatabasePath := sDatabasePath;
  
  try
    InitializeDatabase;
    LoadFileIndex;
    BuildIndexes;
    
    FIsInitialized := True;
    FUpdateTimer.Enabled := True;
    
    WriteLog('文件索引管理器初始化完成，数据库: ' + sDatabasePath);
    WriteLog('索引文件数: ' + IntToStr(GetFileCount) + ', 总大小: ' + FormatBytes(GetTotalSize));
    
  except
    on E: Exception do begin
      WriteLog('初始化文件索引管理器失败: ' + E.Message, True);
      raise;
    end;
  end;
end;

procedure TFileIndexManager.Finalize;
begin
  if not FIsInitialized then
    Exit;
    
  FUpdateTimer.Enabled := False;
  
  if FConnection.Connected then
    FConnection.Close;
    
  FCriticalSection.Enter;
  try
    FIndexList.Clear;
    FHashIndex.Clear;
    FNameIndex.Clear;
  finally
    FCriticalSection.Leave;
  end;
  
  FIsInitialized := False;
  WriteLog('文件索引管理器已关闭');
end;

procedure TFileIndexManager.InitializeDatabase;
var
  sConnectionString: string;
begin
  // 构建连接字符串
  sConnectionString := 'Provider=Microsoft.Jet.OLEDB.4.0;Data Source=' + FDatabasePath + ';';
  
  try
    FConnection.ConnectionString := sConnectionString;
    FConnection.Open;
    
    // 创建表结构
    CreateTables;
    
    WriteLog('数据库连接成功: ' + FDatabasePath);
    
  except
    on E: Exception do begin
      WriteLog('连接数据库失败: ' + E.Message, True);
      raise;
    end;
  end;
end;

procedure TFileIndexManager.CreateTables;
var
  Query: TADOQuery;
begin
  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // 创建文件索引表
    try
      Query.SQL.Text := 
        'CREATE TABLE FileIndex (' +
        'FileId AUTOINCREMENT PRIMARY KEY, ' +
        'FileName TEXT(255) NOT NULL, ' +
        'FilePath TEXT(500) NOT NULL, ' +
        'FileSize LONG NOT NULL, ' +
        'FileHash TEXT(32) NOT NULL, ' +
        'Version LONG NOT NULL, ' +
        'CreateTime DATETIME NOT NULL, ' +
        'UpdateTime DATETIME NOT NULL, ' +
        'CompressType BYTE DEFAULT 0, ' +
        'CompressSize LONG DEFAULT 0, ' +
        'Dependencies MEMO, ' +
        'AccessCount LONG DEFAULT 0, ' +
        'LastAccess DATETIME' +
        ')';
      Query.ExecSQL;
    except
      // 表可能已存在，忽略错误
    end;
    
    // 创建补丁信息表
    try
      Query.SQL.Text := 
        'CREATE TABLE PatchInfo (' +
        'PatchId AUTOINCREMENT PRIMARY KEY, ' +
        'FromVersion LONG NOT NULL, ' +
        'ToVersion LONG NOT NULL, ' +
        'PatchFile TEXT(255) NOT NULL, ' +
        'PatchSize LONG NOT NULL, ' +
        'PatchHash TEXT(32) NOT NULL, ' +
        'CreateTime DATETIME NOT NULL' +
        ')';
      Query.ExecSQL;
    except
      // 表可能已存在，忽略错误
    end;
    
    // 创建下载统计表
    try
      Query.SQL.Text := 
        'CREATE TABLE DownloadStats (' +
        'StatId AUTOINCREMENT PRIMARY KEY, ' +
        'FileId LONG NOT NULL, ' +
        'DownloadCount LONG DEFAULT 0, ' +
        'TotalBytes LONG DEFAULT 0, ' +
        'LastAccess DATETIME' +
        ')';
      Query.ExecSQL;
    except
      // 表可能已存在，忽略错误
    end;
    
    // 创建索引
    try
      Query.SQL.Text := 'CREATE INDEX idx_filename ON FileIndex (FileName)';
      Query.ExecSQL;
    except
    end;
    
    try
      Query.SQL.Text := 'CREATE INDEX idx_hash ON FileIndex (FileHash)';
      Query.ExecSQL;
    except
    end;
    
    try
      Query.SQL.Text := 'CREATE INDEX idx_version ON FileIndex (Version)';
      Query.ExecSQL;
    except
    end;
    
  finally
    Query.Free;
  end;
end;

procedure TFileIndexManager.LoadFileIndex;
var
  Query: TADOQuery;
  Item: TFileIndexItem;
begin
  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM FileIndex ORDER BY FileName';
    Query.Open;
    
    FCriticalSection.Enter;
    try
      FIndexList.Clear;
      
      while not Query.Eof do begin
        Item := TFileIndexItem.Create;
        Item.FileId := Query.FieldByName('FileId').AsInteger;
        Item.FileName := Query.FieldByName('FileName').AsString;
        Item.FilePath := Query.FieldByName('FilePath').AsString;
        Item.FileSize := Query.FieldByName('FileSize').AsLargeInt;
        Item.FileHash := Query.FieldByName('FileHash').AsString;
        Item.Version := Query.FieldByName('Version').AsInteger;
        Item.CreateTime := Query.FieldByName('CreateTime').AsDateTime;
        Item.UpdateTime := Query.FieldByName('UpdateTime').AsDateTime;
        Item.CompressType := Query.FieldByName('CompressType').AsInteger;
        Item.CompressSize := Query.FieldByName('CompressSize').AsLargeInt;
        Item.Dependencies := Query.FieldByName('Dependencies').AsString;
        Item.AccessCount := Query.FieldByName('AccessCount').AsInteger;
        if not Query.FieldByName('LastAccess').IsNull then
          Item.LastAccess := Query.FieldByName('LastAccess').AsDateTime;
        
        FIndexList.Add(Item);
        Query.Next;
      end;
    finally
      FCriticalSection.Leave;
    end;
    
    Query.Close;
    WriteLog('加载文件索引完成，共 ' + IntToStr(FIndexList.Count) + ' 个文件');
    
  finally
    Query.Free;
  end;
end;

procedure TFileIndexManager.BuildIndexes;
var
  i: Integer;
  Item: TFileIndexItem;
begin
  FCriticalSection.Enter;
  try
    FHashIndex.Clear;
    FNameIndex.Clear;
    
    for i := 0 to FIndexList.Count - 1 do begin
      Item := TFileIndexItem(FIndexList[i]);
      if Item <> nil then begin
        FHashIndex.AddObject(Item.FileHash, Item);
        FNameIndex.AddObject(UpperCase(Item.FileName), Item);
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
  
  WriteLog('构建文件索引完成，哈希索引: ' + IntToStr(FHashIndex.Count) + ', 名称索引: ' + IntToStr(FNameIndex.Count));
end;

procedure TFileIndexManager.UpdateIndexes;
begin
  LoadFileIndex;
  BuildIndexes;
end;

procedure TFileIndexManager.OnUpdateTimer(Sender: TObject);
begin
  try
    UpdateIndexes;
    WriteDebugLog('定时更新文件索引');
  except
    on E: Exception do begin
      WriteLog('更新文件索引时出错: ' + E.Message, True);
    end;
  end;
end;

function TFileIndexManager.FindItemByHash(const sFileHash: string): TFileIndexItem;
var
  nIndex: Integer;
begin
  Result := nil;
  
  FCriticalSection.Enter;
  try
    if FHashIndex.Find(sFileHash, nIndex) then
      Result := TFileIndexItem(FHashIndex.Objects[nIndex]);
  finally
    FCriticalSection.Leave;
  end;
end;

function TFileIndexManager.FindItemByName(const sFileName: string): TFileIndexItem;
var
  nIndex: Integer;
begin
  Result := nil;
  
  FCriticalSection.Enter;
  try
    if FNameIndex.Find(UpperCase(sFileName), nIndex) then
      Result := TFileIndexItem(FNameIndex.Objects[nIndex]);
  finally
    FCriticalSection.Leave;
  end;
end;

function TFileIndexManager.AddFile(const sFileName, sFilePath: string; nFileSize: Int64; const sFileHash: string): TFileIndexItem;
var
  Query: TADOQuery;
  Item: TFileIndexItem;
begin
  Result := nil;
  
  // 检查文件是否已存在
  Item := FindItemByName(sFileName);
  if Item <> nil then begin
    // 更新现有文件
    Item.FilePath := sFilePath;
    Item.FileSize := nFileSize;
    Item.FileHash := sFileHash;
    Item.UpdateTime := Now;
    Inc(Item.Version);
    
    if UpdateFile(Item) then
      Result := Item;
    Exit;
  end;
  
  // 添加新文件
  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT INTO FileIndex (FileName, FilePath, FileSize, FileHash, Version, CreateTime, UpdateTime, CompressType, CompressSize, AccessCount, LastAccess) ' +
      'VALUES (:FileName, :FilePath, :FileSize, :FileHash, :Version, :CreateTime, :UpdateTime, :CompressType, :CompressSize, :AccessCount, :LastAccess)';
    
    Query.Parameters.ParamByName('FileName').Value := sFileName;
    Query.Parameters.ParamByName('FilePath').Value := sFilePath;
    Query.Parameters.ParamByName('FileSize').Value := nFileSize;
    Query.Parameters.ParamByName('FileHash').Value := sFileHash;
    Query.Parameters.ParamByName('Version').Value := 1;
    Query.Parameters.ParamByName('CreateTime').Value := Now;
    Query.Parameters.ParamByName('UpdateTime').Value := Now;
    Query.Parameters.ParamByName('CompressType').Value := COMPRESS_NONE;
    Query.Parameters.ParamByName('CompressSize').Value := 0;
    Query.Parameters.ParamByName('AccessCount').Value := 0;
    Query.Parameters.ParamByName('LastAccess').Value := Now;
    
    Query.ExecSQL;
    
    // 获取新插入的ID
    Query.SQL.Text := 'SELECT @@IDENTITY AS NewId';
    Query.Open;
    
    // 创建索引项
    Item := TFileIndexItem.Create;
    Item.FileId := Query.FieldByName('NewId').AsInteger;
    Item.FileName := sFileName;
    Item.FilePath := sFilePath;
    Item.FileSize := nFileSize;
    Item.FileHash := sFileHash;
    Item.Version := 1;
    Item.CreateTime := Now;
    Item.UpdateTime := Now;
    Item.CompressType := COMPRESS_NONE;
    Item.CompressSize := 0;
    Item.AccessCount := 0;
    Item.LastAccess := Now;
    
    // 添加到索引
    FCriticalSection.Enter;
    try
      FIndexList.Add(Item);
      FHashIndex.AddObject(Item.FileHash, Item);
      FNameIndex.AddObject(UpperCase(Item.FileName), Item);
    finally
      FCriticalSection.Leave;
    end;
    
    Result := Item;
    WriteDebugLog('添加文件到索引: ' + sFileName);
    
  except
    on E: Exception do begin
      WriteLog('添加文件到索引失败: ' + E.Message, True);
      if Item <> nil then
        Item.Free;
    end;
  end;
  
  Query.Free;
end;

function TFileIndexManager.UpdateFile(Item: TFileIndexItem): Boolean;
var
  Query: TADOQuery;
begin
  Result := False;
  
  if Item = nil then
    Exit;
    
  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'UPDATE FileIndex SET ' +
      'FilePath = :FilePath, ' +
      'FileSize = :FileSize, ' +
      'FileHash = :FileHash, ' +
      'Version = :Version, ' +
      'UpdateTime = :UpdateTime, ' +
      'CompressType = :CompressType, ' +
      'CompressSize = :CompressSize ' +
      'WHERE FileId = :FileId';
    
    Query.Parameters.ParamByName('FilePath').Value := Item.FilePath;
    Query.Parameters.ParamByName('FileSize').Value := Item.FileSize;
    Query.Parameters.ParamByName('FileHash').Value := Item.FileHash;
    Query.Parameters.ParamByName('Version').Value := Item.Version;
    Query.Parameters.ParamByName('UpdateTime').Value := Item.UpdateTime;
    Query.Parameters.ParamByName('CompressType').Value := Item.CompressType;
    Query.Parameters.ParamByName('CompressSize').Value := Item.CompressSize;
    Query.Parameters.ParamByName('FileId').Value := Item.FileId;
    
    Query.ExecSQL;
    Result := True;
    
    WriteDebugLog('更新文件索引: ' + Item.FileName);
    
  except
    on E: Exception do begin
      WriteLog('更新文件索引失败: ' + E.Message, True);
    end;
  end;
  
  Query.Free;
end;

function TFileIndexManager.RemoveFile(const sFileName: string): Boolean;
var
  Query: TADOQuery;
  Item: TFileIndexItem;
  nIndex: Integer;
begin
  Result := False;
  
  Item := FindItemByName(sFileName);
  if Item = nil then
    Exit;
    
  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM FileIndex WHERE FileId = :FileId';
    Query.Parameters.ParamByName('FileId').Value := Item.FileId;
    Query.ExecSQL;
    
    // 从索引中移除
    FCriticalSection.Enter;
    try
      nIndex := FHashIndex.IndexOfObject(Item);
      if nIndex >= 0 then
        FHashIndex.Delete(nIndex);
        
      nIndex := FNameIndex.IndexOfObject(Item);
      if nIndex >= 0 then
        FNameIndex.Delete(nIndex);
        
      FIndexList.Remove(Item);
    finally
      FCriticalSection.Leave;
    end;
    
    Result := True;
    WriteDebugLog('移除文件索引: ' + sFileName);
    
  except
    on E: Exception do begin
      WriteLog('移除文件索引失败: ' + E.Message, True);
    end;
  end;
  
  Query.Free;
end;

function TFileIndexManager.FindFile(const sFileName: string): TFileIndexItem;
begin
  Result := FindItemByName(sFileName);
  
  if Result <> nil then begin
    Result.LastAccess := Now;
    Inc(Result.AccessCount);
  end;
end;

function TFileIndexManager.FindFile(const sFileName, sFileHash: string): TFileIndexItem;
begin
  Result := FindItemByName(sFileName);
  
  if (Result <> nil) and (sFileHash <> '') and (Result.FileHash <> sFileHash) then
    Result := nil; // 哈希不匹配
    
  if Result <> nil then begin
    Result.LastAccess := Now;
    Inc(Result.AccessCount);
  end;
end;

function TFileIndexManager.GetFileList(const sPattern: string): TList;
var
  i: Integer;
  Item: TFileIndexItem;
begin
  Result := TList.Create;
  
  FCriticalSection.Enter;
  try
    for i := 0 to FIndexList.Count - 1 do begin
      Item := TFileIndexItem(FIndexList[i]);
      if (sPattern = '') or (Pos(UpperCase(sPattern), UpperCase(Item.FileName)) > 0) then
        Result.Add(Item);
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

function TFileIndexManager.ScanDirectory(const sDirectory: string; bRecursive: Boolean): Integer;
var
  Scanner: TFileScanner;
begin
  Scanner := TFileScanner.Create(Self);
  try
    Result := Scanner.ScanDirectory(sDirectory, bRecursive);
    WriteLog('扫描目录完成: ' + sDirectory + ', 找到 ' + IntToStr(Result) + ' 个文件');
  finally
    Scanner.Free;
  end;
end;

function TFileIndexManager.RebuildIndex: Integer;
begin
  FCriticalSection.Enter;
  try
    FIndexList.Clear;
    FHashIndex.Clear;
    FNameIndex.Clear;
  finally
    FCriticalSection.Leave;
  end;
  
  // 清空数据库
  ExecuteSQL('DELETE FROM FileIndex');
  
  // 重新加载
  LoadFileIndex;
  BuildIndexes;
  
  Result := GetFileCount;
  WriteLog('重建文件索引完成，共 ' + IntToStr(Result) + ' 个文件');
end;

function TFileIndexManager.CleanupIndex: Integer;
var
  Query: TADOQuery;
  Item: TFileIndexItem;
  i: Integer;
  ItemsToRemove: TList;
begin
  Result := 0;
  ItemsToRemove := TList.Create;
  try
    FCriticalSection.Enter;
    try
      for i := 0 to FIndexList.Count - 1 do begin
        Item := TFileIndexItem(FIndexList[i]);
        if not FileExists(Item.FilePath) then
          ItemsToRemove.Add(Item);
      end;
    finally
      FCriticalSection.Leave;
    end;
    
    // 移除不存在的文件
    for i := 0 to ItemsToRemove.Count - 1 do begin
      Item := TFileIndexItem(ItemsToRemove[i]);
      if RemoveFile(Item.FileName) then
        Inc(Result);
    end;
    
  finally
    ItemsToRemove.Free;
  end;
  
  WriteLog('清理文件索引完成，移除 ' + IntToStr(Result) + ' 个无效文件');
end;

function TFileIndexManager.GetFileCount: Integer;
begin
  FCriticalSection.Enter;
  try
    Result := FIndexList.Count;
  finally
    FCriticalSection.Leave;
  end;
end;

function TFileIndexManager.GetTotalSize: Int64;
var
  i: Integer;
  Item: TFileIndexItem;
begin
  Result := 0;
  
  FCriticalSection.Enter;
  try
    for i := 0 to FIndexList.Count - 1 do begin
      Item := TFileIndexItem(FIndexList[i]);
      Result := Result + Item.FileSize;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

function TFileIndexManager.GetIndexInfo: string;
begin
  Result := Format('文件数: %d, 总大小: %s, 哈希索引: %d, 名称索引: %d',
    [GetFileCount, FormatBytes(GetTotalSize), FHashIndex.Count, FNameIndex.Count]);
end;

function TFileIndexManager.ExecuteSQL(const sSQL: string): Boolean;
var
  Query: TADOQuery;
begin
  Result := False;
  
  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := sSQL;
    Query.ExecSQL;
    Result := True;
  except
    on E: Exception do begin
      WriteLog('执行SQL失败: ' + E.Message, True);
    end;
  end;
  
  Query.Free;
end;

function TFileIndexManager.QuerySQL(const sSQL: string): TADOQuery;
begin
  Result := TADOQuery.Create(nil);
  Result.Connection := FConnection;
  Result.SQL.Text := sSQL;
  
  try
    Result.Open;
  except
    on E: Exception do begin
      WriteLog('查询SQL失败: ' + E.Message, True);
      Result.Free;
      Result := nil;
    end;
  end;
end;

// TFileScanner 实现

constructor TFileScanner.Create(AIndexManager: TFileIndexManager);
begin
  inherited Create;
  FIndexManager := AIndexManager;
  FRootPath := '';
  FFileCount := 0;
  FTotalSize := 0;
end;

function TFileScanner.ScanDirectory(const sRootPath: string; bRecursive: Boolean): Integer;
begin
  FRootPath := sRootPath;
  FFileCount := 0;
  FTotalSize := 0;
  
  if DirectoryExists(sRootPath) then begin
    ScanPath(sRootPath, bRecursive);
  end;
  
  Result := FFileCount;
end;

procedure TFileScanner.ScanPath(const sPath: string; bRecursive: Boolean);
var
  SearchRec: TSearchRec;
  sFullPath: string;
  sFileHash: string;
  nFileSize: Int64;
begin
  // 扫描文件
  if FindFirst(sPath + '\*.*', faAnyFile, SearchRec) = 0 then begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then begin
        sFullPath := sPath + '\' + SearchRec.Name;
        
        if not ShouldSkipFile(SearchRec.Name) then begin
          try
            nFileSize := SearchRec.Size;
            sFileHash := CalculateFileHash(sFullPath);
            
            if sFileHash <> '' then begin
              FIndexManager.AddFile(SearchRec.Name, sFullPath, nFileSize, sFileHash);
              Inc(FFileCount);
              FTotalSize := FTotalSize + nFileSize;
              
              if Assigned(FOnFileFound) then
                FOnFileFound(Self);
            end;
          except
            on E: Exception do begin
              WriteLog('扫描文件时出错: ' + sFullPath + ' - ' + E.Message, True);
            end;
          end;
        end;
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
  
  // 递归扫描子目录
  if bRecursive then begin
    if FindFirst(sPath + '\*.*', faDirectory, SearchRec) = 0 then begin
      repeat
        if ((SearchRec.Attr and faDirectory) <> 0) and 
           (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then begin
          ScanPath(sPath + '\' + SearchRec.Name, True);
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;
  end;
  
  if Assigned(FOnProgress) then
    FOnProgress(Self);
end;

function TFileScanner.CalculateFileHash(const sFilePath: string): string;
var
  FileStream: TFileStream;
  MD5Context: TMD5Context;
  MD5Digest: TMD5Digest;
begin
  Result := '';
  
  try
    FileStream := TFileStream.Create(sFilePath, fmOpenRead or fmShareDenyWrite);
    try
      MD5Init(MD5Context);
      
      // 分块读取文件计算MD5
      var Buffer: array[0..8191] of Byte;
      var BytesRead: Integer;
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
      WriteLog('计算文件哈希失败: ' + sFilePath + ' - ' + E.Message, True);
    end;
  end;
end;

function TFileScanner.ShouldSkipFile(const sFileName: string): Boolean;
var
  sExt: string;
begin
  Result := False;
  
  // 跳过系统文件和临时文件
  sExt := UpperCase(ExtractFileExt(sFileName));
  if (sExt = '.TMP') or (sExt = '.BAK') or (sExt = '.LOG') or
     (sExt = '.~') or (Pos('~', sFileName) > 0) then begin
    Result := True;
    Exit;
  end;
  
  // 跳过隐藏文件
  if (Length(sFileName) > 0) and (sFileName[1] = '.') then begin
    Result := True;
    Exit;
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
