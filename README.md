# Disk-Partitioning-Script
Automated Disk Partitioning Script designed to run in the Win-PE environment and fully format Disk 0 while checking an active network connection and collecting the device specs

Built for and tested on Dell Business/Enterprise Devices


This file should be loaded into the root folder of a USB bootable with a WIN PE or SCCM installer

To open press F8 or FN+F8 to open terminal then navigate to drive D: or whichever letter has been assinged to the USB
  If C: was assigned to the USB the script will first attempt to reassign it's drive letter and ask you to restart the device

A menu was added to choose between the full script or to simply run parts of it with 1 Full, 2 Wipe Only, 3 Asset Details Only

Network Failure will give you options to Restart, or Bypass depending on what you'd like to do with the device
This script was designed for use in IT environments and has a dedicated section to check the Asset Tag in the BIOS
  If Null or a prefilled template from Manufacturer the script will stop and ask if you want to Restart and add the Tag, Close the Script or Bypass this requirement

