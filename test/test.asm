; TSTVXD.ASM - 测试 VxD 是否存在并调用 API
        .model tiny
        .386
        .code
        org 100h

WHEELVXD_Dev_ID  equ  0E5E5h
WHEEL_GET_VERSION equ 0

start:
        mov     ax, 1684h
        mov     bx, WHEELVXD_Dev_ID
        int     2Fh
        mov     ax, es
        or      ax, di
        jz      no_vxd
        mov     word ptr [api_entry], di
        mov     word ptr [api_entry+2], es

        ; 调用获取版本号
        mov     ax, WHEEL_GET_VERSION
        xor     bx, bx
        call    dword ptr [api_entry]
        call    print_ax
        mov     dx, offset msg_version
        call    print

        ; 调用获取支持状态
        mov     ax, 1       ; WHEEL_SUPPORTED
        xor     bx, bx
        call    dword ptr [api_entry]
        call    print_ax
        mov     dx, offset msg_supported
        call    print

        ; 调用获取累积值
        mov     ax, 2       ; WHEEL_GET_DELTA
        xor     bx, bx
        call    dword ptr [api_entry]
        call    print_ax
        mov     dx, offset msg_delta
        call    print

        jmp     exit

no_vxd:
        mov     dx, offset msg_no_vxd
        call    print

exit:
        mov     ax, 4C00h
        int     21h

print_ax proc
        push    ax
        push    bx
        push    cx
        push    dx
        mov     cx, 4
        mov     bx, ax
        mov     ah, 2
pr_loop:
        rol     bx, 4
        mov     dl, bl
        and     dl, 0Fh
        add     dl, '0'
        cmp     dl, '9'
        jbe     pr_digit
        add     dl, 'A'-'9'-1
pr_digit:
        int     21h
        loop    pr_loop
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
print_ax endp

print proc
        mov     ah, 9
        int     21h
        ret
print endp

.data
api_entry       dd ?
msg_version     db ' - Version',13,10,'$'
msg_supported   db ' - Supported',13,10,'$'
msg_delta       db ' - Delta',13,10,'$'
msg_no_vxd      db 'WHEELVXD.386 not loaded',13,10,'$'

        end start