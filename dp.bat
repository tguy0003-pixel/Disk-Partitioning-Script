@echo off
SETLOCAL
CLS

:: --- Section 0: Drive Letter Check ---
:: Prevents script from running if the USB is assigned C:
IF /I "%~d0"=="C:" GOTO DriveConflictError

:: --- Section 1: Setup and Logging ---
SET LogFile=%~d0\DeploymentLog.txt
ECHO. > %LogFile%

:: --- Main Script Body ---
:Start
CLS
call :LogAndEcho "####################################################################"
call :LogAndEcho "#                    DEPLOYMENT & WIPE UTILITY                     #"
call :LogAndEcho "####################################################################"
call :LogAndEcho ""

:: --- Section 2: Network Connection Check ---
:NetworkTest
call :LogAndEcho "## Step 1: Checking Network Connection..."
ping -n 2 8.8.8.8 > nul
IF %ERRORLEVEL% EQU 0 (
    call :LogAndEcho "# NETWORK STATUS: [  OK  ] - Connection successful."
) ELSE (
    color 4F
    call :LogAndEcho "############################################################"
    call :LogAndEcho "# WARNING: NETWORK CONNECTION FAILED.                      #"
    call :LogAndEcho "# Installations from network shares or SCCM may fail later.#"
    call :LogAndEcho "# Press 'R' to retry, or any other key to continue.        #"
    call :LogAndEcho "############################################################"
    CHOICE /C RC /N /T 10 /D C /M "Retry Network Test? (R/C):"
    IF ERRORLEVEL 1 IF NOT ERRORLEVEL 2 GOTO NetworkTest
    color 0F
)
call :LogAndEcho ""

:: --- Section 3: Initial Configuration ---
call :LogAndEcho "## Step 2: Setting High Performance power plan..."
powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >> %LogFile% 2>&1
call :LogAndEcho ""

:: --- Section 4: Pre-Flight System Information & Asset Tag Validation ---
call :LogAndEcho "## Step 3: Gathering System Information..."

:: --- Gather all data first ---
FOR /F "skip=1 tokens=*" %%i IN ('wmic bios get serialnumber') DO (SET "SERIAL=%%i" & GOTO :next1)
:next1
FOR /F "skip=1 tokens=*" %%i IN ('wmic csproduct get name') DO (SET "MODEL=%%i" & GOTO :next2)
:next2
FOR /F "skip=1 tokens=*" %%i IN ('wmic systemenclosure get smbiosassettag') DO (SET "ASSET=%%i" & GOTO :next3)
:next3
FOR /F "skip=1 tokens=*" %%i IN ('wmic nic where "NetConnectionStatus=2 and PhysicalAdapter=True" get MACAddress') DO (SET "WIRED_MAC=%%i" & GOTO :next4)
:next4
FOR /F "skip=1 tokens=*" %%i IN ('wmic nic where "Name LIKE '%%Wireless%%' and PhysicalAdapter=True" get MACAddress') DO (SET "WIFI_MAC=%%i" & GOTO :next5)
:next5
FOR /F "skip=1 tokens=*" %%i IN ('wmic cpu get name') DO (SET "CPU=%%i" & GOTO :next6)
:next6
SET RAM_TOTAL_MB=0
FOR /F "skip=1" %%C IN ('wmic memorychip get capacity') DO (SET /A RAM_TOTAL_MB+=%%C / 1048576)
:next7
FOR /F "skip=1 tokens=*" %%i IN ('wmic diskdrive get size') DO (SET "DISKRAW=%%i" & GOTO :next8)
:next8

:: --- Clean up and format the gathered data ---
FOR /F "tokens=* delims= " %%a IN ("%SERIAL%") DO SET SERIAL=%%a
FOR /F "tokens=* delims= " %%a IN ("%MODEL%") DO SET MODEL=%%a
FOR /F "tokens=* delims= " %%a IN ("%ASSET%") DO SET ASSET=%%a
FOR /F "tokens=* delims= " %%a IN ("%WIRED_MAC%") DO SET WIRED_MAC=%%a
FOR /F "tokens=* delims= " %%a IN ("%WIFI_MAC%") DO SET WIFI_MAC=%%a
FOR /F "tokens=* delims= " %%a IN ("%CPU%") DO SET CPU=%%a
SET /A RAM_GB=RAM_TOTAL_MB / 1024
SET DISK_GB_STR=%DISKRAW%
SET DISK_GB=%DISK_GB_STR:~0,-9%

:: --- Display data in the requested order ---
call :LogAndEcho "--- ASSET DETAILS ------------------------------------"
call :LogAndEcho "Serial Number:     %SERIAL%"
call :LogAndEcho "Product Model:     %MODEL%"
call :LogAndEcho "Supplier:          Dell"
call :LogAndEcho "Warranty Date:     (Manual Entry Required)"
call :LogAndEcho "OS Install Date:   %date%"
call :LogAndEcho "Disk Size:         ~%DISK_GB% GB"
call :LogAndEcho "CPU Description:   %CPU%"
call :LogAndEcho "RAM Size:          %RAM_GB% GB"
call :LogAndEcho "Wired MAC Address: %WIRED_MAC%"
call :LogAndEcho "Wireless MAC Address:%WIFI_MAC%"
call :LogAndEcho "----------------------------------------------------"
call :LogAndEcho ""

:: --- Pause for technician to record data ---
color 0B
call :LogAndEcho "###############################################################"
call :LogAndEcho "# ACTION REQUIRED: Update the asset in TDX before continuing. #"
call :LogAndEcho "#   Wireless Mac Address Will Not Populate outside Windows    #"
call :LogAndEcho "###############################################################"
call :LogAndEcho ""
PAUSE
color 0F

