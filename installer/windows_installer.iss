#define AppName "Мензулка"
#define AppVersion "1.17.0"
#define AppExe "menzulka.exe"

[Setup]
AppId={{7C3D6B2A-5E1F-4A3B-9C7D-2E8F1A6B4C90}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Menzulka
DefaultDirName={autopf}\Menzulka
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=Menzulka_Setup_{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Лицензия приложения и уведомления о сторонних компонентах (MPL-2.0 и др.)
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  // Ключ деинсталлятора в реестре: AppId_is1
  UninstallKey =
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{7C3D6B2A-5E1F-4A3B-9C7D-2E8F1A6B4C90}_is1';

var
  ModePage: TWizardPage;
  ModeRadios: array[0..3] of TNewRadioButton;
  ModeHints: array[0..3] of TNewStaticText;
  // 0 — установить, 1 — обновить, 2 — чистая установка, 3 — удалить
  InstallMode: Integer;
  InstalledVersion: String;

function GetUninstallExe(var ExePath: String): Boolean;
var
  S: String;
begin
  Result := False;
  if RegQueryStringValue(HKLM, UninstallKey, 'UninstallString', S) or
     RegQueryStringValue(HKCU, UninstallKey, 'UninstallString', S) then
  begin
    S := RemoveQuotes(S);
    if S <> '' then
    begin
      ExePath := S;
      Result := True;
    end;
  end;
end;

function IsAppInstalled: Boolean;
var
  S: String;
begin
  Result := GetUninstallExe(S);
end;

function ReadInstalledVersion: String;
var
  S: String;
begin
  S := '';
  if RegQueryStringValue(HKLM, UninstallKey, 'DisplayVersion', S) or
     RegQueryStringValue(HKCU, UninstallKey, 'DisplayVersion', S) then
    Result := S
  else
    Result := '';
end;

{ Запускает штатный деинсталлятор и ждёт его завершения. }
function UninstallOldVersion: Boolean;
var
  ExePath: String;
  Code: Integer;
begin
  Result := False;
  if not GetUninstallExe(ExePath) then
    Exit;
  if not FileExists(ExePath) then
    Exit;
  if Exec(ExePath, '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES',
      ExtractFileDir(ExePath), SW_HIDE, ewWaitUntilTerminated, Code) then
    Result := (Code = 0);
end;

function SelectedMode: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to 3 do
    if ModeRadios[I].Checked then
    begin
      Result := I;
      Exit;
    end;
end;

procedure AddHint(Index, ATop: Integer; const Text: String);
begin
  ModeHints[Index] := TNewStaticText.Create(ModePage);
  with ModeHints[Index] do
  begin
    Parent := ModePage.Surface;
    Left := 28;
    Top := ATop;
    Width := ModePage.SurfaceWidth - 34;
    AutoSize := False;
    Height := 16;
    Caption := Text;
    Font.Color := clGray;
  end;
end;

procedure AddMode(Index, ATop: Integer; const ACaption, AHint: String);
begin
  ModeRadios[Index] := TNewRadioButton.Create(ModePage);
  with ModeRadios[Index] do
  begin
    Parent := ModePage.Surface;
    Left := 8;
    Top := ATop;
    Width := ModePage.SurfaceWidth - 16;
    Height := 22;
    Caption := ACaption;
  end;
  AddHint(Index, ATop + 22, AHint);
end;

procedure InitializeWizard;
var
  Description: String;
begin
  InstalledVersion := ReadInstalledVersion;

  if IsAppInstalled then
  begin
    if InstalledVersion <> '' then
      Description := 'На компьютере установлена версия ' + InstalledVersion +
        '. Выберите, что сделать.'
    else
      Description := 'На компьютере уже установлена программа. Выберите, что сделать.';
  end
  else
    Description := 'Программа ещё не установлена. Выберите, что сделать.';

  ModePage := CreateCustomPage(wpWelcome, 'Режим установки', Description);

  AddMode(0, 2, 'Установить',
    'обычная установка; если программа уже есть — файлы заменятся');
  AddMode(1, 48, 'Обновить',
    'поверх установленной версии, настройки и данные сохраняются');
  AddMode(2, 94, 'Чистая установка (сначала удалить старую версию)',
    'сначала удаляется предыдущая версия, затем ставится новая');
  AddMode(3, 140, 'Удалить программу',
    'только удалить приложение, ничего не устанавливать');

  // По умолчанию: если уже стоит — «Обновить», иначе — «Установить».
  if IsAppInstalled then
    ModeRadios[1].Checked := True
  else
    ModeRadios[0].Checked := True;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID <> ModePage.ID then
    Exit;

  InstallMode := SelectedMode;

  if InstallMode = 3 then
  begin
    if MsgBox('Удалить «{#AppName}» с этого компьютера?', mbConfirmation,
        MB_YESNO) = IDYES then
    begin
      if IsAppInstalled then
      begin
        if UninstallOldVersion then
          MsgBox('Программа удалена.', mbInformation, MB_OK)
        else
          MsgBox('Не удалось запустить деинсталлятор. Удалите программу через '
            + '«Параметры → Приложения».', mbError, MB_OK);
      end
      else
        MsgBox('Установленная программа не найдена.', mbInformation, MB_OK);
      Result := False;
      WizardForm.Close;
    end
    else
      Result := False;
    Exit;
  end;

  if (InstallMode = 1) and not IsAppInstalled then
    MsgBox('Установленная версия не найдена — будет выполнена обычная установка.',
      mbInformation, MB_OK);

  if (InstallMode = 2) and not IsAppInstalled then
    MsgBox('Предыдущая версия не найдена — будет выполнена обычная установка.',
      mbInformation, MB_OK);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if (InstallMode = 2) and IsAppInstalled then
  begin
    if not UninstallOldVersion then
      Result := 'Не удалось удалить предыдущую версию. Установка отменена.';
  end;
end;
