@echo OFF
set Product= %1
set BuildPath=%2

if %Product%==SM (
set CommandFilePath=\\cdmbuilds\tools\Apps\VHDCreator\AutomationScripts\SM\SM_VHD.cmd
)
if "%Product%"==SCOM (
set CommandFilePath=\\cdmbuilds\tools\Apps\VHDCreator\AutomationScripts\SCOM\SCOM_VHD.cmd
)
if "%Product%"==VMM (
set username=%3
set password=%4
set CommandFilePath=\\cdmbuilds\tools\Apps\VHDCreator\AutomationScripts\VMM\SCVMM_VHD.cmd %Username% %Password%

if "%username%" == "" (
    @echo CDMSCRIPT: Mandatory field: username missing, exiting...
    exit /B 1
)
if "%password%" == "" (
    @echo CDMSCRIPT: Mandatory field: password missing, exiting...
    exit /B 1
)
)
echo %cd%

powershell.exe .\VHD_Preparation.ps1 %Product% %CommandFilePath% %BuildPath%

REM call POWERSHELL VHD_Preparation.ps1 %Product% %CommandFilePath% %BuildPath%