:: Mandatory Asset Tag Check
IF /I "%ASSET%"=="" GOTO AssetTagError
IF /I "%ASSET%"=="To Be Filled By O.E.M." GOTO AssetTagError
IF /I "%ASSET%"=="Default string" GOTO AssetTagError
IF /I "%ASSET%"=="Not Applicable" GOTO AssetTagError
IF /I "%ASSET%"=="Not Set" GOTO AssetTagError

GOTO Confirmation

:AssetTagError
color 4F
call :LogAndEcho "############################################################"
call :LogAndEcho "# CRITICAL STOP: ASSET TAG IS NOT SET IN THE BIOS.         #"
call :LogAndEcho "#                                                          #"
call :LogAndEcho "# Press 'B' to bypass this check for the required scenario,  #"
call :LogAndEcho "# or any other key to exit and set the Asset Tag.          #"
call :LogAndEcho "############################################################"
CHOICE /C BE /N /M "Bypass or Exit? (B/E):"
IF ERRORLEVEL 2 GOTO EndScript
IF ERRORLEVEL 1 GOTO Confirmation

:Confirmation
:: --- Section 5: Go / No-Go Confirmation ---
call :LogAndEcho "--- Detected Disks ---"
(ECHO list disk) > %TEMP%\infogather.txt
diskpart /s %TEMP%\infogather.txt >> %LogFile% 2>&1
diskpart /s %TEMP%\infogather.txt
call :LogAndEcho ""
color 0C

SET /P "CHOICE=Ready to WIPE the internal disk? (Y/N): "
IF /I NOT "%CHOICE%"=="Y" (
    call :LogAndEcho "Wipe aborted by user."
    GOTO Cleanup
)
color 0F

:: --- Section 6: Wipe and Partition the Drive ---
SET TargetDisk=-1
SET TempScript=%TEMP%\dp_commands.txt
( ECHO select disk 0 & ECHO clean & ECHO convert gpt & ECHO create partition efi size=200 & ECHO format fs=fat32 quick & ECHO create part msr size=128 & ECHO create part pri & ECHO assign letter=c & ECHO format fs=ntfs quick ) > %TempScript%

call :LogAndEcho "## Step 4: Attempting to partition DISK 0..."
diskpart /s %TempScript% >> %LogFile% 2>&1
IF %ERRORLEVEL% EQU 0 ( SET TargetDisk=0 & GOTO Verify )

call :LogAndEcho "## DISK 0 failed. Attempting to partition DISK 1..."
( ECHO select disk 1 ) >> %TempScript%
diskpart /s %TempScript% >> %LogFile% 2>&1
IF %ERRORLEVEL% EQU 0 ( SET TargetDisk=1 & GOTO Verify )

color 4F
call :LogAndEcho ""
call :LogAndEcho "# CRITICAL FAILURE: Could not partition DISK 0 or DISK 1."
call :LogAndEcho "# Possible Drive Failure Repair or Replace SSD           "
GOTO Cleanup

:Verify
color 2F
call :LogAndEcho ""
call :LogAndEcho "# SUCCESS: The script completed on DISK %TargetDisk%."
call :LogAndEcho "###############################################################"
call :LogAndEcho "# ACTION REQUIRED: If an object exists in AD for this device  #"
call :LogAndEcho "# then it must be removed before imaging can begin.           #"
call :LogAndEcho "###############################################################"
call :LogAndEcho ""
call :LogAndEcho ""
call :LogAndEcho "## Step 5: Verifying partition structure on DISK %TargetDisk%..."
( ECHO select disk %TargetDisk% & ECHO list partition ) > %TEMP%\dp_verify.txt
diskpart /s %TEMP%\dp_verify.txt >> %LogFile% 2>&1
diskpart /s %TEMP%\dp_verify.txt
call :LogAndEcho ""
call :LogAndEcho "--- EXPECTED PARTITION LAYOUT ---"
call :LogAndEcho "  Partition ###  Type              Size     Offset"
call :LogAndEcho "  -------------  ----------------  -------  -------"
call :LogAndEcho "  Partition 1    System             200 MB  1024 KB"
call :LogAndEcho "  Partition 2    Reserved           128 MB   201 MB"
call :LogAndEcho "  Partition 3    Primary            [Rem]    329 MB"
call :LogAndEcho "-----------------------------------"
call :LogAndEcho ""
call :LogAndEcho "# SCRIPT FINISHED. VERIFY PARTITION LIST ABOVE."

:Cleanup
IF EXIST "%TEMP%\*.txt" DEL "%TEMP%\*.txt" >nul 2>&1
call :LogAndEcho ""
call :LogAndEcho "Script has finished. Press any key to exit the window."
PAUSE > nul
exit

:: --- LOGGING & ERROR SUBROUTINES ---
:LogAndEcho
echo %* >> %LogFile%
echo %*
goto :eof

:DriveConflictError
color 4F
ECHO ###############################################################
ECHO # CRITICAL FAILURE: SCRIPT IS RUNNING FROM C: DRIVE.          #
ECHO #                                                             #
ECHO # The WinPE environment has assigned the letter 'C:' to this  #
ECHO # USB drive, which will cause the disk wipe to fail.          #
ECHO #                                                             #
ECHO # TO FIX: Reboot the machine with ONLY this USB drive plugged #
ECHO # in to allow WinPE to assign drive letters correctly.        #
ECHO ###############################################################
PAUSE
GOTO EndScript

:EndScript
ENDLOCAL


