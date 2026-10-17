; =====================================================================
; Sınıf360 / Akıllı Tahta Kilit Sistemi - Profesyonel Kurulum Scripti
; Sürüm: 2.1.1 | Yayıncı: Emre Can ARDIÇ
; =====================================================================

#define MyAppName "Sınıf360 Akıllı Tahta Kilit Sistemi"
#define MyAppVersion "2.1.1"
#define MyAppPublisher "Emre Can ARDIÇ"
#define MyAppExeName "KioskLockApp.exe"
#define MyWatchdogExeName "WatchdogService.exe"
#define MyRepairExeName "TahtaRepair.exe"
#define MyUpdaterExeName "TahtaUpdater.exe"

[Setup]
AppId={{A3B982A3-CD89-4361-8FB7-89DA4109EF89}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

; 64-Bit Yerel Desteği (Windows 10/11 x64 akıllı tahtalar için)
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; KURULUM YERİ: ProgramData klasörü (C:\ProgramData\AkilliTahtaKilitSistemi)
DefaultDirName={commonappdata}\AkilliTahtaKilitSistemi
DefaultGroupName={#MyAppName}

; Kurulum sırasında "İleri" tuşuna basmayı gerektiren tüm ekranları iptal ediyoruz (Sessiz ve Hızlı Kurulum)
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableFinishedPage=yes

; ProgramData'ya yazabilmek ve başlangıç kancası atabilmek için yönetici izni gereklidir
PrivilegesRequired=admin
OutputDir=userdocs:Inno Setup Output Files
OutputBaseFilename=Sinif360_v2.1.1_Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName} Kaldır

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Dirs]
Name: "{app}"; Permissions: users-full

[Files]
Source: "C:\Projeler\AkilliTahtaSistemi\dist\v2.1.1_publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Permissions: users-full

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Registry]
; BAŞLANGIÇ (Tüm Kullanıcılar - HKLM): Hem ana kilit hem bekçi servisi başlangıca eklenir
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "AkilliTahtaKilitSistemi"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "AkilliTahtaWatchdog"; ValueData: """{app}\{#MyWatchdogExeName}"""; Flags: uninsdeletevalue

; BAŞLANGIÇ (Geçerli Kullanıcı - HKCU): Watchdog ve Kiosk güvenliği için kullanıcı kancası
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "AkilliTahtaKilitSistemi"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue

[Run]
; Kurulum tamamlandığında önce bekçi servisini, ardından kilit uygulamasını arka planda başlatır
Filename: "{app}\{#MyWatchdogExeName}"; Flags: nowait; Description: "Bekçi Servisini Başlat"
Filename: "{app}\{#MyAppExeName}"; Flags: nowait postinstall; Description: "Sınıf360 Kilit Sistemini Başlat"

[Code]
var
  DownloadPage: TDownloadWizardPage;

// .NET 8 Desktop Runtime kontrolü (64-bit ve 32-bit Program Files yollarını doğru kontrol eder)
function IsDotNet8Installed(): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;
  // 64-bit yerel Program Files kontrolü
  if FindFirst(ExpandConstant('{commonpf64}\dotnet\shared\Microsoft.WindowsDesktop.App\8.0.*'), FindRec) then
  begin
    Result := True;
    FindClose(FindRec);
  end
  // Standart Program Files fallback kontrolü
  else if FindFirst(ExpandConstant('{commonpf}\dotnet\shared\Microsoft.WindowsDesktop.App\8.0.*'), FindRec) then
  begin
    Result := True;
    FindClose(FindRec);
  end;
