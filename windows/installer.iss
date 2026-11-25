; Moveable Windows 설치 프로그램 (Inno Setup 6)
;   iscc /DAppVersion=1.3.0 windows\installer.iss   →  dist\Moveable-Setup.exe
; 관리자 권한 없이 현재 사용자에게 설치한다 (%LOCALAPPDATA%\Programs\Moveable).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6E3B1C52-8F0A-4C6B-9D47-3A1F2B9C7E15}
AppName=Moveable
AppVersion={#AppVersion}
AppVerName=Moveable {#AppVersion}
AppPublisher=Moveable
AppPublisherURL=https://github.com/Neil-Jung/moveable
AppSupportURL=https://github.com/Neil-Jung/moveable/issues
AppUpdatesURL=https://neil-jung.github.io/moveable/
VersionInfoVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\Moveable
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.15063
OutputDir=..\dist
OutputBaseFilename=Moveable-Setup
SetupIconFile=moveable.ico
UninstallDisplayIcon={app}\Moveable.exe
UninstallDisplayName=Moveable
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
CloseApplications=no

#if FileExists(CompilerPath + "Languages\Korean.isl")
  #define HasKorean
#endif

[Languages]
#ifdef HasKorean
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
#endif
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
#ifdef HasKorean
korean.StartupTask=Windows 시작 시 자동 실행
korean.LaunchNow=지금 Moveable 실행
#endif
english.StartupTask=Start Moveable when Windows starts
english.LaunchNow=Launch Moveable now

[Tasks]
Name: "startup"; Description: "{cm:StartupTask}"

[Files]
Source: "..\build\Release\Moveable.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{userprograms}\Moveable"; Filename: "{app}\Moveable.exe"

[Registry]
; 앱 트레이 메뉴의 "Windows 시작 시 자동 실행"과 같은 값을 쓴다
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Moveable"; ValueData: """{app}\Moveable.exe"""; Tasks: startup

[Run]
Filename: "{app}\Moveable.exe"; Description: "{cm:LaunchNow}"; Flags: nowait postinstall skipifsilent

[Code]
procedure StopMoveable();
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM Moveable.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  StopMoveable();  { 업데이트할 때 실행 중인 이전 버전 종료 }
  Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    StopMoveable();
  if CurUninstallStep = usPostUninstall then
  begin
    { 자동 실행 항목과 설정(속도 등) 정리 }
    RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Moveable');
    RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\Moveable');
  end;
end;
