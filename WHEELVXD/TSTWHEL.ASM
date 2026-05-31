; TSTWHEL.ASM - Test program for WHEELVXD.386
; Compile with MASM 5.10: masm5 tstwhel;
; Link: link tstwhel.obj;

        .model tiny
        .386
        .code
        org 100h

WHEELVXD_Dev_ID equ 7E5Eh

WHEEL_GET_VERSION equ 0
WHEEL_SUPPORTED   equ 1
WHEEL_GET_DELTA   equ 2
WHEEL_RESET_DELTA equ 3

start:
        mov     ax, 1684h       ; Get Device API Entry Point
        mov     bx, WHEELVXD_Dev_ID
        int     2Fh
        mov     ax, es
        or      ax, di
        jz      no_vxd

        mov     word ptr [api_entry], di
        mov     word ptr [api_entry+2], es

        ; Get version
        mov     ax, WHEEL_GET_VERSION
        call    api_entry
        call    print_ax_hex
        mov     dx, offset msg_version
        call    print

        ; Check wheel support
        mov     ax, WHEEL_SUPPORTED
        call    api_entry
        call    print_ax_hex
        mov     dx, offset msg_supported
        call    print

        ; Get initial delta (should be 0)
        mov     ax, WHEEL_GET_DELTA
        call    api_entry
        call    print_ax_hex
        mov     dx, offset msg_delta
        call    print

        mov     dx, offset msg_instructions
        call    print

wait_loop:
        mov     ah, 1
        int     16h
        jz      no_key
        mov     ah, 0
        int     16h
        cmp     al, 27         ; ESC to exit
        je      exit
no_key:
        mov     ax, WHEEL_GET_DELTA
        call    api_entry
        test    ax, ax
        jz      wait_loop
        call    print_ax_hex
        mov     dx, offset msg_delta
        call    print
        jmp     wait_loop

exit:
        mov     ax, 4C00h
        int     21h

no_vxd:
        mov     dx, offset msg_no_vxd
        call    print
        mov     ax, 4C01h
        int     21h

print_ax_hex proc
        push    ax
        push    bx
        push    cx
        push    dx
        mov     cx, 4
        mov     bx, ax
        mov     ah, 2
print_loop:
        rol     bx, 4
        mov     dl, bl
        and     dl, 0Fh
        add     dl, '0'
        cmp     dl, '9'
        jbe     digit_ok
        add     dl, 'A'-'9'-1
digit_ok:
        int     21h
        loop    print_loop
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
print_ax_hex endp

print proc
        mov     ah, 9
        int     21h
        ret
print endp

.data
api_entry       dd ?
msg_version     db      ' - Version',13,10,'$'
msg_supported   db      ' - Wheel supported (0=no,1=yes)',13,10,'$'
msg_delta       db      ' - Wheel delta',13,10,'$'
msg_instructions db     'Move mouse wheel, press ESC to exit.',13,10,'$'
msg_no_vxd      db      'WHEELVXD.386 not loaded or not found.',13,10,'$'

        end start