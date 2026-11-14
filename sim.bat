@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "GHDLFLAGS=--std=08 -frelaxed"
set "WORKDIR=work"

where ghdl >nul 2>&1
if errorlevel 1 (
  echo [BLAD] Nie znaleziono ghdl w PATH.
  echo Zainstaluj GHDL i dodaj katalog bin do PATH.
  echo Instrukcja: docs\TUTORIAL_TESTOWANIE.md
  exit /b 1
)

if not exist "%WORKDIR%" mkdir "%WORKDIR%"

echo [1/3] Analiza VHDL...
ghdl -a %GHDLFLAGS% --workdir=%WORKDIR% ^
  vhdl\ask_types_pkg.vhd ^
  vhdl\cordic_pkg.vhd ^
  vhdl\cos_unit.vhd ^
  vhdl\sqrt_unit.vhd ^
  vhdl\atan_unit.vhd ^
  vhdl\arccos_unit.vhd ^
  vhdl\memory.vhd ^
  vhdl\math_subprogram.vhd ^
  vhdl\main.vhd ^
  vhdl\tb_main.vhd
if errorlevel 1 exit /b 1

echo [2/3] Elaboracja tb_main...
ghdl -e %GHDLFLAGS% --workdir=%WORKDIR% tb_main
if errorlevel 1 exit /b 1

echo [3/3] Symulacja...
ghdl -r %GHDLFLAGS% --workdir=%WORKDIR% tb_main --wave=tb_main.ghw
if errorlevel 1 exit /b 1

echo.
echo Gotowe. Fale: tb_main.ghw
endlocal
