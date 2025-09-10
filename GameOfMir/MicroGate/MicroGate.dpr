program MicroGate;

uses
  Forms,
  Windows,
  SysUtils,
  MicroGateMain in 'MicroGateMain.pas' {FrmMicroGate},
  MicroShare in 'MicroShare.pas',
  MicroClient in 'MicroClient.pas',
  MicroServer in 'MicroServer.pas',
  ResourceManager in 'ResourceManager.pas',
  DownloadManager in 'DownloadManager.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmMicroGate, FrmMicroGate);
  Application.Run;
end.
