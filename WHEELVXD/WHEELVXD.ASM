PAGE 58,132
;------------------------------------------------------------------------------
; WHEELVXD.ASM - Virtual Device for PS/2 Mouse Wheel Support
;   Contains wheel detection + I/O trapping on port 60h.
;------------------------------------------------------------------------------

        .386p
        .XLIST
        INCLUDE VMM.INC
        INCLUDE VPICD.INC
        INCLUDE WHEELVXD.INC
        .LIST

Declare_Virtual_Device WHEELVXD, 2, 0, WHEELVXD_Control, WHEELVXD_Dev_ID, 0, , WHEELVXD_API_Proc

;-----------------------------------------------------------------------------
; Shared memory structure
;-----------------------------------------------------------------------------
WHEELSHARE STRUC
    wSupported  dw  0
    wAccum      dw  0
WHEELSHARE ENDS

;-----------------------------------------------------------------------------
; Locked Data Segment
;-----------------------------------------------------------------------------
VxD_LOCKED_DATA_SEG

shared_lin     dd  0
shared_handle  dd  0
physaddr_buf   dd  0

packet_state   db  0
saved_buttons  db  0
saved_x        db  0
saved_y        db  0
saved_wheel    db  0
old_buttons    db  0
v_wheel_supported dw 0

VxD_LOCKED_DATA_ENDS

;-----------------------------------------------------------------------------
; Initialization Code
;-----------------------------------------------------------------------------
VxD_ICODE_SEG

BeginProc WHEELVXD_Device_Init
        ; 分配共享内存
        lea     edi, physaddr_buf
        VMMcall _PageAllocate, <1, 1, 0, 0, 0, 0, edi, 0102h>   ; PG_SYS=1, PageZeroInit+PageLocked=102h
        mov     ecx, eax
        mov     edx, edx
        or      ecx, edx
        jz      near ptr alloc_failed
        mov     [shared_handle], ecx
        mov     [shared_lin], edx
        mov     edi, edx
        xor     eax, eax
        mov     ecx, 1024
        rep     stosd

        ; 检测滚轮（发送采样率序列 200,100,80）
        call    DetectWheel

        ; 安装 I/O 回调
        mov     esi, OFFSET32 IOCallback60
        mov     edx, 60h
        VMMcall Install_IO_Handler
        jc      near ptr install_failed
        clc
        ret
alloc_failed:
install_failed:
        stc
        ret
EndProc WHEELVXD_Device_Init

; 滚轮检测子程序（直接 I/O）
DetectWheel proc near
        pushad
        cli

        ; 发送 200,100,80 采样率
        mov     cx, 3
        lea     si, wheel_rates
detect_loop:
        lodsb
        mov     ah, al
        push    cx
        call    SendMouseCommand
        pop     cx
        loop    detect_loop

        ; 发送 0xF2 读取 ID
        mov     al, 0F2h
        call    SendMouseCommand
        call    ReadMouseByte   ; ACK
        call    ReadMouseByte   ; ID
        cmp     al, 3
        je      wheel_yes
        cmp     al, 4
        je      wheel_yes
        jmp     wheel_no
wheel_yes:
        mov     word ptr [v_wheel_supported], 1
        mov     eax, [shared_lin]
        test    eax, eax
        jz      wheel_no
        mov     word ptr [eax + WHEELSHARE.wSupported], 1
wheel_no:
        sti
        popad
        ret

wheel_rates db 200, 100, 80

SendMouseCommand proc near
        push    eax
        call    WaitKBCWrite
        mov     al, 0D4h
        out     64h, al
        call    WaitKBCWrite
        pop     eax
        out     60h, al
        ret
SendMouseCommand endp

ReadMouseByte proc near
        call    WaitKBCRead
        in      al, 60h
        ret
ReadMouseByte endp

WaitKBCWrite proc near
        push    eax
wait_kb_write:
        in      al, 64h
        test    al, 00000010b
        jnz     wait_kb_write
        pop     eax
        ret
WaitKBCWrite endp

WaitKBCRead proc near
        push    eax
wait_kb_read:
        in      al, 64h
        test    al, 00000001b
        jz      wait_kb_read
        pop     eax
        ret
WaitKBCRead endp
DetectWheel endp

VxD_ICODE_ENDS

