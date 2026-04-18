@echo off
setlocal enabledelayedexpansion

REM ===== CONFIG =====
set APP_NAME=MyFlutterApp
set PUBLISHER=Your Name
set INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe

REM ===== PATHS =====
set PROJECT_DIR=%cd%
set BUILD_DIR=build\windows\x64\runner\Release
set OUTPUT_DIR=installer_output
set ISS_FILE=installer.iss
set PUBSPEC=pubspec.yaml

echo.
echo ===== Flutter Windows Installer Builder =====
echo.

REM ===== CHECK INNO SETUP =====
if not exist "%INNO_PATH%" (
    echo ERROR: Inno Setup not found at:
    echo %INNO_PATH%
    echo Install Inno Setup or fix the path.
    exit /b 1
)

REM ===== GET VERSION FROM PUBSPEC =====
for /f "tokens=2 delims=: " %%a in ('findstr /b "version:" %PUBSPEC%') do (
    set RAW_VERSION=%%a
)

REM Remove build metadata (after +)
for /f "tokens=1 delims=+" %%a in ("%RAW_VERSION%") do (
    set APP_VERSION=%%a
)

echo Detected version: %APP_VERSION%

REM ===== BUILD FLUTTER =====
echo.
echo Building Flutter Windows release...
flutter clean
flutter pub get
flutter build windows

if errorlevel 1 (
    echo ERROR: Flutter build failed.
    exit /b 1
)

REM ===== FIND EXE =====
set EXE_FILE=
for %%f in (%BUILD_DIR%\*.exe) do (
    set EXE_FILE=%%~nxf
)

if "%EXE_FILE%"=="" (
    echo ERROR: No .exe found in build folder.
    exit /b 1
)

echo Found executable: %EXE_FILE%

REM ===== CREATE OUTPUT DIR =====
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM ===== GENERATE INNO SCRIPT =====
echo.
echo Generating installer script...

(
echo [Setup]
echo AppName=%APP_NAME%
echo AppVersion=%APP_VERSION%
echo AppPublisher=%PUBLISHER%
echo DefaultDirName={pf}\%APP_NAME%
echo DefaultGroupName=%APP_NAME%
echo OutputDir=%OUTPUT_DIR%
echo OutputBaseFilename=%APP_NAME%_%APP_VERSION%_Setup
echo Compression=lzma
echo SolidCompression=yes
echo ArchitecturesInstallIn64BitMode=x64
echo WizardStyle=modern
echo
echo [Files]
echo Source: "%BUILD_DIR%\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs
echo
echo [Icons]
echo Name: "{group}\%APP_NAME%"; Filename: "{app}\%EXE_FILE%"
echo Name: "{autodesktop}\%APP_NAME%"; Filename: "{app}\%EXE_FILE%"
echo
echo [Run]
echo Filename: "{app}\%EXE_FILE%"; Description: "Launch %APP_NAME%"; Flags: nowait postinstall skipifsilent
) > %ISS_FILE%

REM ===== COMPILE INSTALLER =====
echo.
echo Building installer...
"%INNO_PATH%" %ISS_FILE%

if errorlevel 1 (
    echo ERROR: Installer build failed.
    exit /b 1
)

echo.
echo SUCCESS 🎉
echo Installer created in: %OUTPUT_DIR%
echo.

pause