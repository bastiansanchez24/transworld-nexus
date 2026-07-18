[Setup]
AppId={{E68BC201-9F31-48C7-9943-41A6673413E0}
AppName=NEXUS
AppVersion=1.0.0
AppPublisher=Transworld
DefaultDirName={autopf}\Transworld NEXUS
DefaultGroupName=Transworld NEXUS
OutputDir=.\build\windows\installer
OutputBaseFilename=Transworld_Nexus_Installer
SetupIconFile=.\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: ".\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Transworld Nexus"; Filename: "{app}\transworld_nexus.exe"
Name: "{autodesktop}\Transworld Nexus"; Filename: "{app}\transworld_nexus.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\transworld_nexus.exe"; Description: "{cm:LaunchProgram,Transworld Nexus}"; Flags: nowait postinstall skipifsilent