end;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), nil);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  // Kuruluma başlamadan önce çalışan eski tüm süreçleri (TahtaRepair dahil) zorla kapat
  Exec('cmd.exe', '/c taskkill /f /im {#MyAppExeName} /im {#MyWatchdogExeName} /im {#MyUpdaterExeName} /im {#MyRepairExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // Eğer .NET 8 Desktop Runtime x64 yüklü değilse otomatik indirip kur
  if not IsDotNet8Installed() then
  begin
    DownloadPage.Clear;
    // Güvenilir doğrudan Microsoft CDN indirme bağlantısı (Yönlendirme takılmalarını önler)
    DownloadPage.Add('https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/8.0.32/windowsdesktop-runtime-8.0.32-win-x64.exe', 'dotnet8_desktop_runtime_x64.exe', '');
    DownloadPage.Show;
    try
      try
        DownloadPage.Download;
        // /passive anahtarı ile kullanıcıya net bir ilerleme çubuğu gösterilir, sessizce tamamlanır
        Exec(ExpandConstant('{tmp}\dotnet8_desktop_runtime_x64.exe'), '/install /passive /norestart', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
      except
        // İndirme başarısız olursa PowerShell TLS1.2 ile doğrudan yedek indirme dene
        Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile(''https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/8.0.32/windowsdesktop-runtime-8.0.32-win-x64.exe'', ''' + ExpandConstant('{tmp}\dotnet8_desktop_runtime_x64.exe') + ''')"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
        Exec(ExpandConstant('{tmp}\dotnet8_desktop_runtime_x64.exe'), '/install /passive /norestart', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
      end;
    finally
      DownloadPage.Hide;
    end;

    // Kurulum sonrası son kontrol
    if not IsDotNet8Installed() then
    begin
      Result := '.NET 8 Masaüstü Çalışma Zamanı (Desktop Runtime x64) kurulamadı. Lütfen internet bağlantınızı kontrol edip kurulumu tekrar çalıştırın.';
    end;
  end;
end;

// Kaldırma işlemi için yönetici şifre onay formu
function GetUninstallPassword(out EnteredPassword: String): Boolean;
var
  PassForm: TForm;
  PromptLabel: TLabel;
  PassEdit: TEdit;
  OKButton, CancelButton: TButton;
begin
  Result := False;
  PassForm := TForm.Create(nil);
  try
    PassForm.Caption := 'Sınıf360 Kaldırma Güvenliği';
    PassForm.ClientWidth := 350;
    PassForm.ClientHeight := 130;
    PassForm.Position := poScreenCenter;
    PassForm.BorderStyle := bsDialog;

    PromptLabel := TLabel.Create(PassForm);
    PromptLabel.Parent := PassForm;
    PromptLabel.Left := 16;
    PromptLabel.Top := 16;
    PromptLabel.Width := 318;
    PromptLabel.WordWrap := True;
    PromptLabel.Caption := 'Sistemi bilgisayardan tamamen kaldırmak için yönetici şifresini girmelisiniz:';

    PassEdit := TEdit.Create(PassForm);
    PassEdit.Parent := PassForm;
    PassEdit.Left := 16;
    PassEdit.Top := PromptLabel.Top + PromptLabel.Height + 12;
    PassEdit.Width := 318;
    PassEdit.PasswordChar := '*'; 

    OKButton := TButton.Create(PassForm);
    OKButton.Parent := PassForm;
    OKButton.Width := 85;
    OKButton.Height := 25;
    OKButton.Left := PassForm.ClientWidth - 16 - OKButton.Width - 8 - OKButton.Width;
    OKButton.Top := PassForm.ClientHeight - 16 - OKButton.Height;
    OKButton.Caption := 'Tamam';
    OKButton.ModalResult := mrOk;
    OKButton.Default := True;

    CancelButton := TButton.Create(PassForm);
    CancelButton.Parent := PassForm;
    CancelButton.Width := 85;
    CancelButton.Height := 25;
    CancelButton.Left := PassForm.ClientWidth - 16 - CancelButton.Width;
    CancelButton.Top := OKButton.Top;
    CancelButton.Caption := 'İptal';
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;

    PassForm.ActiveControl := PassEdit;

    if PassForm.ShowModal() = mrOk then
    begin
      EnteredPassword := PassEdit.Text;
      Result := True;
    end;
  finally
    PassForm.Free;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    Exec('cmd.exe', '/c icacls "' + ExpandConstant('{app}') + '" /grant *S-1-5-32-545:(OI)(CI)F /T /C /Q', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

function InitializeUninstall(): Boolean;
var
  InputPass: String;
begin
  Result := False;
  if GetUninstallPassword(InputPass) then
  begin
    if InputPass = '821620' then
      Result := True
    else
      MsgBox('Hatalı şifre girdiniz! Kaldırma işlemi güvenlik sebebiyle iptal edildi.', mbError, MB_OK);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    // 1. ADIM: Kaldırma başlarken tüm kilit ve kurtarma süreçlerini kapat
    Exec('cmd.exe', '/c taskkill /f /im {#MyAppExeName} /im {#MyWatchdogExeName} /im {#MyUpdaterExeName} /im {#MyRepairExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    // 2. ADIM: Eşleştirme ve okul ayarlarını Registry'den kaldır
    RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\SmartBoardLock');
    RegDeleteKeyIncludingSubkeys(HKEY_LOCAL_MACHINE, 'Software\SmartBoardLock');
  end;

  if CurUninstallStep = usPostUninstall then
  begin
    // 3. ADIM: Başlangıç (Autostart) kayıtlarını temizle
    RegDeleteValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'AkilliTahtaKilitSistemi');
    RegDeleteValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'AkilliTahtaWatchdog');
    RegDeleteValue(HKEY_CURRENT_USER, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'AkilliTahtaKilitSistemi');
    RegDeleteValue(HKEY_CURRENT_USER, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'AkilliTahtaWatchdog');

    // 4. ADIM: Sonradan oluşan log, afiş, temp zip dosyalarını ve klasörü tamamen temizle
    DelTree(ExpandConstant('{app}'), True, True, True);
  end;
end;
