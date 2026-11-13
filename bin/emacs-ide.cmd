@echo off
rem Launch the ide profile, daemon-first. All the logic is in launch.cmd, once.
setlocal
set "ROOT=%~dp0.."
call "%ROOT%\bin\launch.cmd" ide %*
