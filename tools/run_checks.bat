@echo off
rem Elaris checks: headless smoke test, then a windowed screenshot tour.
rem
rem   tools\run_checks.bat             both
rem   tools\run_checks.bat --no-shots  smoke test only (no window)
rem
rem Output goes to tools\out\ (import.log, smoke.log, tour.log, screenshots\).
rem Set GODOT_EXE to use a different engine binary.
setlocal

if "%GODOT_EXE%"=="" set "GODOT_EXE=C:\Users\Akos\Desktop\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe"
set "PROJECT=%~dp0.."
set "OUT=%~dp0out"
if not exist "%OUT%" mkdir "%OUT%"
type nul > "%OUT%\.gdignore"

if not exist "%GODOT_EXE%" (
	echo [checks] Godot not found at "%GODOT_EXE%". Set GODOT_EXE.
	exit /b 2
)

set RESULT=0

rem New PNGs and new class_name scripts do not exist for the engine until they are
rem imported. The editor does this on its own; a command-line run has to ask.
echo [checks] import, headless...
"%GODOT_EXE%" --headless --path "%PROJECT%" --import > "%OUT%\import.log" 2>&1

echo [checks] smoke test, headless...
"%GODOT_EXE%" --headless --path "%PROJECT%" --script res://tools/smoke_test.gd > "%OUT%\smoke.log" 2>&1
if errorlevel 1 set RESULT=1
findstr /C:"[SMOKE] FAIL" /C:"[SMOKE] known" /C:"[SMOKE]   " /C:"[SMOKE] ---" /C:"passed," /C:"[SMOKE] RESULT" "%OUT%\smoke.log"
findstr /C:"[SMOKE] RESULT: PASS" "%OUT%\smoke.log" >nul
if errorlevel 1 set RESULT=1
findstr /C:"SCRIPT ERROR" "%OUT%\smoke.log" >nul
if not errorlevel 1 (
	echo [checks] FAIL: script errors during the smoke test:
	findstr /C:"SCRIPT ERROR" "%OUT%\smoke.log"
	set RESULT=1
)

if "%~1"=="--no-shots" goto finish

echo [checks] screenshot tour, opens a window for about half a minute...
"%GODOT_EXE%" --path "%PROJECT%" --resolution 1920x1080 --script res://tools/screenshot_tour.gd > "%OUT%\tour.log" 2>&1
if errorlevel 1 set RESULT=1
findstr /C:"[TOUR] done" "%OUT%\tour.log"
if errorlevel 1 (
	echo [checks] FAIL: the screenshot tour did not finish, see tools\out\tour.log
	set RESULT=1
)
findstr /C:"SCRIPT ERROR" "%OUT%\tour.log" >nul
if not errorlevel 1 (
	echo [checks] FAIL: script errors during the tour:
	findstr /C:"SCRIPT ERROR" "%OUT%\tour.log"
	set RESULT=1
)

:finish
if "%RESULT%"=="0" (echo [checks] ALL PASSED) else (echo [checks] FAILED - see tools\out\)
exit /b %RESULT%
