; Inno Setup script for Web Watch Companion. Built by tools/build-installer.ps1,
; which stages everything under dist\stage first and passes /DAppVersion=...

#define AppName "Web Watch Companion"
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Never change AppId: it is how upgrades and the uninstaller find this install.
AppId={{A3351D83-DB3D-4B16-83E3-38F693F8722E}
AppName={#AppName}
AppVersion={#AppVersion}
; Per-user install (no admin prompt): {autopf} resolves to %LOCALAPPDATA%\Programs.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=WebWatchCompanion-Setup-{#AppVersion}
SetupIconFile=..\assets\tray.ico
UninstallDisplayIcon={app}\assets\tray.ico
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "autostart"; Description: "Iniciar {#AppName} con Windows"

[Files]
Source: "..\dist\stage\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
; Start Menu entry (this is what Windows search finds) and optional autostart.
Name: "{autoprograms}\{#AppName}"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\tray\launch.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\assets\tray.ico"
Name: "{userstartup}\{#AppName}"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\tray\launch.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\assets\tray.ico"; Tasks: autostart

[Run]
Filename: "{sys}\wscript.exe"; Parameters: """{app}\tray\launch.vbs"""; WorkingDir: "{app}"; Description: "Iniciar {#AppName} ahora"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Runs before any file is removed, so a running copy doesn't lock node.exe.
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\tray\stop.ps1"""; Flags: runhidden waituntilterminated; RunOnceId: "StopApp"

[UninstallDelete]
; Logs live outside {app} so upgrades don't touch them; remove them on uninstall.
Type: filesandordirs; Name: "{localappdata}\WebWatchCompanion"

[Code]
// Stop a running copy (server + tray) so its files aren't locked when upgrading
// over an existing install (same {app}). Uninstall does the same via [UninstallRun].
procedure StopApp();
var
  Script: String;
  ResultCode: Integer;
begin
  Script := ExpandConstant('{app}\tray\stop.ps1');
  if FileExists(Script) then
  begin
    // Full path: a bare "powershell.exe" is not reliably found from a 32-bit installer.
    if Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
        '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + Script + '"',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      Log('stop.ps1 finished, exit code ' + IntToStr(ResultCode))
    else
      Log('stop.ps1 could not be started: ' + SysErrorMessage(ResultCode));
  end
  else
    Log('stop.ps1 not found at ' + Script);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  StopApp();
  Result := '';
end;
