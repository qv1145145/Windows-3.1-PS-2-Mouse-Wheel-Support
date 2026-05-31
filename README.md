# Windows 3.1 PS/2 Mouse Wheel Support (Experimental / Work in Progress)

**Status: Not fully functional – contributions welcome!**  
This project is an attempt to add scroll wheel support to Windows 3.1 for PS/2 mice (IntelliMouse compatible). The code compiles and installs, but the VxD currently fails to register its API entry point (`INT 2Fh` returns zero), and the modified mouse driver always returns `0`. This repository is a call for help from anyone with experience in Windows 3.1 VxD development.

## Overview

The project consists of:
- `WHEELVXD.386` – a VxD that hooks IRQ12 or uses I/O trapping on port 0x60 to parse PS/2 packets, detect a wheel via the standard rate sequence (200 → 100 → 80 Hz), and accumulate wheel deltas.
- A patched `MOUSE.DRV` that exports `WheelSupported` and `GetWheelDelta` (ordinals 7 and 8) which forward calls to the VxD.

The intended API (via `INT 2Fh`, AX=1684h, BX=0xE5E5) should provide:
- `AX=0`: version (0x0100)
- `AX=1`: wheel supported? (1 if detected)
- `AX=2`: get accumulated delta (clears after read)

## Current Issues (Help Needed!)

- **VxD entry point not found** – `INT 2Fh` returns a null pointer even though the VxD is installed (file in SYSTEM, `device=` line in `SYSTEM.INI`). The VxD compiles and passes `addhdr`, but the API is not registered.
- **Memory allocation may fail** – `_PageAllocate` could be returning an error, causing the VxD to abort initialisation (though Windows boots normally).
- **I/O callback not triggered** – When using `Install_IO_Handler`, the callback routine may never be called, or the wheel detection sequence fails.
- **Driver extension always returns 0** – Even though `GetProcAddress` finds the exported functions, they return 0 because the VxD is not accessible.

## How You Can Help

If you have experience with Windows 3.1 VxD development, please consider:
- Debugging the VxD initialisation – check why `INT 2Fh` returns zero.
- Testing the I/O trapping or IRQ hooking variants.
- Verifying the wheel detection sequence on real hardware or emulators (86Box, VirtualBox).
- Providing a working version of `WHEELVXD.386` or a pull request with fixes.

Open an issue or submit a pull request on GitHub. Any help is greatly appreciated!

## Repository Structure

```
├── WHEELVXD/
│   ├── WHEELVXD.ASM       - VxD source (two versions: IRQ hook and I/O trap)
│   ├── WHEELVXD.INC       - constants and device ID
│   ├── WHEELVXD.DEF       - module definition file
│   ├── MAKEFILE           - build with MASM 5.10+ and link386
│   └── README.md          - this file
├── MOUSE/
│   ├── MOUSE.ASM.diff     - changes to original DDK mouse driver
│   ├── MOUSE.INC.diff
│   ├── MOUSE.DEF.diff
│   └── PS2.ASM.diff       
└── TEST/
    ├── tes.cpp            - test program that calls VxD directly
    └── test_dos.cpp       - test program that calls MOUSE.DRV exports
```

## Requirements

- **Build environment**: DOSBox or real MS‑DOS with Microsoft MASM 5.10B, link386, addhdr, mapsym32 (from Windows 3.1 DDK).
- **Runtime**: Windows 3.1 in 386 enhanced mode, PS/2 mouse (or emulated, e.g., 86Box, VirtualBox with PS/2 mouse).

## Building

### VxD

1. Place sources in a directory (e.g., `D:\DDK31\386\WHEELVXD`).
2. In DOSBox, set environment:
   ```batch
   set PATH=D:\DDK31\386\TOOLS;%PATH%
   set INCLUDE=D:\DDK31\386\INCLUDE
   ```
3. Run `nmake`.
4. Output: `WHEELVXD.386`.

### Mouse Driver (optional)

Apply the patches to the original DDK `MOUSE` directory and run `nmake`.

## Installation

1. Copy `WHEELVXD.386` to `C:\WINDOWS\SYSTEM`.
2. Add `device=WHEELVXD.386` to the `[386enh]` section of `SYSTEM.INI`.
3. Restart Windows.
4. (Optional) Replace `MOUSE.DRV` with the patched version (backup original).

## Testing

### Direct VxD API test

Compile `TEST/testvxd.c` with Open Watcom. If the VxD is loaded correctly, it should display version and supported status.

### Driver function test

Compile `TEST/testdrv.c`. It calls `LoadLibrary` and `GetProcAddress` for the exported functions. Currently both return 0.

## Known Limitations

- Only PS/2 mice (IRQ12) are targeted.
- The VxD may not load at all; the project is not yet functional.
- The wheel detection sequence has not been verified on real hardware.

## License

This project is licensed under the **GNU Affero General Public License v3.0** (AGPL-3.0). See the LICENSE file for details.

## Acknowledgements

- Microsoft DDK sample code (VFINTD, VKD) for the VxD framework.
- The community preserving Windows 3.1 development tools.

---

**Please open an issue or pull request if you can help fix the remaining problems. Thank you!**
