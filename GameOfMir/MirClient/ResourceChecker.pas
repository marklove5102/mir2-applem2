unit ResourceChecker;

interface

uses
  Windows, SysUtils, Classes, IniFiles, MicroClient;

type
  // 资源文件信息
  TResourceFileInfo = record
    FileName: string;
    FileSize: LongWord;
    FileHash: string;
    IsRequired: Boolean;
    LocalPath: string;
  end;

  // 资源检查器
  TResourceChecker = class
  private
    FResourceList: TList;
    FConfigFile: string;
    FClientPath: string;
    FMissingFiles: TStringList;
    FCorruptedFiles: TStringList;
    
    procedure LoadResourceConfig;
    procedure AddResourceFile(const sFileName: string; dwFileSize: LongWord; 
      const sFileHash: string; bRequired: Boolean; const sLocalPath: string = '');
    function CheckFileIntegrity(const ResourceInfo: TResourceFileInfo): Boolean;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Initialize(const sClientPath: string; const sConfigFile: string = 'Resources.ini');
    function CheckAllResources: Boolean;
    function DownloadMissingResources: Boolean;
    function GetMissingFileCount: Integer;
    function GetCorruptedFileCount: Integer;
    function GetMissingFileList: TStringList;
    function GetCorruptedFileList: TStringList;
    
    property ClientPath: string read FClientPath;
    property ConfigFile: string read FConfigFile;
  end;

// 全局资源检查器
var
  g_ResourceChecker: TResourceChecker;

// 工具函数
function InitializeResourceChecker: Boolean;
procedure FinalizeResourceChecker;
function CheckClientResources: Boolean;

implementation

uses
  Grobal2;

// TResourceChecker 实现

constructor TResourceChecker.Create;
begin
  inherited Create;
  FResourceList := TList.Create;
  FMissingFiles := TStringList.Create;
  FCorruptedFiles := TStringList.Create;
  FConfigFile := '';
  FClientPath := '';
end;

destructor TResourceChecker.Destroy;
var
  i: Integer;
  pResourceInfo: ^TResourceFileInfo;
begin
  // 清理资源列表
  for i := 0 to FResourceList.Count - 1 do begin
    pResourceInfo := FResourceList[i];
    Dispose(pResourceInfo);
  end;
  
  FResourceList.Free;
  FMissingFiles.Free;
  FCorruptedFiles.Free;
  inherited Destroy;
end;

procedure TResourceChecker.Initialize(const sClientPath: string; const sConfigFile: string);
begin
  FClientPath := sClientPath;
  if sConfigFile <> '' then
    FConfigFile := sConfigFile
  else
    FConfigFile := 'Resources.ini';
    
  // 确保配置文件路径是完整的
  if not FileExists(FConfigFile) then
    FConfigFile := FClientPath + FConfigFile;
    
  LoadResourceConfig;
  DebugOutStr('资源检查器初始化完成，配置文件: ' + FConfigFile);
end;

procedure TResourceChecker.LoadResourceConfig;
var
  IniFile: TIniFile;
  Sections: TStringList;
  Keys: TStringList;
  i, j: Integer;
  sSection, sKey: string;
  sFileName, sFileHash, sLocalPath: string;
  dwFileSize: LongWord;
  bRequired: Boolean;
begin
  // 清理现有资源列表
  for i := 0 to FResourceList.Count - 1 do
    Dispose(FResourceList[i]);
  FResourceList.Clear;
  
  if not FileExists(FConfigFile) then begin
    // 如果配置文件不存在，创建默认配置
    CreateDefaultResourceConfig;
    Exit;
  end;
  
  IniFile := TIniFile.Create(FConfigFile);
  Sections := TStringList.Create;
  Keys := TStringList.Create;
  try
    IniFile.ReadSections(Sections);
    
    for i := 0 to Sections.Count - 1 do begin
      sSection := Sections[i];
      if sSection = 'General' then
        Continue; // 跳过通用配置段
        
      Keys.Clear;
      IniFile.ReadSection(sSection, Keys);
      
      for j := 0 to Keys.Count - 1 do begin
        sKey := Keys[j];
        if sKey = 'FileName' then begin
          sFileName := IniFile.ReadString(sSection, 'FileName', '');
          dwFileSize := IniFile.ReadInteger(sSection, 'FileSize', 0);
          sFileHash := IniFile.ReadString(sSection, 'FileHash', '');
          bRequired := IniFile.ReadBool(sSection, 'Required', True);
          sLocalPath := IniFile.ReadString(sSection, 'LocalPath', '');
          
          if sFileName <> '' then
            AddResourceFile(sFileName, dwFileSize, sFileHash, bRequired, sLocalPath);
        end;
      end;
    end;
    
  finally
    Keys.Free;
    Sections.Free;
    IniFile.Free;
  end;
  
  DebugOutStr('加载资源配置完成，共 ' + IntToStr(FResourceList.Count) + ' 个文件');
