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

bool isPowerOf2(T)(T x)
    if (isIntegral!T)
{
    return (x != 0) && ((x & (x - 1)) == 0);
}

// NOTE(stefanos): Hope for a jump table.
// TODO(stefanos): Can `mixin` help?
extern(C) void Dmemset_small(void *d, const int val, size_t n) {
    const int v = val * 0x01010101;  // Broadcast c to all 4 bytes
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
}

// IMPORTANT(stefanos): memset is supposed to return the dest
extern(C) void Dmemset(void *d, const int val, size_t n)
{
	version (Windows) {
		// Move to Posix registers due to different calling convention.
		asm pure nothrow @nogc {
			naked;
			mov RDI, RCX;
			mov ESI, EDX;
			mov RDX, R8;
		}
	}
	asm pure nothrow @nogc {
		naked;
		cmp RDX, 0x10;
		ja LARGE;
	}

	version (Windows) {
		asm pure nothrow @nogc {
			// NOTE(stefanos): If you try to call a function, don't forget
			// to subtract 0x20 from RSP before the call and add them after.
			
			// Naive implementation as the call did not work.
			// NOTE(stefanos): Getting the low byte part of ESI (it is SIL) did not
			// generate correct ASM.
		LOOP:
			mov [RDI], ESI;
			add RDI, 1;
			sub RDX, 1;
			ja  LOOP;
			ret;
		}
	}
	else
	{
		asm pure nothrow @nogc {
			call Dmemset_small;
		}
	}
	asm pure nothrow @nogc {

		ret;
	LARGE:
		// Broadcast to all bytes of ESI
		imul    ESI, 0x01010101;
		// Move it to XMM.
		movd    XMM0, ESI;
		// Broadcast it across XMM0.
		// Use this if available:
		// vpbroadcastd XMM0, ESI;
		pshufd  XMM0, XMM0, 0;
		// Save much used address.
		lea     RAX, [RDI+RDX-0x10];
    
		cmp     RDX, 0x20;
		ja      LBIG;
    
		// <= 32
		movdqu  [RDI], XMM0;
		movdqu  [RAX], XMM0;
		ret;
    
	LBIG:
		mov     RCX, RDI;
		// RCX = RDI & 0x1f aka dst % 32
		and     RCX, 0x1f;
		vinsertf128 YMM0, YMM0, XMM0, 1;
        
		/// Reach 32-byte alignment
		// move first 32 bytes
		vmovdqu [RDI], YMM0;
		// R9 = 32 - mod
		mov     R9, 32;
		sub     R9, RCX;
    
		// dst += 32 - mod
		add     RDI, R9;
		// n -= 32 - mod
		sub     RDX, R9;

		cmp     RDX, 32;
		jb      END;

		// Align to 32-byte boundary, let END handle
		// remaining bytes.
		and     RDX, -0x20;
	MAIN_LOOP:
		// NOTE(stefanos): If you move this -0x20 above, it may cause
		// underflow.
		vmovdqa [RDI+RDX-0x20], YMM0;
		sub     RDX, 32;
		jg      MAIN_LOOP;
		vmovdqa [RDI], YMM0;
	END:
		vmovdqu  [RAX-0x10], YMM0;
		vzeroupper;
		ret;
	}
}

extern(C) void Dmemset_naive(ubyte *dst, const int val, size_t n) {
    for (size_t i = 0; i != n; ++i) {
        dst[i] = cast(ubyte)val;
    }
}

import core.stdc.stdio: printf;

// NOTE(stefanos):
// 1) Naive is faster for very small sizes.
// 2) Range-checking is not needed since we never
// 	  pass an `n` (byte count) ourselves.

void Dmemset(T)(T[] dst, const int val)
{
    version (X86_64)
    {
        Dmemset(dst.ptr, val, dst.length * T.sizeof);
    }
    else
    {
        Dmemset_naive(dst.ptr, val, dst.length * T.sizeof);
    }
}

import std.traits;

void Dmemset(T)(ref T dst, const int val)
    if(isStaticArray!T)
{
    version (X86_64)
    {
        Dmemset(dst.ptr, val, dst.length * T.sizeof);
    }
    else
    {
        Dmemset_naive(dst.ptr, val, dst.length * T.sizeof);
    }
}

void Dmemset(T)(T *dst, const int val) {
    version (X86_64)
    {
        Dmemset(dst, val, T.sizeof);
    }
    else
    {
        Dmemset_naive(dst, val, T.sizeof);
    }
}
