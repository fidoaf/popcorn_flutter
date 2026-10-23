#ifndef ReleaseDir
  #define ReleaseDir SourcePath + "..\build\windows\x64\runner\Release"
#endif
#ifndef VcRuntimeDir
  #error Pass /DVcRuntimeDir pointing to the x64 Microsoft.VC143.CRT redistributable directory.
#endif
#define AppVersion GetStringFileInfo(ReleaseDir + "\popcorn_flutter.exe", "ProductVersion")

[Setup]
AppId={{27B28F6A-1058-4D5B-86A9-81B01583D235}
AppName=Popcorn
AppVersion={#AppVersion}
AppPublisher=Com a casa en cap lloc
DefaultDirName={localappdata}\Programs\Popcorn
DefaultGroupName=Popcorn
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=..\build\installer
OutputBaseFilename=Popcorn-{#AppVersion}-Windows-x64-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\popcorn_flutter.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
ChangesAssociations=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Excludes: "*.pdb,AppxManifest.xml,resources.pri"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#VcRuntimeDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "stop_local_server.ps1"; Flags: dontcopy

[Icons]
Name: "{userprograms}\Popcorn"; Filename: "{app}\popcorn_flutter.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\Popcorn"; Filename: "{app}\popcorn_flutter.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Classes\com.comacasaencaplloc.popcorn-flutter"; ValueType: string; ValueData: "URL:Popcorn authentication"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\com.comacasaencaplloc.popcorn-flutter"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\com.comacasaencaplloc.popcorn-flutter\DefaultIcon"; ValueType: string; ValueData: """{app}\popcorn_flutter.exe"",0"
Root: HKCU; Subkey: "Software\Classes\com.comacasaencaplloc.popcorn-flutter\shell\open\command"; ValueType: string; ValueData: """{app}\popcorn_flutter.exe"" ""%1"""

[Run]
Filename: "{app}\popcorn_flutter.exe"; Description: "{cm:LaunchProgram,Popcorn}"; Flags: nowait postinstall skipifsilent

[Code]
function StopBundledPlayerServer: String;
var
  ResultCode: Integer;
  ScriptPath, Parameters, PowerShellPath: String;
begin
  Result := '';
  if not FileExists(ExpandConstant('{app}\local_server\node.exe')) then
    exit;

  ExtractTemporaryFile('stop_local_server.ps1');
  ScriptPath := ExpandConstant('{tmp}\stop_local_server.ps1');
  PowerShellPath := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
  Parameters := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + ScriptPath + '" "' + ExpandConstant('{app}') + '"';
  if not Exec(PowerShellPath, Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := 'Could not start PowerShell to stop Popcorn''s local player server.';
    exit;
  end;
  if ResultCode <> 0 then
    Result := 'Could not stop Popcorn''s local player server. Close Popcorn and retry.';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := StopBundledPlayerServer;
end;
