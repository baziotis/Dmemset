.intel_syntax noprefix
.text

.align 16
.globl agner_memset
agner_memset:
    
    // Broadcast to all bytes of esi
    imul    esi, 0x01010101;
    // Move it to XMM.
    movd    xmm0, esi;
    // Broadcast it across xmm0.
    pshufd  xmm0, xmm0, 0;
    // Save much used address (pointing to the end).
    lea     rax, [rdi+rdx];

    cmp     rdx, 0x20;
    jbe     LSMALL;


    // Store the first possibly unaligned 16 bytes
    // It is faster to always write 16 bytes, possibly overlapping
    // with the subsequent regular part, than to make possibly mispredicted
    // branches depending on the size of the first part.
    movups  [rdi], xmm0;

    // store another 16 bytes, aligned
    add     rdi, 0x10;
    and     rdi, -0x10;
    movaps  [rdi], xmm0;

    // go to next 32 bytes boundary
    add     rdi, 0x10;
    and     rdi, -0x20;

    // find last 32 bytes boundary
    mov     rdx, rax;
    and     rdx, -0x20;

    // - size of 32-bytes blocks
    sub     rdi, rdx;
    jnb     END;

    vinsertf128 ymm0, ymm0, xmm0, 1;
.align 16
MAIN_LOOP:
    vmovaps [rdx+rdi], ymm0;
    add     rdi, 0x20;
    jnz     MAIN_LOOP;
    vzeroupper;
END:
    movups  [rax-0x20], xmm0;
    movups  [rax-0x10], xmm0;
    ret;

    // <= 32 so move another 16 and return
LSMALL:
    movdqu  [rdi], xmm0;
    movdqu  [rax-0x10], xmm0;
    ret;


