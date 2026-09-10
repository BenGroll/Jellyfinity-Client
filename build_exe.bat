@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Build Jellyfinity with the native Windows Flutter toolchain.
rem
rem   build_exe.bat                       release build
rem   build_exe.bat debug                 debug build
rem   build_exe.bat --clean --pub-get     clean and refresh dependencies
rem   set MODE=debug && build_exe.bat     debug build (also supports profile)
rem   set CLEAN=1 && build_exe.bat       run flutter clean first
rem   set PUB_GET=1 && build_exe.bat      refresh dependencies before building

cd /d "%~dp0"
if not exist "pubspec.yaml" (
  echo build_exe.bat: Flutter project root not found 1>&2
  exit /b 1
)

rem Optional arguments are convenient from Command Prompt and Explorer.
:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--clean" (
  set "CLEAN=1"
) else if /I "%~1"=="--pub-get" (
  set "PUB_GET=1"
) else if /I "%~1"=="release" (
  set "MODE=release"
) else if /I "%~1"=="debug" (
  set "MODE=debug"
) else if /I "%~1"=="profile" (
  set "MODE=profile"
) else (
  echo build_exe.bat: unknown argument "%~1" 1>&2
  exit /b 1
)
shift
goto parse_args

:args_done
if not defined MODE set "MODE=release"
if /I "%MODE%"=="release" (
  set "configuration=Release"
) else if /I "%MODE%"=="debug" (
  set "configuration=Debug"
) else if /I "%MODE%"=="profile" (
  set "configuration=Profile"
) else (
  echo build_exe.bat: MODE must be release, debug, or profile 1>&2
  exit /b 1
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo build_exe.bat: add Windows Flutter's bin directory to PATH 1>&2
  exit /b 1
)

set "branch=nogit"
set "sha=nogit"
set "dirty="
git rev-parse --git-dir >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%A in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set "branch=%%A"
  for /f "delims=" %%A in ('git rev-parse --short HEAD 2^>nul') do set "sha=%%A"
  for /f "delims=" %%A in ('git status --porcelain --untracked-files=normal 2^>nul') do set "dirty=-dirty"
)

rem Branch names may contain characters that are invalid in Windows paths.
set "JF_BRANCH=!branch!"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$s=$env:JF_BRANCH; $s=[regex]::Replace($s,'[^a-zA-Z0-9._-]','-'); $s.Substring(0,[Math]::Min(80,$s.Length))"`) do set "branch=%%A"
set "stamp=!branch!-!sha!!dirty!"

echo ==^> Jellyfinity Windows build
echo     tree : !stamp!
echo     mode : !MODE!
call flutter --version

rem Only check the clean command when it was actually requested. Flutter's
rem informational --version command may leave a nonzero status on some setups.
if /I "!CLEAN!"=="1" (
  call flutter clean
  if errorlevel 1 exit /b 1
)
if /I "!PUB_GET!"=="1" goto pub_get
if not exist ".dart_tool\package_config.json" goto pub_get
echo     deps : reusing .dart_tool\package_config.json (set PUB_GET=1 to refresh)
goto build

:pub_get
call flutter pub get
if errorlevel 1 exit /b 1

:build
echo.
echo ==^> flutter build windows --!MODE! --no-pub
call flutter build windows --!MODE! --no-pub
if errorlevel 1 exit /b 1

set "source_dir=build\windows\x64\runner\!configuration!"
if not exist "!source_dir!\jellyfinity.exe" (
  echo build_exe.bat: expected executable missing from !source_dir! 1>&2
  exit /b 1
)
if not exist "!source_dir!\flutter_windows.dll" (
  echo build_exe.bat: incomplete Windows runtime in !source_dir! 1>&2
  exit /b 1
)
if not exist "!source_dir!\data\" (
  echo build_exe.bat: incomplete Windows runtime in !source_dir! 1>&2
  exit /b 1
)

if not exist "build\exe" mkdir "build\exe"
set "destination=build\exe\jellyfinity-!stamp!-windows-x64-!MODE!-!RANDOM!"
mkdir "!destination!"
if errorlevel 1 exit /b 1
xcopy "!source_dir!\*" "!destination!\" /E /I /Y >nul
rem xcopy returns 1 when files were copied successfully; 2+ indicates an error.
if errorlevel 2 exit /b 1

echo.
echo ==^> Done. Run: !destination!\jellyfinity.exe
echo     Share the entire folder, including DLLs and data.
for %%A in ("!destination!\jellyfinity.exe") do echo     Size: %%~zA bytes
exit /b 0
