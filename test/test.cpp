#include <windows.h>

#define WHEELVXD_Dev_ID   0xE5E5
#define WHEEL_GET_VERSION 0
#define WHEEL_SUPPORTED   1
#define WHEEL_GET_DELTA   2

typedef void (FAR * VXDCALL)(void);
VXDCALL vxdEntry = NULL;

BOOL GetVxDApi(void) {
    __asm {
        mov     ax, 1684h
        mov     bx, WHEELVXD_Dev_ID
        int     2Fh
        mov     word ptr [vxdEntry], di
        mov     word ptr [vxdEntry+2], es
    }
    return vxdEntry != NULL;
}

WORD CallVxd(WORD ax, WORD bx) {
    WORD result;
    __asm {
        mov     ax, ax
        mov     bx, bx
        call    dword ptr [vxdEntry]
        mov     [result], ax
    }
    return result;
}

int PASCAL WinMain(HANDLE hInst, HANDLE hPrev, LPSTR lpCmd, int nCmd) {
    char buf[128];
    if (!GetVxDApi()) {
        MessageBox(NULL, "WHEELVXD.386 not loaded", "Error", MB_OK);
        return 0;
    }
    wsprintf(buf, "Version: %04X\nSupported: %d\nDelta: %d",
             CallVxd(WHEEL_GET_VERSION, 0),
             CallVxd(WHEEL_SUPPORTED, 0),
             CallVxd(WHEEL_GET_DELTA, 0));
    MessageBox(NULL, buf, "Direct VxD Test", MB_OK);
    return 0;
}