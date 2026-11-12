@echo off
setlocal
set "ROOT=%~dp0.."
emacs --init-directory="%ROOT%\configs\notes" %*
