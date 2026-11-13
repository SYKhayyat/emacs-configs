@echo off
rem Launch the hebrew profile, daemon-first. All the logic is in launch.cmd, once.
setlocal
set "ROOT=%~dp0.."
call "%ROOT%\bin\launch.cmd" hebrew %*
