@echo off
SETLOCAL EnableDelayedExpansion
CLS
::Last Change 10/29/25
::Version 24 (Updated C: Drive Reboot logic)

:: --- Section 0: Drive Letter Check ---
IF /I "%~d0"=="C:" GOTO DriveConflictError

:StartMainScript
:: --- Section 1: Main Menu ---

:MainMenu
CLS
ECHO "####################################################################"
ECHO "#                    DEPLOYMENT & WIPE UTILITY                     #"
ECHO "####################################################################"
ECHO ""
ECHO "Please select an operation mode:"
ECHO "  1 - Full Staging (Network, Asset Details, Disk Wipe)"
ECHO "  2 - Wipe Only (Skip checks and go straight to Wipe)"
ECHO "  3 - Asset Details Only (Gather Specs and Exit)"
ECHO "  E - Exit Script"
ECHO ""
CHOICE /C 123E /N /M "Select an option (1, 2, 3, E): "

IF ERRORLEVEL 4 GOTO Cleanup
IF ERRORLEVEL 3 GOTO ModeAssetOnly
IF ERRORLEVEL 2 GOTO ModeWipeOnly
IF ERRORLEVEL 1 GOTO ModeFull

:ModeFull
SET "RUN_MODE=FULL"
GOTO StartProcess

:ModeAssetOnly
SET "RUN_MODE=ASSET_ONLY"
GOTO StartProcess

:ModeWipeOnly
SET "RUN_MODE=WIPE_ONLY"
GOTO Confirmation

:StartProcess
ECHO "## Step 1: Setting High Performance power plan..."
powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c > nul 2>&1
ECHO ""

ECHO "## Step 2: Gathering System Information..."

FOR /F "skip=1 tokens=*" %%i IN ('wmic bios get serialnumber') DO (SET "SERIAL=%%i" & GOTO :next1)
:next1
FOR /F "skip=1 tokens=*" %%i IN ('wmic csproduct get name') DO (SET "MODEL=%%i" & GOTO :next2)
:next2
FOR /F "skip=1 tokens=*" %%i IN ('wmic systemenclosure get smbiosassettag') DO (SET "ASSET=%%i" & GOTO :next5)
:next5
FOR /F "skip=1 tokens=*" %%i IN ('wmic cpu get name') DO (SET "CPU=%%i" & GOTO :next6)
:next6
SET RAM_TOTAL_GB=0
SET RAM_GB=0
FOR /F "skip=1" %%C IN ('wmic memorychip get capacity') DO (
    FOR /F "tokens=1" %%D IN ("%%C") DO (
        SET "RAM_VALUE=%%D"
        SET "RAM_VALUE=!RAM_VALUE:(=!"
        SET "RAM_VALUE=!RAM_VALUE:)=!"
        SET "RAM_GB_VALUE=!RAM_VALUE:~0,-9!"
        SET /A RAM_TOTAL_GB+=!RAM_GB_VALUE! 2>nul
    )
)
SET RAM_GB=%RAM_TOTAL_GB%

:next7
SET "DISKRAW="
FOR /F "skip=1" %%i IN ('wmic diskdrive where "Index=0" get size') DO (
    FOR /F "tokens=1" %%j IN ("%%i") DO (
        SET "DISKRAW=%%j"
        GOTO next8
    )
    GOTO next8
)

:next8
FOR /F "tokens=* delims= " %%a IN ("%SERIAL%") DO SET SERIAL=%%a
FOR /F "tokens=* delims= " %%a IN ("%MODEL%") DO SET MODEL=%%a
FOR /F "tokens=* delims= " %%a IN ("%ASSET%") DO SET ASSET=%%a
FOR /F "tokens=* delims= " %%a IN ("%CPU%") DO SET CPU=%%a
SET DISK_GB_STR=%DISKRAW%
SET DISK_GB=%DISK_GB_STR:~0,-9%