end;

procedure TResourceChecker.CreateDefaultResourceConfig;
var
  IniFile: TIniFile;
begin
  IniFile := TIniFile.Create(FConfigFile);
  try
    // 通用配置
    IniFile.WriteString('General', 'Version', '1.0');
    IniFile.WriteString('General', 'Description', '客户端资源文件配置');
    
    // 核心资源文件
    IniFile.WriteString('CoreData', 'FileName', 'Data\Prguse.wil');
    IniFile.WriteInteger('CoreData', 'FileSize', 0);
    IniFile.WriteString('CoreData', 'FileHash', '');
    IniFile.WriteBool('CoreData', 'Required', True);
    IniFile.WriteString('CoreData', 'LocalPath', '');
    
    IniFile.WriteString('CoreData2', 'FileName', 'Data\Prguse2.wil');
    IniFile.WriteInteger('CoreData2', 'FileSize', 0);
    IniFile.WriteString('CoreData2', 'FileHash', '');
    IniFile.WriteBool('CoreData2', 'Required', True);
    IniFile.WriteString('CoreData2', 'LocalPath', '');
    
    IniFile.WriteString('CoreData3', 'FileName', 'Data\Prguse3.wil');
    IniFile.WriteInteger('CoreData3', 'FileSize', 0);
    IniFile.WriteString('CoreData3', 'FileHash', '');
    IniFile.WriteBool('CoreData3', 'Required', True);
    IniFile.WriteString('CoreData3', 'LocalPath', '');
    
    // 地图文件
    IniFile.WriteString('MapData', 'FileName', 'Map\*.map');
    IniFile.WriteInteger('MapData', 'FileSize', 0);
    IniFile.WriteString('MapData', 'FileHash', '');
    IniFile.WriteBool('MapData', 'Required', False);
    IniFile.WriteString('MapData', 'LocalPath', '');
    
    // 音效文件
    IniFile.WriteString('SoundData', 'FileName', 'Sound\*.wav');
    IniFile.WriteInteger('SoundData', 'FileSize', 0);
    IniFile.WriteString('SoundData', 'FileHash', '');
    IniFile.WriteBool('SoundData', 'Required', False);
    IniFile.WriteString('SoundData', 'LocalPath', '');
    
  finally
    IniFile.Free;
  end;
  
  DebugOutStr('创建默认资源配置文件: ' + FConfigFile);
end;

procedure TResourceChecker.AddResourceFile(const sFileName: string; dwFileSize: LongWord; 
  const sFileHash: string; bRequired: Boolean; const sLocalPath: string);
var
  pResourceInfo: ^TResourceFileInfo;
begin
  New(pResourceInfo);
  pResourceInfo.FileName := sFileName;
  pResourceInfo.FileSize := dwFileSize;
  pResourceInfo.FileHash := sFileHash;
  pResourceInfo.IsRequired := bRequired;
  
  if sLocalPath <> '' then
    pResourceInfo.LocalPath := sLocalPath
  else
    pResourceInfo.LocalPath := FClientPath + sFileName;
    
  FResourceList.Add(pResourceInfo);
end;

function TResourceChecker.CheckFileIntegrity(const ResourceInfo: TResourceFileInfo): Boolean;
var
  sActualHash: string;
  dwActualSize: LongWord;
