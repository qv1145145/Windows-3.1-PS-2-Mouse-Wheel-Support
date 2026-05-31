WHEELVXD.386 - PS/2 Mouse Wheel Support for Windows 3.1
--The self-descriptive file has not been fully implemented.

Overview:
---------
This VxD provides low-level support for IntelliMouse-style scroll wheels 
under Windows 3.1 in 386 enhanced mode. It hooks IRQ12 (PS/2 mouse interrupt),
detects the presence of a wheel using the standard sample rate sequence 
(200/100/80 Hz), reads 4-byte packets, extracts the wheel delta, and 
accumulates it. The accumulated value can be retrieved by a protected-mode 
application (such as MOUSE.DRV or a browser) via a simple API.

Installation:
-------------
1. Copy WHEELVXD.386 to your Windows SYSTEM directory.
2. Add the following line to the [386enh] section of SYSTEM.INI:
        device=WHEELVXD.386
3. Restart Windows.

API Usage (for application/driver):
------------------------------------
Obtain the VxD entry point using Int 2Fh, AX=1684h, BX=WHEELVXD_Dev_ID (0x7E5E).
Then call the returned far address with appropriate function code in AX.

Supported function codes (from WHEELVXD.INC):
    AX = 0  -> Get version (returns AX = 0x0100)
    AX = 1  -> Check wheel support (returns AX = 1 if present, else 0)
    AX = 2  -> Get accumulated wheel delta (returns AX = signed delta, clears accumulator)
    AX = 3  -> Reset accumulator (returns AX = 1)

The VxD works alongside the standard MOUSE.DRV; it does not interfere with 
normal mouse movement or button handling.

Notes:
------
- The device ID (0x7E5E) is a placeholder. If you plan to redistribute,
  obtain a unique ID from Microsoft (refer to VXDID.TXT in the DDK).
- This VxD is for educational purposes and may be adapted for other devices.

Building:
---------
Use MASM 5.10B and LINK386 from the Windows DDK. The provided MAKEFILE assumes
the DDK include files are in the parent directory's "inc" subfolder.
Edit paths as needed.

Author: 
    Based on Microsoft VFINTD sample, adapted for PS/2 mouse wheel.