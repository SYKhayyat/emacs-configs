@echo off
rem Launch the notes profile, daemon-first. All the logic is in launch.cmd, once.
setlocal
set "ROOT=%~dp0.."
call "%ROOT%\bin\launch.cmd" notes %*
