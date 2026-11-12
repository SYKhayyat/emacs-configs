@echo off
rem Tangle + byte-compile the literate config. Windows twin of bin/build.sh.
setlocal
set "ROOT=%~dp0.."
emacs -Q --batch -l "%ROOT%\bin\build.el" -- %*
