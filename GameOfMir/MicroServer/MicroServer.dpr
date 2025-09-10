program MicroServer;

uses
  Forms,
  Windows,
  SysUtils,
  MicroServerMain in 'MicroServerMain.pas' {FrmMicroServer},
  MicroShare in '..\MicroGate\MicroShare.pas',
  FileIndexManager in 'FileIndexManager.pas',
  ResourceProvider in 'ResourceProvider.pas',
  PatchManager in 'PatchManager.pas',
  ServerEngine in 'ServerEngine.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmMicroServer, FrmMicroServer);
  Application.Run;
end.
