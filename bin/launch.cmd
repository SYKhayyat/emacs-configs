@echo off
rem Launch a profile, daemon-first. Windows twin of launch.sh; see that file
rem for why a daemon is worth it.
setlocal
set "ROOT=%~dp0.."
set "PROFILE=%~1"
shift
if "%PROFILE%"=="" goto usage
set "SERVER=emacs-%PROFILE%"

emacsclient -s "%SERVER%" --eval t >nul 2>&1
if not errorlevel 1 goto client

start "" emacs --init-directory="%ROOT%\configs\%PROFILE%" --daemon="%SERVER%"
rem Wait for it to answer rather than sleeping a guessed interval.
set /a i=0
:wait
timeout /t 1 /nobreak >nul
emacsclient -s "%SERVER%" --eval t >nul 2>&1
if not errorlevel 1 goto client
set /a i+=1
if %i% lss 30 goto wait
echo daemon for %PROFILE% started but never answered 1>&2
exit /b 5

:client
emacsclient -s "%SERVER%" -c %*
exit /b %errorlevel%

:usage
echo usage: launch.cmd ^<hebrew^|notes^|ide^> [file ...] 1>&2
exit /b 2