;-----------------------------------------------------------------------------
; Control Procedure
;-----------------------------------------------------------------------------
VxD_LOCKED_CODE_SEG

BeginProc WHEELVXD_Control
        Control_Dispatch Device_Init, WHEELVXD_Device_Init
        clc
        ret
EndProc WHEELVXD_Control

VxD_LOCKED_CODE_ENDS

;-----------------------------------------------------------------------------
; I/O Callback for port 60h
;-----------------------------------------------------------------------------
VxD_LOCKED_CODE_SEG

WAIT_FIRST equ 0
WAIT_X     equ 1
WAIT_Y     equ 2
WAIT_WHEEL equ 3

BeginProc IOCallback60

        pushad
        push    ds
        push    es
        push    ss
        pop     ds
        assume  ds:nothing

        test    ecx, Byte_Input or Word_Input or Dword_Input
        jz      output_op

        in      al, 60h
        push    eax

        mov     bl, [packet_state]
        cmp     bl, WAIT_FIRST
        jne     near ptr not_first

        test    al, 00001000b
        jz      near ptr done_input
        mov     [saved_buttons], al
        mov     byte ptr [packet_state], WAIT_X
        jmp     near ptr done_input

not_first:
        cmp     bl, WAIT_X
        jne     near ptr not_x
        mov     [saved_x], al
        mov     byte ptr [packet_state], WAIT_Y
        jmp     near ptr done_input

not_x:
        cmp     bl, WAIT_Y
        jne     near ptr not_y
        mov     [saved_y], al
        cmp     word ptr [v_wheel_supported], 0
        je      near ptr complete_packet
        mov     byte ptr [packet_state], WAIT_WHEEL
        jmp     near ptr done_input

not_y:
        cmp     bl, WAIT_WHEEL
        jne     near ptr done_input
        mov     [saved_wheel], al

complete_packet:
        mov     dl, [old_buttons]
        mov     al, [saved_buttons]
        and     al, 03h
        mov     [old_buttons], al

        cmp     word ptr [v_wheel_supported], 0
        je      no_wheel
        mov     al, [saved_wheel]
        cbw
        mov     edx, [shared_lin]
        test    edx, edx
        jz      no_wheel
        add     word ptr [edx + WHEELSHARE.wAccum], ax
        cmp     word ptr [edx + WHEELSHARE.wSupported], 0
        jne     no_wheel
        mov     word ptr [edx + WHEELSHARE.wSupported], 1
no_wheel:
        mov     byte ptr [packet_state], WAIT_FIRST

done_input:
        pop     eax
        jmp     short callback_exit

output_op:
        xor     eax, eax

callback_exit:
        pop     es
        pop     ds
        popad
        ret

EndProc IOCallback60

VxD_LOCKED_CODE_ENDS

;-----------------------------------------------------------------------------
; API Procedure
;-----------------------------------------------------------------------------
VxD_CODE_SEG

BeginProc WHEELVXD_API_Proc
        and     [ebp.Client_Flags], NOT CF_Mask

        cmp     [ebp.Client_AX], WHEEL_GET_VERSION
        jne     near ptr chk_supported
        mov     [ebp.Client_AX], WHEEL_VERSION
        jmp     near ptr api_exit

chk_supported:
        cmp     [ebp.Client_AX], WHEEL_SUPPORTED
        jne     near ptr chk_delta
        mov     eax, [shared_lin]
        test    eax, eax
        jz      near ptr unsup
        mov     ax, [eax + WHEELSHARE.wSupported]
        mov     [ebp.Client_AX], ax
        jmp     near ptr api_exit
unsup:
        mov     [ebp.Client_AX], 0
        jmp     near ptr api_exit

chk_delta:
        cmp     [ebp.Client_AX], WHEEL_GET_DELTA
        jne     near ptr api_invalid
        mov     eax, [shared_lin]
        test    eax, eax
        jz      near ptr nodelta
        mov     bx, [eax + WHEELSHARE.wAccum]
        mov     [ebp.Client_AX], bx
        mov     word ptr [eax + WHEELSHARE.wAccum], 0
        jmp     near ptr api_exit
nodelta:
        mov     [ebp.Client_AX], 0
        jmp     near ptr api_exit

api_invalid:
        or      [ebp.Client_Flags], CF_Mask

api_exit:
        ret
EndProc WHEELVXD_API_Proc

VxD_CODE_ENDS

        END