; Inno Setup Script for Skylight Wallet
; This script creates a Windows installer with a setup wizard.
;
; Usage (from project root):
;   iscc /DAppVersion=1.0.0 windows/installer.iss
;
; Requirements:
;   - Inno Setup 6.x (https://jrsoftware.org/isinfo.php)
;   - Flutter Windows build must exist at build\windows\x64\runner\Release\

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "Skylight Wallet"
#define AppPublisher "MAGIC Grants"
#define AppURL "https://github.com/MagicGrants/skylight-wallet"
#define AppExeName "skylight_wallet.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
AppId={{E8F4B2A1-7D3C-4E5F-9A1B-2C3D4E5F6A7B}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir=Output
OutputBaseFilename=skylight-wallet-v{#AppVersion}-x64-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
WizardImageFile=installer_banner.bmp
WizardSmallImageFile=installer_icon.bmp
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
CloseApplicationsFilter=*.exe
RestartApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main application files from Flutter build
Source: "..\build\windows\x64\runner\Release\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function IsAppRunning(const ExeName: string): Boolean;
var
  WMIService: Variant;
  ProcessList: Variant;
begin
  Result := False;
  try
    WMIService := CreateOleObject('WbemScripting.SWbemLocator');
    WMIService := WMIService.ConnectServer('.', 'root\cimv2');
    ProcessList := WMIService.ExecQuery('SELECT * FROM Win32_Process WHERE Name = ''' + ExeName + '''');
    Result := (ProcessList.Count > 0);
  except
    Result := False;
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
  if IsAppRunning('{#AppExeName}') then
  begin
    MsgBox('{#AppName} is currently running.' + #13#10 + #13#10 +
           'Please close the application before uninstalling.', mbError, MB_OK);
    Result := False;
  end;
end;
