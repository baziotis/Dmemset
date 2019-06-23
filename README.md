# Dmemset

This is part of my [Google Summer of Code project](https://summerofcode.withgoogle.com/organizations/6103365956665344/#5475582328963072), _Independency of D from the C Standard Library_.

It is a public repository for the work on the `memset()` replacement.

## Compile and Run
### Run the test suite
This suites verifies that `Dmemset` works correctly.

`rdmd run tests`

This will compile with `-O -inline`. Refer to the `run.d` file for more info and `tests.d` to see the test suite code.

### Run the benchmark suite
This suite benchmarks `Dmemset` against `memset()` of the C Standard Library.

`rdmd run benchmarks`

This will compile with `-O -inline`. Refer to the `run.d` file for more info and `tests.d` to see the benchmark suite code.

### Contact Info

E-mail: sdi1600105@di.uoa.gr

If you are involved in D, you can also ping me on Slack (Stefanos Baziotis), or post in the dlang forum thread above.