begin
  Result := False;
  
  // 检查文件是否存在
  if not FileExists(ResourceInfo.LocalPath) then begin
    DebugOutStr('文件不存在: ' + ResourceInfo.LocalPath);
    Exit;
  end;
  
  // 检查文件大小（如果有预期值）
  if ResourceInfo.FileSize > 0 then begin
    dwActualSize := g_MicroClientManager.GetFileSize(ResourceInfo.LocalPath);
    if dwActualSize <> ResourceInfo.FileSize then begin
      DebugOutStr('文件大小不匹配: ' + ResourceInfo.FileName + 
                 ', 期望: ' + IntToStr(ResourceInfo.FileSize) + 
                 ', 实际: ' + IntToStr(dwActualSize));
      Exit;
    end;
  end;
  
  // 检查文件哈希（如果有预期值）
  if ResourceInfo.FileHash <> '' then begin
    sActualHash := g_MicroClientManager.CalculateFileHash(ResourceInfo.LocalPath);
    if sActualHash <> ResourceInfo.FileHash then begin
      DebugOutStr('文件哈希不匹配: ' + ResourceInfo.FileName + 
                 ', 期望: ' + ResourceInfo.FileHash + 
                 ', 实际: ' + sActualHash);
      Exit;
    end;
  end;
  
  Result := True;
end;

function TResourceChecker.CheckAllResources: Boolean;
var
  i: Integer;
  pResourceInfo: ^TResourceFileInfo;
  bAllValid: Boolean;
begin
  FMissingFiles.Clear;
  FCorruptedFiles.Clear;
  bAllValid := True;
  
  DebugOutStr('开始检查客户端资源文件...');
  
  for i := 0 to FResourceList.Count - 1 do begin
    pResourceInfo := FResourceList[i];
    
    if not FileExists(pResourceInfo.LocalPath) then begin
      // 文件不存在
      FMissingFiles.Add(pResourceInfo.FileName);
      if pResourceInfo.IsRequired then
        bAllValid := False;
      DebugOutStr('缺失文件: ' + pResourceInfo.FileName);
    end else if not CheckFileIntegrity(pResourceInfo^) then begin
      // 文件损坏
      FCorruptedFiles.Add(pResourceInfo.FileName);
      if pResourceInfo.IsRequired then
        bAllValid := False;
      DebugOutStr('损坏文件: ' + pResourceInfo.FileName);
    end;
  end;
  
  DebugOutStr('资源检查完成，缺失: ' + IntToStr(FMissingFiles.Count) + 
             ', 损坏: ' + IntToStr(FCorruptedFiles.Count));
  
  Result := bAllValid;
end;

function TResourceChecker.DownloadMissingResources: Boolean;
var
  i: Integer;
  sFileName: string;
  dwRequestId: LongWord;
  bAllDownloaded: Boolean;
begin
  Result := False;
  bAllDownloaded := True;
  
  if (g_MicroClientManager = nil) or not g_MicroClientManager.IsConnected then begin
    DebugOutStr('微端管理器未连接，无法下载资源');
    Exit;
  end;
  
  DebugOutStr('开始下载缺失的资源文件...');
  
  // 下载缺失的文件
  for i := 0 to FMissingFiles.Count - 1 do begin
    sFileName := FMissingFiles[i];
    dwRequestId := g_MicroClientManager.RequestResource(sFileName);
    
    if dwRequestId > 0 then begin
      DebugOutStr('请求下载: ' + sFileName + ', ID: ' + IntToStr(dwRequestId));
    end else begin
      DebugOutStr('请求下载失败: ' + sFileName);
      bAllDownloaded := False;
    end;
  end;
  
  // 下载损坏的文件
  for i := 0 to FCorruptedFiles.Count - 1 do begin
    sFileName := FCorruptedFiles[i];
    dwRequestId := g_MicroClientManager.RequestResource(sFileName);
    
    if dwRequestId > 0 then begin
      DebugOutStr('请求重新下载: ' + sFileName + ', ID: ' + IntToStr(dwRequestId));
    end else begin
      DebugOutStr('请求重新下载失败: ' + sFileName);
      bAllDownloaded := False;
    end;
  end;
  
  if bAllDownloaded and ((FMissingFiles.Count > 0) or (FCorruptedFiles.Count > 0)) then begin
    // 显示下载对话框
    g_MicroClientManager.ShowDownloadDialog;
  end;
  
  Result := bAllDownloaded;
