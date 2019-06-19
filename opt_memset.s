.intel_syntax noprefix
.text

.align 16
.globl opt_memset
opt_memset:
// Broadcast to all bytes of esi
    imul    esi, esi, 0x01010101;
    // Move it to xmm.
    movd    xmm0, esi;
    // Broadcast it across xmm0.
    // Use this if available:
    // vpbroadcastd xmm0, esi;
    pshufd  xmm0, xmm0, 0;
    // Save much used address.
    lea     rax, [rdi+rdx-0x10];
    
    cmp     rdx, 0x1f;
    ja      LBIG;
    
    // <= 32
    movdqu  [rdi], xmm0;
    movdqu  [rax], xmm0;
    ret;

LBIG:
    mov     rcx, rdi;
    and     rcx, 0x1f;
    vinsertf128 ymm0, ymm0, xmm0, 1;
    je      MAIN_LOOP;
    
    vmovdqu [rdi], ymm0;
    mov     R9, 32;
    sub     R9, rcx;
    
    add     rdi, R9;
    sub     rdx, R9;
    cmp     rdx, 32;
    jb      END;
.align 16
MAIN_LOOP:
    vmovdqa [rdi], ymm0;
    add     rdi, 32;
    sub     rdx, 32;
    cmp     rdx, 32;
    jge     MAIN_LOOP;
END:
    vmovdqu  [rax-0x10], ymm0;
    vzeroupper;
    ret;

