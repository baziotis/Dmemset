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

import std.datetime.stopwatch;
import Dmemset: Dmemset;
import std.random;
import std.stdio;
import core.stdc.string;
import std.traits;

struct S(size_t Size)
{
    ubyte[Size] x;
}

///
///   A big thanks to Mike Franklin (JinShil). A big part of code is taken from his memcpyD implementation.
///

// From a very good Chandler Carruth video on benchmarking: https://www.youtube.com/watch?v=nXaxk27zwlk
void escape(void* p)
{
    version(LDC)
    {
        import ldc.llvmasm;
         __asm("", "r,~{memory}", p);
    }
    version(GNU)
    {
        asm { "" : : "g" p : "memory"; }
    }
}

void clobber()
{
    version(LDC)
    {
        import ldc.llvmasm;
        __asm("", "~{memory}");
    }
    version(GNU)
    {
        asm { "" : : : "memory"; }
    }
}

import core.stdc.string: memset;

void Cmemset(T)(T[] dst, const int v)
{
    pragma(inline, true)
    memset(dst.ptr, v, dst.length * T.sizeof);
}

Duration benchmark(T, alias f)(T[] dst, int v, ulong* bytesCopied)
{
    size_t iterations = 2^^20 / dst.length;
    Duration result;

    auto swt = StopWatch(AutoStart.yes);
    swt.reset();
    while(swt.peek().total!"msecs" < 50)
    {
        auto sw = StopWatch(AutoStart.yes);
        sw.reset();
        foreach (_; 0 .. iterations)
        {
            escape(dst.ptr);   // So optimizer doesn't remove code
            f(dst, v);
        }
        result += sw.peek();
        *bytesCopied += (iterations * dst.length);
    }

    return result;
}

void init(T)(T[] v)
{
    static if (is (T == float))
    {
        v = uniform(0.0f, 9_999_999.0f);
    }
    else static if (is(T == double))
    {
        v = uniform(0.0, 9_999_999.0);
    }
    else static if (is(T == real))
    {
        v = uniform(0.0L, 9_999_999.0L);
    }
    else
    {
        for(int i = 0; i < v.length; i++)
        {
            v[i] = uniform!byte;
        }
    }
}

void verify(string name, T)(int j, const ref T[] a, const int v)
{
    const ubyte *p = cast(const ubyte *) a.ptr;
    for(size_t i = 0; i < a.length * T.sizeof; i++)
    {
        assert(p[i] == cast(const ubyte)v);
    }
}

void verifyBasicType(T)(T *p, const int v)
{
    const ubyte *up = cast(const ubyte *) p;
    for(size_t i = 0; i < T.sizeof; i++)
    {
        assert(up[i] == cast(const ubyte)v);
    }
}

bool average;

import core.stdc.stdio: printf;

void test(T, size_t n)(int v)
{
    T[n + 32] buf;
    
    double TotalGBperSec1 = 0.0;
    double TotalGBperSec2 = 0.0;
    enum alignments = 32;
    size_t len = n;

    foreach(i; 0..alignments)
    {
        auto d = buf[i..i+n];

        ulong bytesCopied1;
        ulong bytesCopied2;
        init(d);
        immutable d1 = benchmark!(T, Cmemset)(d, v, &bytesCopied1);
        verify!("Cmemset")(i, d, v);


        init(d);
        immutable d2 = benchmark!(T, Dmemset)(d, v, &bytesCopied2);
        verify!("Dmemset")(i, d, v);

        auto secs1 = (cast(double)(d1.total!"nsecs")) / 1_000_000_000.0;
        auto secs2 = (cast(double)(d2.total!"nsecs")) / 1_000_000_000.0;
        auto GB1 = (cast(double)bytesCopied1) / 1_000_000_000.0;
        auto GB2 = (cast(double)bytesCopied2) / 1_000_000_000.0;
        auto GBperSec1 = GB1 / secs1;
        auto GBperSec2 = GB2 / secs2;
        if (average)
        {
            TotalGBperSec1 += GBperSec1;
            TotalGBperSec2 += GBperSec2;
        }
        else
        {
            writeln(len, " ", GBperSec1, " ", GBperSec2);
            stdout.flush();
        }
    }

    if (average)
    {
        writeln(len, " ", TotalGBperSec1 / alignments, " ", TotalGBperSec2 / alignments);
        stdout.flush();
    }
}

void testBasicType(T)(const int v) {
    T t;
    Dmemset(&t, v);
    verifyBasicType(&t, v);
}

enum Aligned = true;
enum MisAligned = false;

void main(string[] args)
{
    average = args.length >= 2;

    // For performing benchmarks
    writeln("size(bytes) Cmemmove(GB/s) Dmemmove(GB/s)");
    stdout.flush();
    // IMPORTANT(stefanos): This won't work as they are <= 16
    /*
    testBasicType!(byte)(5);
    testBasicType!(ubyte)(5);
    testBasicType!(short)(5);
    testBasicType!(ushort)(5);
    testBasicType!(int)(5);
    testBasicType!(uint)(5);
    testBasicType!(long)(5);
    testBasicType!(ulong)(5);
    testBasicType!(float)(5);
    testBasicType!(double)(5);
    testBasicType!(real)(5);
    static foreach(i; 16..33) {
        test!(ubyte, i)(5);
    }
    */
    test!(ubyte, 32)(5);
    /*
    test!(ubyte, 100)(5);
    test!(ubyte, 500)(5);
    test!(ubyte, 700)(5);
    test!(ubyte, 3434)(5);
    test!(ubyte, 7128)(5);
    test!(ubyte, 13908)(5);
    test!(ubyte, 16343)(5);
    test!(ubyte, 27897)(5);
    test!(ubyte, 32344)(5);
    test!(ubyte, 46830)(5);
    test!(ubyte, 64349)(5);
    */

    testBasicType!(S!20)(5);
    testBasicType!(S!200)(5);
    testBasicType!(S!2000)(5);
}
