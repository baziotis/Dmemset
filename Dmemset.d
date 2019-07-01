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

extern(C) void Dmemset(void *d, const uint val, size_t n)
{
    import core.simd: int4;
    version (LDC)
    {
        import ldc.simd: loadUnaligned, storeUnaligned;
    }
    else
    version (DigitalMars)
    {
        import core.simd: void16, loadUnaligned, storeUnaligned;
    }
    else
    {
        static assert(0, "Version not supported");
    }

    void store32_sse(void *dest, int4 reg)
    {
        version (LDC)
        {
            storeUnaligned!int4(reg, cast(int*)dest);
            storeUnaligned!int4(reg, cast(int*)(dest+0x10));
        }
        else
        {
            storeUnaligned(cast(void16*)dest, reg);
            storeUnaligned(cast(void16*)(dest+0x10), reg);
        }
    }

    void store16_sse(void *dest, int4 reg)
    {
        version (LDC)
        {
            storeUnaligned!int4(reg, cast(int*)dest);
        }
        else
        {
            storeUnaligned(cast(void16*)dest, reg);
        }
    }

    void broadcast_int(ref int4 xmm, int v)
    {
        xmm[0] = v;
        xmm[1] = v;
        xmm[2] = v;
        xmm[3] = v;
    }

    const uint v = val * 0x01010101;            // Broadcast c to all 4 bytes

    // NOTE(stefanos): I use the naive version, which in my benchmarks was slower
    // than the previous classic switch. BUT. Using the switch had a significant
    // drop in the rest of the sizes. It's not the branch that is responsible for the drop,
    // but the fact that it's more difficult to optimize it as part of the rest of the code.
    if (n <= 16)
    {
        Dmemset_naive(cast(ubyte*)d, cast(ubyte)val, n);
        return;
    }
    void *temp = d + n - 0x10;                  // Used for the last 32 bytes

    int4 xmm0;
    // Broadcast v to all bytes.
    broadcast_int(xmm0, v);

    ubyte rem = cast(ulong)d & 15;              // Remainder from the previous 16-byte boundary.
    // Store 16 bytes, from which some will possibly overlap on a future store.
    // For example, if the `rem` is 7, we want to store 16 - 7 = 9 bytes unaligned,
    // add 16 - 7 = 9 to `d` and start storing aligned. Since 16 - `rem` can be at most
    // 16, we store 16 bytes anyway.
    store16_sse(d, xmm0);
    d += 16 - rem;
    n -= 16 - rem;

    // Move in blocks of 32.
    // TODO(stefanos): Experiment with differnt sizes.
    if (n >= 32)
    {
        // Align to (previous) multiple of 32. That does something invisible to the code,
        // but a good optimizer will avoid a `cmp` instruction inside the loop. With a
        // multiple of 32, the end of the loop can be (if we assume that `n` is in RDX):
        // sub RDX, 32;
        // jge START_OF_THE_LOOP.
        // Without that, it has to be:
        // sub RDX, 32;
        // cmp RDX, 32;
        // jge START_OF_THE_LOOP
        // NOTE, that we align on a _previous_ multiple (for 37, we will go to 32). That means
        // we have somehow to compensate for that, which is done at the end of this function.
        n &= -32;
        do
        {
            store32_sse(d, xmm0);
            // NOTE(stefanos): I tried avoiding this operation on `d` by combining
            // `d` and `n` in the above loop and going backwards. It was slower in my benchs.
            d += 32;
            n -= 32;
        } while(n >= 32);
    }
    // Compensate for the last (at most) 32 bytes.
    store32_sse(temp-0x10, xmm0);
}

extern(C) void Dmemset_naive(ubyte *dst, const ubyte val, size_t n)
{
    for (size_t i = 0; i != n; ++i)
    {
        dst[i] = val;
    }
}

// NOTE(stefanos):
// Range-checking is not needed since we never
// pass an `n` (byte count) ourselves.

import std.traits;
import std.stdio;

void Dmemset(T)(ref T dst, const ubyte val)
{
    const uint v = cast(int)val;
    version (X86_64)
    {
        static if (isArray!T)
        {
            // NOTE(stefanos): We need to get the element type of the array.
            size_t n = dst.length * typeof(dst[0]).sizeof;
            Dmemset(dst.ptr, v, n);
        }
        else
        {
            Dmemset(&dst, v, T.sizeof);
        }
    }
    else
    {
        static if (isArray!T)
        {
            // NOTE(stefanos): We need to get the element type of the array.
            Dmemset_naive(dst.ptr, val, dst.length * typeof(dst[0]).sizeof);
        }
        else
        {
            Dmemset_naive(&dst, val, T.sizeof);
        }
    }
}
