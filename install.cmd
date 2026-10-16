@echo off
rem install.cmd — обёртка для Windows: находит sh.exe от Git for Windows
rem и запускает install.sh. Все аргументы передаются в install.sh как есть.
rem Можно запускать двойным кликом или из cmd/PowerShell.
setlocal

rem Пауза в конце нужна только при запуске двойным кликом из проводника.
set "HOLD="
if "%~1"=="" if not "%cmdcmdline%"=="%cmdcmdline:install.cmd=%" set "HOLD=1"

rem Консоль cmd по умолчанию в cp866, а скрипты печатают UTF-8 —
rem переключаем кодовую страницу и возвращаем прежнюю в конце.
set "CP="
for /f "tokens=2 delims=:" %%c in ('chcp') do set "CP=%%c"
set "CP=%CP: =%"
set "CP=%CP:.=%"
chcp 65001 >nul

set "SH="
if exist "%ProgramFiles%\Git\bin\sh.exe" set "SH=%ProgramFiles%\Git\bin\sh.exe"
if not defined SH if exist "%ProgramFiles(x86)%\Git\bin\sh.exe" set "SH=%ProgramFiles(x86)%\Git\bin\sh.exe"
if not defined SH if exist "%LocalAppData%\Programs\Git\bin\sh.exe" set "SH=%LocalAppData%\Programs\Git\bin\sh.exe"

if not defined SH (
  echo ОШИБКА: не найден sh.exe от Git for Windows.
  echo Установите Git ^(https://git-scm.com/download/win^) или запустите install.sh из git-bash.
  if defined CP chcp %CP% >nul
  if defined HOLD pause
  exit /b 1
)

set "DIR=%~dp0"
set "DIR=%DIR:\=/%"

"%SH%" "%DIR%install.sh" %*
set "RC=%ERRORLEVEL%"

if defined CP chcp %CP% >nul
if defined HOLD pause
exit /b %RC%