ECHO "--- ASSET DETAILS ------------------------------------"
ECHO "Serial Number:     %SERIAL%"
ECHO "Product Model:     %MODEL%"
ECHO "Supplier:          Dell"
ECHO "Warranty Date:     (4 Years From Purchase)"
ECHO "OS Install Date:   %date%"
ECHO "Disk Size:         %DISK_GB% GB"
ECHO "CPU Description:   %CPU%"
ECHO "RAM Size:          %RAM_GB% GB"
ECHO "Wireless MAC Address:Check packaging"
ECHO "----------------------------------------------------"
ECHO "If errors are reported above device may have failing hardware, recommend running diagnostics"
ECHO ""

color 0B
ECHO "###############################################################"
ECHO "# ACTION REQUIRED: Update the asset in TDX before continuing. #"
ECHO "#   Wireless Mac Address Will Not Populate outside Windows    #"
ECHO "###############################################################"
ECHO ""
PAUSE
color 0F

:: If the user only wanted Asset Details, exit the script here before the wipe
IF /I "%RUN_MODE%"=="ASSET_ONLY" GOTO Cleanup

:NetworkTest
ECHO "## Step 3: Checking Network Connection..."
SET "NetworkRetries=0"

:NetworkTestPing
ping -n 2 8.8.8.8 > nul
IF %ERRORLEVEL% EQU 0 (
    ECHO "# NETWORK STATUS: [  OK  ] - Connection successful."
    GOTO NetworkTestSuccess
)

SET /A NetworkRetries+=1
IF %NetworkRetries% LSS 4 (
    ECHO "# Network failed. Retrying in 5 seconds... (Attempt %NetworkRetries%/4)"
    ping -n 6 127.0.0.1 >nul
    GOTO NetworkTestPing
)

color 4F
ECHO "############################################################"
ECHO "# CRITICAL: NETWORK CONNECTION FAILED AFTER 4 ATTEMPTS.    #"
ECHO "# Installations from network shares or SCCM may fail later.#"
ECHO "# Press 'C' to continue, 'R' to reboot, or 'E' to exit.    #"
ECHO "############################################################"

SET "CHOICE="
SET /P "CHOICE=Continue, Reboot, or Exit? (C/R/E): "

IF /I "%CHOICE%"=="C" (
    ECHO "User chose to continue without network."
    GOTO NetworkTestSuccess
)
IF /I "%CHOICE%"=="R" (
    ECHO "User selected REBOOT."
    ping -n 6 127.0.0.1 >nul
    wpeutil reboot
    GOTO EndScript
)
:: Any other key (including 'E') defaults to Exit
ECHO "User aborted network test."
GOTO Cleanup

:NetworkTestSuccess
color 0F
ECHO ""
:: --- End of moved Network Test ---

IF /I "%ASSET%"=="" GOTO AssetTagError
IF /I "%ASSET%"=="To Be Filled By O.E.M." GOTO AssetTagError
IF /I "%ASSET%"=="Default string" GOTO AssetTagError
IF /I "%ASSET%"=="Not Applicable" GOTO AssetTagError
IF /I "%ASSET%"=="Not Set" GOTO AssetTagError

GOTO Confirmation

:AssetTagError
color 4F
ECHO "############################################################"
ECHO "# CRITICAL STOP: ASSET TAG IS NOT SET IN THE BIOS.         #"
ECHO "# You can bypass this (not recommended), reboot to         #"
ECHO "# enter the BIOS, or exit the script.                      #"
ECHO "############################################################"
ECHO ""

SET "CHOICE="
SET /P "CHOICE=(B)ypass, (R)eboot, or (E)xit: "

IF /I "%CHOICE%"=="B" (
    ECHO "User selected BYPASS for missing asset tag."
    GOTO Confirmation
)
IF /I "%CHOICE%"=="R" (
    ECHO "User selected REBOOT to enter BIOS."
    ECHO.
    ECHO ########################################################
    ECHO # REBOOTING IN 5 SECONDS. PRESS CTRL-C TO CANCEL.      #
    ECHO # Prepare to enter the BIOS/UEFI setup.                #
    ECHO ########################################################
    ping -n 6 127.0.0.1 >nul
    wpeutil reboot
    GOTO EndScript
)
:: Any other key (including 'E') defaults to Exit
ECHO "User aborted due to missing asset tag."
GOTO Cleanup


