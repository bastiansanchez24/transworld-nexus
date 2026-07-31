; Instalador bootstrap de Nexus.
; No empaqueta binarios: descarga la última versión desde GitHub Releases.
; Compilar: .\scripts\build-installer.ps1  (requiere Inno Setup 6+)

#define MyAppName "Nexus"
#define MyAppPublisher "Transworld"
#define MyUninstallKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\{E68BC201-9F31-48C7-9943-41A6673413E0}_is1"

[Setup]
AppId={{E68BC201-9F31-48C7-9943-41A6673413E0}
AppName={#MyAppName}
AppVersion=0.0.0
AppPublisher={#MyAppPublisher}
UninstallDisplayName={#MyAppName}
DefaultDirName={localappdata}\Nexus
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableFinishedPage=yes
OutputDir=.\build\windows\installer
OutputBaseFilename=NexusSetup
SetupIconFile=.\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={localappdata}\Nexus\transworld_nexus.exe

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "scripts\install-nexus.ps1"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "scripts\uninstall-nexus.ps1"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "{code:GetInstallParameters}"; StatusMsg: "Descargando e instalando la última versión de Nexus..."; Flags: waituntilterminated

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{localappdata}\Nexus\uninstall-nexus.ps1"""; Flags: waituntilterminated runascurrentuser; RunOnceId: "UninstallNexus"

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\Transworld\Nexus"
Type: filesandordirs; Name: "{userappdata}\Transworld\Transworld Nexus"
Type: filesandordirs; Name: "{userdocs}\leads_pendientes"
Type: filesandordirs; Name: "{localappdata}\Nexus"
Type: filesandordirs; Name: "{localappdata}\Transworld NEXUS"

[Code]
function ReadInstalledVersion(): String;
var
  Lines: TStringList;
  Path: String;
begin
  Result := '';
  Path := ExpandConstant('{localappdata}\Nexus\.nexus-version');
  if not FileExists(Path) then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path);
    if Lines.Count > 0 then
      Result := Trim(Lines[0]);
  finally
    Lines.Free;
  end;
end;

procedure ParseVersionParts(const Version: String; var Major, Minor, Patch: Integer);
var
  P1, P2: Integer;
  S: String;
begin
  Major := 0;
  Minor := 0;
  Patch := 0;
  S := Version;
  P1 := Pos('.', S);
  if P1 = 0 then
  begin
    Major := StrToIntDef(S, 0);
    Exit;
  end;
  Major := StrToIntDef(Copy(S, 1, P1 - 1), 0);
  Delete(S, 1, P1);
  P2 := Pos('.', S);
  if P2 = 0 then
  begin
    Minor := StrToIntDef(S, 0);
    Exit;
  end;
  Minor := StrToIntDef(Copy(S, 1, P2 - 1), 0);
  Patch := StrToIntDef(Copy(S, P2 + 1, MaxInt), 0);
end;

procedure ApplyInstalledVersionToRegistry();
var
  Version: String;
  Major, Minor, Patch: Integer;
begin
  Version := ReadInstalledVersion();
  if Version = '' then
    Exit;
  if not RegKeyExists(HKEY_CURRENT_USER, '{#MyUninstallKey}') then
    Exit;

  ParseVersionParts(Version, Major, Minor, Patch);
  RegWriteStringValue(HKEY_CURRENT_USER, '{#MyUninstallKey}', 'DisplayVersion', Version);
  RegWriteStringValue(HKEY_CURRENT_USER, '{#MyUninstallKey}', 'DisplayName', '{#MyAppName}');
  RegWriteDWordValue(HKEY_CURRENT_USER, '{#MyUninstallKey}', 'VersionMajor', Major);
  RegWriteDWordValue(HKEY_CURRENT_USER, '{#MyUninstallKey}', 'VersionMinor', Minor);
  RegWriteDWordValue(HKEY_CURRENT_USER, '{#MyUninstallKey}', 'Version', (Major shl 16) or Minor);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
    WizardForm.Hide;
  if CurStep = ssPostInstall then
    ApplyInstalledVersionToRegistry();
end;

procedure DeinitializeSetup();
begin
  { Inno crea la entrada de desinstalación después del script [Run]. }
  ApplyInstalledVersionToRegistry();
end;

function GetInstallParameters(Param: String): String;
begin
  Result := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{tmp}\install-nexus.ps1') + '" -InstallDir "' + ExpandConstant('{localappdata}\Nexus') + '" -Launch -SkipUninstallRegistry';
  if WizardIsTaskSelected('desktopicon') then
    Result := Result + ' -DesktopShortcut';
end;
