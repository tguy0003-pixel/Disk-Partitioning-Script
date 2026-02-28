WINPE DEPLOYMENT & WIPE UTILITY (dp.bat)

==========================================

A batch script designed for WinPE and SCCM environments to automate the pre-imaging setup process. Instead of manually typing diskpart commands and checking network drops by hand, this script automatically tests the network, pulls hardware info from the BIOS, and safely wipes the internal drive so the device is ready for a fresh OS install.

Built for and tested primarily on Dell enterprise machines.

CORE FEATURES

• AUTOMATED DISK WIPING (WITH FALLBACK):
Cleans and partitions the primary drive (GPT/UEFI) to prep it for imaging. If it detects a failure on Disk 0, it automatically falls back and attempts to partition Disk 1.
(Note: While the fallback could theoretically target the removable boot drive, WinPE natively protects the active USB from being wiped).

• HARDWARE INFO CAPTURE:
Pulls crucial system specs directly from the BIOS and displays them for the technician. This includes the Serial Number, CPU, RAM, Disk Size, and Asset Tag.
(Note: Only the wired MAC address can be retrieved from outside the Windows environment).

• PRE-DEPLOYMENT NETWORK CHECKS:
Pings out to ensure the ethernet drop is actually active before imaging begins, preventing SCCM task sequences from failing halfway through.

• ASSET TAG VALIDATION:
Checks the BIOS for a valid organizational Asset Tag. If the tag is blank or shows a generic OEM template (e.g., "To Be Filled By O.E.M."), the script pauses and prompts the technician to fix it before continuing.

• USB DRIVE PROTECTION:
Sometimes WinPE incorrectly assigns the C: drive letter to the bootable USB. The script checks for this immediately and halts execution to prevent it from accidentally wiping the deployment drive.

DEPLOYMENT & SETUP

STEP 1: Download the dp.bat file.

STEP 2: Place the file directly into the ROOT DIRECTORY of your bootable WinPE or SCCM USB drive.

USAGE INSTRUCTIONS

STEP 1: Boot the target device to your WinPE/SCCM USB.

STEP 2: Press F8 (or Fn + F8 on some laptops) to open the command prompt.

STEP 3: Navigate to the drive letter assigned to your USB (usually D:).
Example: Type D: and press Enter.

STEP 4: Run the script by typing dp.bat and pressing Enter.

STEP 5: Review the hardware info on the screen, update your ticketing system with the MAC addresses, and follow the prompts to proceed with the disk wipe.

Note: This script uses diskpart clean to wipe internal drives. It is built strictly for IT staging environments where data destruction is the intended goal. Please use carefully.
