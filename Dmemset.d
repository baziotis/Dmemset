/*
Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

import core.stdc.string: memset;

void Cmemset(T)(T[] dst, const int v)
{
    pragma(inline, true)
    memset(dst.ptr, v, dst.length * T.sizeof);
}

import core.stdc.stdio: printf;

bool isPowerOf2(T)(T x)
    if (isIntegral!T)
{
    return (x != 0) && ((x & (x - 1)) == 0);
}

// IMPORTANT(stefanos): memset is supposed to return the dest
void Dmemset(T)(T[] dst, const int val)
{
    size_t n = dst.length * T.sizeof;

    if(n <= 16) {
        void *d = dst.ptr;
        int v = val * 0x01010101;  // Broadcast c to all 4 bytes
        // NOTE(stefanos): Hope for a jump table.
        // TODO(stefanos): Can `mixin` help?
        // IMPORTANT(stefanos): This switch generates weird code. It actually seems wrong.
        switch (n) {
            case 16:
                *(cast(uint*)(d+12)) = v;
                goto case 12;
            case 12:
                *(cast(uint*)(d+8)) = v;
                goto case 8;
            case 8:
                *(cast(uint*)(d+4)) = v;
                goto case 4;
            case 4:
                *(cast(uint*)d) = v;
            return;

            case 15:
                *(cast(uint*)(d+11)) = v;
                goto case 11;
            case 11:
                *(cast(uint*)(d+7)) = v;
                goto case 7;
            case 7:
                *(cast(uint*)(d+3)) = v;
                goto case 3;
            case 3:
                *(cast(ushort*)(d+1)) = cast(ushort)v;
                goto case 1;
            case 1:
                *(cast(ubyte*)d) = cast(ubyte)v;
            return;

            case 14:
                *(cast(uint*)(d+10)) = v;
                goto case 10;
            case 10:
                *(cast(uint*)(d+6)) = v;
                goto case 6;
            case 6:
                *(cast(uint*)(d+2)) = v;
                goto case 2;
            case 2:
                *(cast(ushort*)d) = cast(ushort)v;
            return;

            case 13:
                *(cast(uint*)(d+9)) = v;
                goto case 9;
            case 9:
                *(cast(uint*)(d+5)) = v;
                goto case 5;
            case 5:
                *(cast(uint*)(d+1)) = v;
                *(cast(ubyte*)d) = cast(ubyte)v;
            return;

            default: assert(0);
        }
    } else {
        // opt_memset code.
        asm pure nothrow @nogc {
            naked;
            // Broadcast to all bytes of EDI
            imul    EDI, 0x01010101;
            // Move it to XMM.
            movd    XMM0, EDI;
            // Broadcast it across XMM0.
            // Use this if available:
            // vpbroadcastd XMM0, EDI;
            pshufd  XMM0, XMM0, 0;
            // Save much used address.
            lea     RAX, [RDX+RSI-0x10];

            cmp     RSI, 0x1f;
            ja      LBIG;

            // <= 32
            movdqu  [RDX], XMM0;
            movdqu  [RAX], XMM0;
            ret;

        LBIG:
            mov     RCX, RDX;
            and     RCX, 0x1f;
            vinsertf128 YMM0, YMM0, XMM0, 1;
            
            vmovdqu [RDX], YMM0;
            mov     R9, 32;
            sub     R9, RCX;

            add     RDX, R9;
            sub     RSI, R9;
            // Align to 32-byte boundary, let END handle
            // remaining bytes.
            and     RSI, -0x20;
            cmp     RSI, 32;
            jb      END;
        MAIN_LOOP:
            vmovdqa [RDX], YMM0;
            add     RDX, 32;
            sub     RSI, 32;
            jg      MAIN_LOOP;
        END:
            vmovdqu  [RAX-0x10], YMM0;
            vzeroupper;
            ret;
        }
    }
}