:Confirmation
ECHO "--- Detected Disks ---"
(ECHO list disk) > %TEMP%\infogather.txt
diskpart /s %TEMP%\infogather.txt
ECHO ""
color 0C

ECHO "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
ECHO "!! WARNING: YOU ARE ABOUT TO WIPE THE INTERNAL DRIVE (DISK 0)     !!"
ECHO "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
SET "CHOICE="
SET /P "CHOICE=Ready to WIPE Disk 0 (%DISK_GB% GB)? (Y/N): "
IF /I NOT "%CHOICE%"=="Y" (
    ECHO "Wipe aborted by user."
    GOTO Cleanup
)
color 0F
SET TargetDisk=-1
SET TempScript=%TEMP%\dp_commands.txt

( ECHO select disk 0 & ECHO clean & ECHO convert gpt & ECHO create partition efi size=200 & ECHO format fs=fat32 quick & ECHO create part msr size=128 & ECHO create part pri & ECHO assign letter=c & ECHO format fs=ntfs quick ) > %TempScript%

ECHO "## Step 4: Attempting to partition DISK 0..."
diskpart /s %TempScript% > nul 2>&1
IF %ERRORLEVEL% EQU 0 ( SET TargetDisk=0 & GOTO Verify )

color 4F
ECHO "########################################################"
ECHO "# CRITICAL FAILURE: Could not partition DISK 0.        #"
ECHO "# The script will not attempt to partition other disks.#"
ECHO "#     Possible Drive Failure Repair or Replace SSD     #"
ECHO "########################################################"
GOTO Cleanup

:Verify
color 2F
ECHO ""
ECHO "## Step 5: Verifying partition structure on DISK %TargetDisk%..."
( ECHO select disk %TargetDisk% & ECHO list partition ) > %TEMP%\dp_verify.txt
diskpart /s %TEMP%\dp_verify.txt
ECHO ""
ECHO "--- EXPECTED PARTITION LAYOUT ---"
ECHO "  Partition ###  Type              Size     Offset"
ECHO "  -------------  ----------------  -------  -------"
ECHO "  Partition 1    System             200 MB  1024 KB"
ECHO "  Partition 2    Reserved           128 MB   201 MB"
ECHO "  Partition 3    Primary            [Rem]    329 MB"
ECHO "-----------------------------------"
ECHO ""
ECHO "# SCRIPT FINISHED. VERIFY PARTITION LIST ABOVE."
ECHO "# SUCCESS: The script completed on DISK %TargetDisk%."
ECHO "###############################################################"
ECHO "# ACTION REQUIRED: If an object exists in AD for this device  #"
ECHO "#       no task sequences will be avialble for imaging        #"
ECHO "#         Contact your IT Administrator for Removal           #"
ECHO "###############################################################"
ECHO ""

:Cleanup
IF EXIST "%TEMP%\*.txt" DEL "%TEMP%\*.txt" >nul 2>&1
ECHO ""
ECHO "Script has finished. Press any key to exit the window."
PAUSE > nul
exit

:: --- LOGGING & ERROR SUBROUTINES ---
:: (Logging function removed)

:DriveConflictError
color 4F
CLS
ECHO ###############################################################
ECHO # CRITICAL FAILURE: SCRIPT IS RUNNING FROM C: DRIVE.          #
ECHO #                                                             #
ECHO # The WinPE environment has assigned 'C:' to this USB drive,  #
ECHO # which will cause the disk wipe to fail.                     #
ECHO #                                                             #
ECHO # TO FIX: Attempting to remap C: to E: before rebooting...    #
ECHO ###############################################################
ECHO ""
ECHO "Attempting to assign C: to E:..."

(
    ECHO select volume C
    ECHO assign letter=E
) > %TEMP%\remap_c.txt

diskpart /s %TEMP%\remap_c.txt

ECHO ""
:: CHANGED: Added prompt to restart script and PAUSE
ECHO "Remap attempt finished."
ECHO "Please close this window and restart the DP script."
ECHO "The machine will reboot after you press any key."
ECHO ""
PAUSE > nul

ECHO "Rebooting now..."
wpeutil reboot
GOTO EndScript

:EndScript
ENDLOCAL
