;===================================================
;       x86 executable junk code generator
;(c) adversarial 2020, released under MIT License
;===================================================


; int gen_junk(__out_deref void* lpOut, size_t cbOut)
;
; build with fasm (http://flatassembler.net)
;
; exports one function that returns count of bytes generated
; test included: comment out "format MS COFF" and "public ..."
; remove comments on "format PE", "entry main",
; code in "main:", and "executable" flag in .data header

format MS COFF
;format PE GUI 6.0 NX on 'nul'
;entry main

include 'win32a.inc'

public gen_junk as '_gen_junk@8'

;======== Constants ====================
OP_ADD  = 0
OP_OR   = 1
OP_ADC  = 2
OP_SBB  = 3
OP_AND  = 4
OP_SUB  = 5
OP_XOR  = 6
OP_CMP  = 7

OP_MOV  = $b0
F_MOV_WIDE = $08

MASK_WIDE_GPR_ONLY = $03

OP_RET  = $c3

; ALU opcode flags
F_WIDE  = $01
F_DIR   = $02
F_ACCUM = $04
;=======================================

;======= Code ==========================
section '.text' code readable executable
;=======================================
;main:
;        mov edi, something
;        mov esi, $100
;        stdcall gen_junk,edi,esi
;        add edi, eax
;        mov eax, OP_RET
;        stosb
;        call something
;        ret

; int gen_junk(__out_deref void* lpOut, size_t cbOut);
gen_junk:
        push ebx esi edi ebp

        mov edi, [esp+4*4+4*1]          ; lpOut
        mov ebp, [esp+4*4+4*2]          ; cbOut
        mov esi, ebp

    .gen_instr:
        call gen_logical
        sub ebp, ecx
        cmp ebp, $5
        jb .done
        rdtsc
        test eax, $4
        jl .gen_instr
    .gen_movinstr:
        call gen_mov
        sub ebp, ecx
        cmp ebp, $5
        jl .done
        jmp .gen_instr

    .done:
        sub esi, ebp                    ; cbOut - remaining space = num generated
        mov eax, esi                    ; num bytes generated
                                        ; always (cbOut - n(<5))
        pop ebp edi esi ebx
        ret 4*2


; generates a mov r8/32, imm8/32
;
;           wide
;             |
;    1 0 1 1  1 0 0 0
;    |_____|
;       |
;   mov imm
;
; in: edi - buffer to output to
; out: ecx - size of opcode
gen_mov:
        push eax edx

        stdcall rand,eax
        pop edx

        test edx, edx     ; flag for 8 or 32
        mov al, OP_MOV
        mov ecx, 2        ; sizeof.mov r8, imm8
        js .mov_8
  .mov_32:
        or al, F_MOV_WIDE
        mov ecx, 5        ; sizeof.mov r32, imm32
        and dl, MASK_WIDE_GPR_ONLY     ; reg code & 4 is [ esi, edi, esp, ebp ]
  .mov_8:
        mov ah, dl
        and ah, $07       ; get register code
        or al, ah
        stosb

  .mov_regimm:
        stdcall rand,eax
        pop eax
        test edx, edx
        js .mov_8_imm
    .mov_32_imm:
        stosd
        jmp .done
    .mov_8_imm:
        stosb

  .done:
        pop edx eax
        ret

; generates a logical math operation
;
;   unused
;     _|       direction
;    | |           |
;    0 0  0 0 0  0 0 0
;         |___|  |_  |_____
;           |      |      |
;       operation  |      |
;             accumulator |
;                        wide
;
; this applies to all opcodes < 0100 (if opcode & 7 < 6)
;
; operation:
;       specifies a logical operation from 0-7 (see constants section)

; accumulator:
;       dest is accumulator, src is immediate after opcode, no modrm byte
; direction:
;       if not set, src may be r/m, otherwise dest is r/m
; wide:
;       if set, then operation is wide (r/m32), otherwise operation is 8 bit
;
; in: edi - buffer to output to
; out: ecx - size of opcode
gen_logical:
        push eax ebx edx

        xor eax, eax

  .invalid_op:
        stdcall rand,eax
        pop edx
        and edx, $ffff0707

        mov al, dl       ; operation octet
        shl al, 3
        or al, dh       ; settings octet
        mov ah, al
        and ah, $07
        cmp ah, 5       ; if opcode > 5, then it's a push/pop segreg
        ja .invalid_op  ; or other non-logical instruction

        stosb           ; we've constructed the opcode

        test al, F_ACCUM
        jnz .accum_regimm

  .logical_regreg:
        stdcall rand,eax
        pop edx         ; generate new magic for regs
        and edx, $07070707 ; nibble octet mask

        test al, F_WIDE ; prevent generating non-gpr instructions
        jz @f
        and edx, $07030703 ; lo nibble octet hi bit (04) is non-gpr
  @@:
        shl eax, 8      ; ah contains opcode
        mov al, dl      ; set modrm.reg field
        shl al, 3       ; shift into place

        ror edx, 16     ; get next field
        or al, dl       ; set modrm.rm field

        or al, $c0      ; 0x3 modrm.mod == reg-reg

        stosb           ; output modrm byte
        mov ecx, 2
        jmp .done

  .accum_regimm:
        stdcall rand,eax
        pop edx         ; generate a new imm

        test al, F_WIDE
        jnz .accum_imm32

    .accum_imm8:
        mov al, dl
        stosb
        mov ecx, 2
        jmp .done

    .accum_imm32:
        mov eax, edx
        stosd
        mov ecx, 5
        jmp .done

  .done:
        pop edx ebx eax
        ret


; void cdecl rand(uint32_t dummy)
; returns 32 bit value in stack allocated by called
; e.g. push eax
;      call rand
;      pop eax
rand:
        push eax edx
     ; wat
        rdtsc
        not eax
        xor [rand_seed], eax
     ; wat
        mov eax, [rand_seed]
        mov edx, $0019660D
        mul edx
        add eax, $3C6EF35F
        mov dword [rand_seed], eax
        mov [esp+4*2+4*1], eax

        pop edx eax
        ret

;======================================
section '.data' data readable writeable ;executable
;======================================
        rand_seed dd $ffffffff
;        something db ?
