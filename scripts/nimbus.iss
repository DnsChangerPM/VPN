#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif
#ifndef BuildDir
#define BuildDir "..\build\windows\x64\runner\Release"
#endif

#define MyAppName "Nimbus VPN"
#define MyAppPublisher "DnsChangerPM"
#define MyAppURL "https://github.com/DnsChangerPM/VPN"
#define MyAppExeName "nimbus.exe"

[Setup]
AppId={{9C2E1B6A-7F44-4C1E-9A11-A7B8C9D0E1F2}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\Nimbus VPN
DefaultGroupName=Nimbus VPN
DisableProgramGroupPage=yes
OutputDir=..\release
OutputBaseFilename=Nimbus-VPN-v{#MyAppVersion}-Windows-x64-Installer
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
MinVersion=6.3.9600
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
