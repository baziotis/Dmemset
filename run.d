#!/usr/bin/rdmd

import std.array;
import std.process;
import std.stdio;
import std.getopt;

int run(string cmd)
{
    writeln(cmd);
    auto pid = spawnProcess(cmd.split(' '));
    return wait(pid);
}

void main(string[] args)
{
    auto help = getopt(args);
    if (help.helpWanted || args.length != 2 || (args[1] != "tests" && args[1] != "benchmarks"))
    {
        writeln("USAGE: rdmd run tests|benchmarks");
        return;
    }

    string compile, execute;

    if (args[1] == "tests")
    {
        version (x86_64)
        {
            compile = "rdmd -m64 -O -inline --build-only tests.d Dmemset.d";
        }
        else
        {
            compile = "rdmd -O -inline --build-only tests.d Dmemset.d";
        }
        execute = "./tests";
    }
    else
    {
        version (x86_64)
        {
            compile = "rdmd -m64 -O -inline --build-only benchmarks.d Dmemset.d";
        }
        else
        {
            compile = "rdmd -O -inline --build-only benchmarks.d Dmemset.d";
        }
        execute = "./benchmarks";
    }
    if(run(compile) != 0)
    {
        return;
    }
    run(execute);
}