end;

function TResourceChecker.GetMissingFileCount: Integer;
begin
  Result := FMissingFiles.Count;
end;

function TResourceChecker.GetCorruptedFileCount: Integer;
begin
  Result := FCorruptedFiles.Count;
end;

function TResourceChecker.GetMissingFileList: TStringList;
begin
  Result := FMissingFiles;
end;

function TResourceChecker.GetCorruptedFileList: TStringList;
begin
  Result := FCorruptedFiles;
end;

// 全局函数实现

function InitializeResourceChecker: Boolean;
begin
  Result := False;
  
  if g_ResourceChecker <> nil then begin
    Result := True;
    Exit;
  end;
  
  try
    g_ResourceChecker := TResourceChecker.Create;
    g_ResourceChecker.Initialize(ExtractFilePath(ParamStr(0)));
    Result := True;
    DebugOutStr('资源检查器初始化成功');
  except
    on E: Exception do begin
      DebugOutStr('初始化资源检查器失败: ' + E.Message);
    end;
  end;
end;

procedure FinalizeResourceChecker;
begin
  if g_ResourceChecker <> nil then begin
    g_ResourceChecker.Free;
    g_ResourceChecker := nil;
    DebugOutStr('资源检查器已清理');
  end;
end;

function CheckClientResources: Boolean;
var
  bResourcesValid: Boolean;
  nMissingCount, nCorruptedCount: Integer;
  sMessage: string;
begin
  Result := True;
  
  if g_ResourceChecker = nil then begin
    DebugOutStr('资源检查器未初始化');
    Exit;
  end;
  
  // 检查所有资源
  bResourcesValid := g_ResourceChecker.CheckAllResources;
  nMissingCount := g_ResourceChecker.GetMissingFileCount;
  nCorruptedCount := g_ResourceChecker.GetCorruptedFileCount;
  
  if not bResourcesValid then begin
    sMessage := '检测到资源文件问题：' + #13#10;
    
    if nMissingCount > 0 then
      sMessage := sMessage + '缺失文件: ' + IntToStr(nMissingCount) + ' 个' + #13#10;
      
    if nCorruptedCount > 0 then
      sMessage := sMessage + '损坏文件: ' + IntToStr(nCorruptedCount) + ' 个' + #13#10;
      
    sMessage := sMessage + #13#10 + '是否使用微端系统自动下载缺失的资源？';
    
    if Application.MessageBox(PChar(sMessage), '资源检查', MB_YESNO + MB_ICONQUESTION) = IDYES then begin
      // 连接微端网关并下载资源
      if (g_MicroClientManager <> nil) and not g_MicroClientManager.IsConnected then begin
        if g_MicroClientManager.Connect('127.0.0.1', 7200) then begin
          DebugOutStr('已连接到微端网关');
        end else begin
          Application.MessageBox('连接微端网关失败，请检查网络连接或联系管理员。', '连接失败', MB_ICONERROR);
          Result := False;
          Exit;
        end;
      end;
      
      // 开始下载
      if g_ResourceChecker.DownloadMissingResources then begin
        DebugOutStr('资源下载请求已发送');
        Result := True; // 允许继续启动，下载在后台进行
      end else begin
        Application.MessageBox('下载资源失败，请检查网络连接或联系管理员。', '下载失败', MB_ICONERROR);
        Result := False;
      end;
    end else begin
      // 用户选择不下载，询问是否继续
      if Application.MessageBox('不下载资源可能导致游戏运行异常，是否仍要继续？', '确认', MB_YESNO + MB_ICONWARNING) = IDYES then begin
        Result := True;
      end else begin
        Result := False;
      end;
    end;
  end else begin
    DebugOutStr('所有资源文件检查通过');
  end;
end;

initialization
  g_ResourceChecker := nil;

finalization
  FinalizeResourceChecker;

end.
