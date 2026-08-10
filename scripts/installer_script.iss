; Instalador bootstrap de RegisPro (Inno Setup nativo).
; Descarga la última release desde GitHub, sin PowerShell.
; Requiere Inno Setup 6.1+ (CreateDownloadPage).
; Compilar: .\scripts\build-installer.ps1

#define MyAppName "RegisPro"
#define MyAppPublisher "Transworld"
#define MyAppExeName "transworld_nexus.exe"
#define MyRepoOwner "bastiansanchez24"
#define MyRepoName "transworld_project_nexus"
#define MyUninstallKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\{E68BC201-9F31-48C7-9943-41A6673413E0}_is1"

[Setup]
AppId={{E68BC201-9F31-48C7-9943-41A6673413E0}
AppName={#MyAppName}
AppVersion=0.0.0
AppPublisher={#MyAppPublisher}
UninstallDisplayName={#MyAppName}
DefaultDirName={localappdata}\RegisPro
DefaultGroupName={#MyAppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableFinishedPage=no
AllowNoIcons=yes
OutputDir=..\build\windows\installer
OutputBaseFilename=RegisProSetup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
CloseApplications=yes
CloseApplicationsFilter=*.exe,*.dll
RestartApplications=no
MinVersion=10.0

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Messages]
spanish.SetupAppTitle=RegisPro
spanish.SetupWindowTitle=RegisPro — Instalador
spanish.WelcomeLabel1=Bienvenido a RegisPro
spanish.WelcomeLabel2=Este asistente descargará e instalará automáticamente la última versión de RegisPro desde GitHub.%n%nNo se requieren privilegios de administrador.%n%nPulsa Siguiente para continuar.
spanish.ClickNext=Pulsa Siguiente para empezar la instalación automática.
spanish.ReadyLabel1=Listo para instalar RegisPro
spanish.ReadyLabel2a=Se consultará GitHub Releases, se descargará el paquete Windows y se instalará en tu perfil de usuario.
spanish.FinishedHeadingLabel=RegisPro quedó instalado
spanish.FinishedLabelNoIcons=RegisPro se instaló correctamente en tu equipo.
spanish.FinishedLabel=RegisPro se instaló correctamente en tu equipo.

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Opciones adicionales:"; Flags: unchecked

[Files]
; Paquete resuelto en tiempo de instalación (descarga + extracción en [Code]).
; Debe coincidir con GPayloadDir (= {tmp}\regispro-payload).
Source: "{tmp}\regispro-payload\*"; DestDir: "{app}"; Flags: external recursesubdirs createallsubdirs ignoreversion
Source: "uninstall-regispro.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir RegisPro"; Flags: nowait postinstall skipifsilent; WorkingDir: "{app}"

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\uninstall-regispro.ps1"" -InstallDir ""{app}"""; Flags: waituntilterminated runascurrentuser; RunOnceId: "UninstallRegisPro"

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\Transworld\RegisPro"
Type: filesandordirs; Name: "{userappdata}\Transworld\Nexus"
Type: filesandordirs; Name: "{userappdata}\Transworld\Transworld Nexus"
Type: filesandordirs; Name: "{userdocs}\leads_pendientes"
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{localappdata}\Nexus"
Type: filesandordirs; Name: "{localappdata}\Transworld NEXUS"

[Code]
const
  AppExeName = '{#MyAppExeName}';
  RepoOwner = '{#MyRepoOwner}';
  RepoName = '{#MyRepoName}';

var
  DownloadPage: TDownloadWizardPage;
  ProgressPage: TOutputProgressWizardPage;
  GPayloadDir: String;
  GInstalledVersion: String;
  GPayloadReady: Boolean;
  GLastError: String;

function StripVersionTag(const Tag: String): String;
begin
  Result := Trim(Tag);
  if (Length(Result) > 0) and ((Result[1] = 'v') or (Result[1] = 'V')) then
    Delete(Result, 1, 1);
end;

function JsonUnescape(const S: String): String;
begin
  Result := S;
  StringChangeEx(Result, '\/', '/', True);
  StringChangeEx(Result, '\n', #10, True);
  StringChangeEx(Result, '\"', '"', True);
  StringChangeEx(Result, '\\', '\', True);
end;

function JsonGetStringFrom(const Json, Key: String; StartAt: Integer): String;
var
  Needle, Rest: String;
  P, I, StartPos, Base: Integer;
  InEscape: Boolean;
begin
  Result := '';
  if StartAt < 1 then
    Base := 1
  else
    Base := StartAt;
  if Base > Length(Json) then
    Exit;

  Needle := '"' + Key + '"';
  P := Pos(Needle, Copy(Json, Base, MaxInt));
  if P = 0 then
    Exit;

  Rest := Copy(Json, Base + P - 1 + Length(Needle), MaxInt);
  I := 1;
  while (I <= Length(Rest)) and (Rest[I] <= ' ') do
    Inc(I);
  if (I > Length(Rest)) or (Rest[I] <> ':') then
    Exit;
  Inc(I);
  while (I <= Length(Rest)) and (Rest[I] <= ' ') do
    Inc(I);
  if (I > Length(Rest)) or (Rest[I] <> '"') then
    Exit;

  Inc(I);
  StartPos := I;
  InEscape := False;
  while I <= Length(Rest) do
  begin
    if InEscape then
      InEscape := False
    else if Rest[I] = '\' then
      InEscape := True
    else if Rest[I] = '"' then
    begin
      Result := JsonUnescape(Copy(Rest, StartPos, I - StartPos));
      Exit;
    end;
    Inc(I);
  end;
end;

function JsonGetString(const Json, Key: String): String;
begin
  Result := JsonGetStringFrom(Json, Key, 1);
end;

function IsWindowsAppZip(const Name: String): Boolean;
var
  LowerName: String;
begin
  LowerName := LowerCase(Name);
  Result :=
    ((Pos('windows-regispro-', LowerName) = 1) or
     (Pos('windows-nexus-', LowerName) = 1)) and
    (Length(LowerName) > 4) and
    (Copy(LowerName, Length(LowerName) - 3, 4) = '.zip');
end;

function NormalizeSha256(const Digest: String): String;
var
  S: String;
begin
  Result := '';
  S := Trim(Digest);
  if Pos('sha256:', LowerCase(S)) = 1 then
    Delete(S, 1, 7);
  S := LowerCase(Trim(S));
  if (Length(S) = 64) then
    Result := S;
end;

function TryReadAssetAtNameKey(const Json: String; NameKeyPos: Integer;
  var AssetName, AssetUrl, AssetSha: String): Boolean;
begin
  Result := False;
  AssetName := JsonGetStringFrom(Json, 'name', NameKeyPos);
  if (AssetName = '') or (not IsWindowsAppZip(AssetName)) then
    Exit;
  { GitHub coloca digest y browser_download_url después de name en el objeto asset. }
  AssetUrl := JsonGetStringFrom(Json, 'browser_download_url', NameKeyPos);
  AssetSha := NormalizeSha256(JsonGetStringFrom(Json, 'digest', NameKeyPos));
  if AssetUrl = '' then
    Exit;
  Result := True;
end;

function ResolveWindowsZipAsset(const Json, Version: String;
  var AssetName, AssetUrl, AssetSha: String): Boolean;
var
  ExactRegisPro, ExactLegacy, LowerJson, Needle: String;
  SearchFrom, FoundPos, AbsPos: Integer;
  CandName, CandUrl, CandSha: String;
  FirstName, FirstUrl, FirstSha: String;
  LegacyName, LegacyUrl, LegacySha: String;
  HaveFirst, HaveLegacy: Boolean;
begin
  Result := False;
  AssetName := '';
  AssetUrl := '';
  AssetSha := '';
  ExactRegisPro := 'windows-regispro-v' + Version + '.zip';
  ExactLegacy := 'windows-nexus-v' + Version + '.zip';
  HaveFirst := False;
  HaveLegacy := False;

  LowerJson := LowerCase(Json);
  Needle := '"name"';
  SearchFrom := 1;
  while SearchFrom <= Length(LowerJson) do
  begin
    FoundPos := Pos(Needle, Copy(LowerJson, SearchFrom, MaxInt));
    if FoundPos = 0 then
      Break;
    AbsPos := SearchFrom + FoundPos - 1;
    if TryReadAssetAtNameKey(Json, AbsPos, CandName, CandUrl, CandSha) then
    begin
      if CompareText(CandName, ExactRegisPro) = 0 then
      begin
        AssetName := CandName;
        AssetUrl := CandUrl;
        AssetSha := CandSha;
        Result := True;
        Exit;
      end;
      if (not HaveLegacy) and (CompareText(CandName, ExactLegacy) = 0) then
      begin
        LegacyName := CandName;
        LegacyUrl := CandUrl;
        LegacySha := CandSha;
        HaveLegacy := True;
      end;
      if not HaveFirst then
      begin
        FirstName := CandName;
        FirstUrl := CandUrl;
        FirstSha := CandSha;
        HaveFirst := True;
      end;
    end;
    SearchFrom := AbsPos + Length(Needle);
  end;

  if HaveLegacy then
  begin
    AssetName := LegacyName;
    AssetUrl := LegacyUrl;
    AssetSha := LegacySha;
    Result := True;
    Exit;
  end;

  if HaveFirst then
  begin
    AssetName := FirstName;
    AssetUrl := FirstUrl;
    AssetSha := FirstSha;
    Result := True;
  end;
end;

function HttpGetText(const Url: String): String;
var
  Http: Variant;
  Status: Integer;
begin
  Result := '';
  Http := CreateOleObject('WinHttp.WinHttpRequest.5.1');
  Http.Open('GET', Url, False);
  Http.SetRequestHeader('Accept', 'application/vnd.github+json');
  Http.SetRequestHeader('User-Agent', 'RegisPro-Installer');
  Http.SetRequestHeader('X-GitHub-Api-Version', '2022-11-28');
  Http.SetTimeouts(30000, 30000, 30000, 300000);
  Http.Send;
  Status := Http.Status;
  if Status = 404 then
    RaiseException('No hay Releases publicados en el repositorio de GitHub.');
  if (Status = 403) or (Status = 429) then
    RaiseException('Límite de la API de GitHub alcanzado. Reintenta más tarde.');
  if Status <> 200 then
    RaiseException('No se pudo consultar GitHub Releases (HTTP ' + IntToStr(Status) + ').');
  Result := Http.ResponseText;
end;

function ResolvePayloadRoot(const ExtractDir: String): String;
var
  FindRec: TFindRec;
  OnlyDir: String;
  Entries: Integer;
begin
  Result := ExtractDir;
  if FileExists(AddBackslash(ExtractDir) + AppExeName) then
    Exit;

  Entries := 0;
  OnlyDir := '';
  if FindFirst(AddBackslash(ExtractDir) + '*', FindRec) then
  try
    repeat
      if (FindRec.Name = '.') or (FindRec.Name = '..') then
        Continue;
      Inc(Entries);
      if FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0 then
        OnlyDir := AddBackslash(ExtractDir) + FindRec.Name
      else
        OnlyDir := '';
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;

  if (Entries = 1) and (OnlyDir <> '') and
     FileExists(AddBackslash(OnlyDir) + AppExeName) then
    Result := OnlyDir;
end;

procedure CopyDirectory(const SourceDir, DestDir: String);
var
  FindRec: TFindRec;
  SourcePath, DestPath: String;
begin
  ForceDirectories(DestDir);
  if not FindFirst(AddBackslash(SourceDir) + '*', FindRec) then
    Exit;
  try
    repeat
      if (FindRec.Name = '.') or (FindRec.Name = '..') then
        Continue;
      SourcePath := AddBackslash(SourceDir) + FindRec.Name;
      DestPath := AddBackslash(DestDir) + FindRec.Name;
      if FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0 then
        CopyDirectory(SourcePath, DestPath)
      else if not CopyFile(SourcePath, DestPath, False) then
        RaiseException('No se pudo copiar: ' + FindRec.Name);
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;

function ExtractZipArchive(const ZipPath, DestDir: String): Boolean;
var
  ResultCode: Integer;
  TarPath, Params: String;
begin
  Result := False;
  if DirExists(DestDir) then
    DelTree(DestDir, True, True, True);
  ForceDirectories(DestDir);

  TarPath := ExpandConstant('{sys}\tar.exe');
  if not FileExists(TarPath) then
    TarPath := 'tar.exe';

  Params := '-xf "' + ZipPath + '" -C "' + DestDir + '"';
  if not Exec(TarPath, Params, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    RaiseException('No se encontró tar.exe para extraer el paquete.');
  if ResultCode <> 0 then
    RaiseException('Falló la extracción del paquete (tar código ' + IntToStr(ResultCode) + ').');
  Result := True;
end;

procedure WriteInstalledVersionFile(const Version: String);
var
  Path: String;
begin
  Path := ExpandConstant('{app}\.regispro-version');
  if not SaveStringToFile(Path, Trim(Version), False) then
    Log('Aviso: no se pudo escribir .regispro-version');
end;

procedure RemoveLegacyDirIfDifferent(const LegacyDir: String);
begin
  if CompareText(LegacyDir, ExpandConstant('{app}')) = 0 then
    Exit;
  if DirExists(LegacyDir) then
  begin
    Log('Eliminando instalación legacy: ' + LegacyDir);
    DelTree(LegacyDir, True, True, True);
  end;
end;

procedure RemoveLegacyInstallArtifacts;
var
  LegacyStartMenu, Desktop, Shortcut: String;
begin
  RemoveLegacyDirIfDifferent(ExpandConstant('{localappdata}\Nexus'));
  RemoveLegacyDirIfDifferent(ExpandConstant('{localappdata}\Transworld NEXUS'));

  LegacyStartMenu := ExpandConstant('{userprograms}\Transworld NEXUS');
  if DirExists(LegacyStartMenu) then
    DelTree(LegacyStartMenu, True, True, True);
  LegacyStartMenu := ExpandConstant('{userprograms}\Nexus');
  if DirExists(LegacyStartMenu) then
    DelTree(LegacyStartMenu, True, True, True);

  Desktop := ExpandConstant('{autodesktop}');
  Shortcut := AddBackslash(Desktop) + 'Transworld NEXUS.lnk';
  if FileExists(Shortcut) then
    DeleteFile(Shortcut);
  Shortcut := AddBackslash(Desktop) + 'Nexus.lnk';
  if FileExists(Shortcut) then
    DeleteFile(Shortcut);

  if RegKeyExists(HKEY_CURRENT_USER,
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{E68BC201-9F31-48C7-9943-41A6673413E0}') then
  begin
    RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER,
      'Software\Microsoft\Windows\CurrentVersion\Uninstall\{E68BC201-9F31-48C7-9943-41A6673413E0}');
  end;
end;

function ReadInstalledVersion(): String;
var
  Lines: TStringList;
  Path: String;
begin
  Result := '';
  Path := ExpandConstant('{app}\.regispro-version');
  if not FileExists(Path) then
    Path := ExpandConstant('{app}\.nexus-version');
  if not FileExists(Path) then
    Path := ExpandConstant('{localappdata}\RegisPro\.regispro-version');
  if not FileExists(Path) then
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
  Version := GInstalledVersion;
  if Version = '' then
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

function DownloadAndPreparePayload: Boolean;
var
  ApiUrl, Json, Tag, Version: String;
  AssetName, AssetUrl, AssetSha: String;
  ZipPath, StagingDir, PayloadRoot: String;
begin
  Result := False;
  GLastError := '';
  GPayloadReady := False;
  GInstalledVersion := '';

  ApiUrl := 'https://api.github.com/repos/' + RepoOwner + '/' + RepoName + '/releases/latest';
  ZipPath := ExpandConstant('{tmp}\regispro-windows.zip');
  StagingDir := ExpandConstant('{tmp}\regispro-staging');
  GPayloadDir := ExpandConstant('{tmp}\regispro-payload');

  if FileExists(ZipPath) then
    DeleteFile(ZipPath);
  if DirExists(StagingDir) then
    DelTree(StagingDir, True, True, True);
  if DirExists(GPayloadDir) then
    DelTree(GPayloadDir, True, True, True);

  ProgressPage.SetText('Consultando GitHub Releases...', ApiUrl);
  ProgressPage.SetProgress(0, 0);
  ProgressPage.Show;
  try
    try
      Json := HttpGetText(ApiUrl);
      Tag := JsonGetString(Json, 'tag_name');
      if Tag = '' then
        RaiseException('La respuesta de GitHub no incluye tag_name.');
      Version := StripVersionTag(Tag);
      if Version = '' then
        RaiseException('No se pudo interpretar la versión del release.');

      if not ResolveWindowsZipAsset(Json, Version, AssetName, AssetUrl, AssetSha) then
        RaiseException(
          'El release ' + Tag +
          ' no incluye un ZIP de Windows (windows-regispro-v*.zip).');

      GInstalledVersion := Version;
      Log('Release=' + Tag + ' Asset=' + AssetName + ' Sha=' + AssetSha);
    except
      GLastError := GetExceptionMessage;
      ProgressPage.Hide;
      Result := False;
      Exit;
    end;
  finally
    ProgressPage.Hide;
  end;

  DownloadPage.Clear;
  DownloadPage.Add(AssetUrl, 'regispro-windows.zip', AssetSha);
  DownloadPage.Show;
  try
    try
      DownloadPage.Download;
    except
      if DownloadPage.AbortedByUser then
        GLastError := 'Descarga cancelada.'
      else
        GLastError := GetExceptionMessage;
      Result := False;
      Exit;
    end;
  finally
    DownloadPage.Hide;
  end;

  ProgressPage.SetText('Extrayendo paquete...', AssetName);
  ProgressPage.SetProgress(1, 3);
  ProgressPage.Show;
  try
    try
      ExtractZipArchive(ZipPath, StagingDir);
      ProgressPage.SetProgress(2, 3);
      PayloadRoot := ResolvePayloadRoot(StagingDir);
      if not FileExists(AddBackslash(PayloadRoot) + AppExeName) then
        RaiseException('El paquete no contiene ' + AppExeName + '.');
      CopyDirectory(PayloadRoot, GPayloadDir);
      ProgressPage.SetProgress(3, 3);
      if not FileExists(AddBackslash(GPayloadDir) + AppExeName) then
        RaiseException('No se pudo preparar el directorio de instalación.');
      GPayloadReady := True;
      Result := True;
    except
      GLastError := GetExceptionMessage;
      Result := False;
    end;
  finally
    ProgressPage.Hide;
    if FileExists(ZipPath) then
      DeleteFile(ZipPath);
    if DirExists(StagingDir) then
      DelTree(StagingDir, True, True, True);
  end;
end;

procedure InitializeWizard;
begin
  GPayloadDir := ExpandConstant('{tmp}\regispro-payload');
  GPayloadReady := False;
  GInstalledVersion := '';
  GLastError := '';

  DownloadPage := CreateDownloadPage(
    'Descargando RegisPro',
    'Obteniendo la última versión desde GitHub Releases...',
    nil);
  DownloadPage.ShowBaseNameInsteadOfUrl := True;

  ProgressPage := CreateOutputProgressPage(
    'Preparando RegisPro',
    'Esto puede tardar unos segundos...');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpReady then
  begin
    Result := DownloadAndPreparePayload;
    if not Result then
    begin
      if GLastError = '' then
        GLastError := 'No se pudo preparar la instalación.';
      SuppressibleMsgBox(AddPeriod(GLastError), mbCriticalError, MB_OK, IDOK);
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  NeedsRestart := False;
  Result := '';
  if GPayloadReady then
    Exit;
  if not DownloadAndPreparePayload then
  begin
    if GLastError <> '' then
      Result := GLastError
    else
      Result := 'No se pudo preparar la instalación.';
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if GInstalledVersion <> '' then
      WriteInstalledVersionFile(GInstalledVersion);
    RemoveLegacyInstallArtifacts;
    ApplyInstalledVersionToRegistry;
  end;
end;

procedure DeinitializeSetup();
begin
  ApplyInstalledVersionToRegistry();
end;
