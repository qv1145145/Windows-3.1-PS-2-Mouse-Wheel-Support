# Windows 3.1 PS/2 Mouse Wheel Support

This project adds scroll wheel support to Windows 3.1 for PS/2 mice (IntelliMouse compatible). It consists of a VxD (`WHEELVXD.386`) that hooks IRQ12 or uses I/O trapping to parse wheel packets, and a modified mouse driver (`MOUSE.DRV`) that exports `WheelSupported` and `GetWheelDelta` APIs.

## Features

- Detects wheel presence using the standard IntelliMouse rate sequence (200 → 100 → 80 Hz).
- Accumulates wheel deltas while preserving original mouse movement and button functionality.
- Provides a simple protected‑mode API (via `INT 2Fh`) to query wheel support and retrieve accumulated delta.
- Optional: modified `MOUSE.DRV` can forward calls to the VxD, allowing existing applications to use `LoadLibrary`/`GetProcAddress`.

## Repository Structure

```
├── WHEELVXD/
│   ├── WHEELVXD.ASM       - VxD source (direct I/O or I/O trapping version)
│   ├── WHEELVXD.INC       - constants and device ID
│   ├── WHEELVXD.DEF       - module definition file
│   ├── MAKEFILE           - build with MASM 5.10+ and link386
│   └── README.md          - this file
├── MOUSE/
│   ├── MOUSE.ASM.diff     - changes to original DDK mouse driver
│   ├── MOUSE.INC.diff
│   ├── MOUSE.DEF.diff
│   └── PS2.ASM.diff       (if modified)
└── TEST/
    ├── testvxd.c          - test program that calls VxD directly
    ├── testdrv.c          - test program that calls MOUSE.DRV exports
    └── Makefile           - Open Watcom makefile
```

## Requirements

- **Build environment**: DOSBox or real MS‑DOS with Microsoft MASM 5.10B, link386, addhdr, mapsym32 (all from Windows 3.1 DDK).
- **Runtime**: Windows 3.1 in 386 enhanced mode, PS/2 mouse (or emulated, e.g., 86Box, VirtualBox with PS/2 mouse).

## Building

### VxD

1. Place the source files in a directory, e.g., `D:\DDK31\386\WHEELVXD`.
2. Set up environment (example for DOSBox):
   ```batch
   set PATH=D:\DDK31\386\TOOLS;%PATH%
   set INCLUDE=D:\DDK31\386\INCLUDE
   ```
3. Run `nmake` (the provided `MAKEFILE`).
4. Successful build yields `WHEELVXD.386`.

### Mouse Driver (optional)

Apply the patches to the original DDK `MOUSE` directory, then compile with `nmake`.

## Installation

1. Copy `WHEELVXD.386` to `C:\WINDOWS\SYSTEM`.
2. Add the following line to the `[386enh]` section of `SYSTEM.INI`:
   ```
   device=WHEELVXD.386
   ```
3. Restart Windows.
4. Optionally replace the original `MOUSE.DRV` with the patched version (backup first).

## Usage

### Direct VxD API

Call `INT 2Fh` with `AX=1684h`, `BX=0E5E5h` to retrieve the API entry point. Then call with function codes:

| AX | Function | Returns |
|----|----------|---------|
| 0  | Get version | `AX = 0x0100` |
| 1  | Wheel supported | `AX = 0` (no) or `1` (yes) |
| 2  | Get wheel delta | `AX = signed accumulated delta`, cleared after read |

Example C code (Open Watcom):

```c
#define WHEELVXD_Dev_ID   0xE5E5
#define WHEEL_GET_VERSION 0
#define WHEEL_SUPPORTED   1
#define WHEEL_GET_DELTA   2

typedef void (__far * VXDCALL)(void);
VXDCALL vxdEntry = NULL;

BOOL GetVxDApi(void) {
    __asm {
        mov ax, 1684h
        mov bx, WHEELVXD_Dev_ID
        int 2Fh
        mov word ptr [vxdEntry], di
        mov word ptr [vxdEntry+2], es
    }
    return vxdEntry != NULL;
}

int GetWheelDelta(void) {
    int delta;
    if (!vxdEntry) return 0;
    __asm {
        mov ax, WHEEL_GET_DELTA
        xor bx, bx
        call dword ptr [vxdEntry]
        mov [delta], ax
    }
    return delta;
}
```

### Using the Patched MOUSE.DRV

After installing the patched driver, an application can call `LoadLibrary("MOUSE.DRV")` and `GetProcAddress` for `WheelSupported` (ordinal 7) and `GetWheelDelta` (ordinal 8).

## How It Works

The VxD either hooks IRQ12 (standard PS/2 interrupt) or installs an I/O callback on port 60h. The state machine parses 3‑byte (standard) and 4‑byte (wheel) packets, extracts the signed wheel delta, and accumulates it. The wheel detection sequence follows the IntelliMouse protocol:

1. Set sample rate to 200 Hz (`0xF3, 200`)
2. Set sample rate to 100 Hz (`0xF3, 100`)
3. Set sample rate to 80 Hz (`0xF3, 80`)
4. Read device ID (`0xF2`); if ID == 3 or 4, wheel is supported.

The accumulated value is stored in shared memory and can be queried via the API.

## Limitations

- Only PS/2 mice (IRQ12) are supported.
- The VxD must be loaded before Windows enables mouse interrupts (works when placed in `[386enh]`).
- If the mouse does not support the IntelliMouse protocol, the wheel will not be detected.

## Troubleshooting

- **Test program cannot find VxD** → check `SYSTEM.INI`, file location, and that `addhdr` was run on `WHEELVXD.386`.
- **Wheel delta always 0** → your mouse may not support the standard protocol; try forcing `v_wheel_supported = 1` in the VxD.
- **Windows fails to start** → remove the `device=` line and restore original `MOUSE.DRV`.

## References

- Microsoft Windows 3.1 DDK documentation (especially `VFINTD.386` sample for IRQ virtualization and `VKDIO.ASM` for I/O trapping).
- “PS/2 Mouse Interfacing” and “IntelliMouse Protocol” specifications (publicly available).

## License

This project is provided for educational purposes. Use at your own risk. No warranty or support is implied. You are free to modify and distribute it under the terms of the MIT License.

## Acknowledgements

- Microsoft DDK sample code (VFINTD, VKD) for the base VxD framework.
- The community for preserving Windows 3.1 development tools.

---

Feel free to open issues or pull requests on GitHub. Contributions are welcome!
