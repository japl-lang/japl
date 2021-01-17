# JAPL - Just Another Programming Language

JAPL is an interpreted, dynamically-typed, garbage-collected, and minimalistic programming language with C- and Java-like syntax.

## J.. what?

You may wonder what's the meaning of JAPL: well, it turns out to be an acronym for __Just Another Programming Language__, but beware! Despite the name, the pronunciation is the same as "JPL".

### Disclaimer

This project is currently a WIP (Work in Progress) and is not optimized nor complete.
The design of the language may change at any moment and all the source inside this repo is alpha code quality, for now.  

For other useful information, check the LICENSE file in this repo.  

JAPL is licensed under the Apache 2.0 license.

### Project roadmap

In no particular order, here's a list that is constantly updated and that helps us to keep track
of what's done in JAPL:

- [x] Parsing/Lexing
- [x] Type system (string, integer, float)
- [ ] Builtin collections (arraylist, mapping, tuple, set)
- [x] Builtin functions (`print`, etc)
- [ ] An import system
- [x] Control flow (if/else)
- [x] Loops (for/while)
- [x] Comparisons operators (`>`, `<`, `>=`, `<=`, `!=`, `==`)
- [x] Casting with the `as` operator
- [x] Modulo division (`%`) and exponentiation (`**`)
- [x] Bitwise operators (AND, OR, XOR, NOT)
- [x] Simple optimizations (constant string interning, singletons caching)
- [ ] Garbage collector (Mark & Sweep)
- [x] Operations on strings (addition, multiplication -> TODO both sides)
- [x] Functions
- [ ] Closures
- [ ] Functions default and keyword arguments
- [ ] An OOP system (class-based)
- [x] Global and local variables
- [x] Explicit scopes using bracket
- [ ] Native asynchronous (`await`/`async fun`) support 
- [ ] Bytecode optimizations such as constant folding and stack caching 
- [x] Lambda functions as inline expressions
- [ ] Arbitrary-precision arithmetic
- [x] Multi-line comments `/* like this */` (can be nested)
- [ ] Generators 
- [ ] A standard library
- [x] String slicing, with start:end syntax as well
- [ ] Multithreading and multiprocessing support with a global VM Lock like CPython
- [ ] Exceptions 
- [x] Logical operators (`not`, `or`, `and`, `is`)
- [x] Basic arithmetic (`+`, `-`, `/`, `*`)
- [ ] Optional JIT Compilation 
- [ ] Static type checker (compiler module)
- [ ] Runtime Type Checking
- [x] 0-argument functions without ()


## Contributing

If you want to contribute, feel free to open a PR!

Right now there are some major issues with the virtual machine which need to be addressed before the development can proceed, and some help is ~~desperately needed~~ greatly appreciated!

To get started, you might want to have a look at the currently open issues and start from there

### Community

Our first goal is to create a welcoming and helpful community, so if you are so inclined, you might want to join our [Discord server](https://discord.gg/P8FYZvM) and our [forum](https://forum.japl-lang.com)! We can't wait to welcome you into our community :D

### A special thanks

JAPL is born thanks to the amazing work of Bob Nystrom that wrote a book available completely for free at [this](https://craftinginterpreters.com) link, where he describes the implementation of a simple language called Lox.

## JAPL - Installing

JAPL is currently in its early stages and is therefore in a state of high mutability, so this installation guide might
not be always up to date.

### Requirements

To compile JAPL, you need the following:

- Nim >= 1.2 installed on your system
- Git (to clone the repository)
- Python >= 3.6 (Build script)

### Cloning the repo

Once you've installed all the required tooling, you can clone the repo with the following command

```bash
git clone https://github.com/japl-lang/japl
```

### Running the build script

As a next step, you need to run the build script. This will generate the required configuration files, compile the JAPL runtime and run tests (unless `--skip-tests` is passed). There are some options that can be tweaked with command-line options, for more information, run `python3 build.py --help`.

To compile the JAPL runtime, you'll first need to move into the project's directory you cloned before, so run `cd japl`, then `python3 build.py ./src` and wait for it to complete. You should now find an executable named `japl` (or `japl.exe` on windows) inside the `src` folder.

If you're running under windows, you might encounter some issues when using forward-slashes as opposed to back-slashes in paths, so you should replace `./src` with `.\src`

If you're running under linux, you can also call the build script with `./build.py` (assuming python is installed in the directory indicated by the shebang at the top of the file)

### Advanced builds

If you need more customizability or want to enable debugging for JAPL, there's a few things you can do.

### Nim compiler options

The build tool calls the system's nim compiler to build JAPL. If you want to customize the options passed to the compiler, you can pass a comma separated list of key:value options (spaces are not allowed). For example, doing `python3 build.py src --flags d:release,threads:on` will call `nim compile src/japl -d:release --threads:on`.

#### Known issues

Right now JAPL is in its very early stages and we've encountered a series of issues related to nim's garbage collection implementations. Some of them
seem to clash with JAPL's own memory management and cause random `NilAccessDefects` because the GC frees stuff that JAPL needs. If the test suite shows
weird crashes try changing the `gc` option to `boehm` (particularly recommended since it seems to cause very little interference with JAPL), or `regions` 
to see if this mitigates the problem; this is a temporary solution until JAPL becomes fully independent from nim's runtime memory management.

### JAPL Debugging options

JAPL has some (still very beta) internal tooling to debug various parts of its ecosystem (compiler, runtime, GC, etc).
There are also some compile-time constants (such as the heap grow factor for the garbage collector) that can be set via the `--options` parameter in the same fashion as the nim's compiler options. The available options are:

- `debug_vm` -> Debugs the runtime, instruction by instruction, showing the effects of the bytecode on the VM's stack and scopes in real time (beware of bugs!)
- `debug_gc` -> Debugs the garbage collector (once we have one)
- `debug_alloc` -> Debugs memory allocation/deallocation
- `debug_compiler` -> Debugs the compiler, showing each byte that is spit into the bytecode

Each of these options is independent of the others and can be enabled/disabled at will. To enable an option, pass `option_name:true` to `--options` while to disable it, replace `true` with `false`.

Note that the build tool will generate a file named `config.nim` inside the `src` directory and will use that for subsequent builds, so if you want to override it you'll have to pass `--override-config` as a command-line options. Passing it without any option will fallback to (somewhat) sensible defaults

**P.S.**: The test suite assumes that all debugging options are turned off, so for development/debug builds we recommend skipping the test suite by passing `--skip-tests` to the build script


### Installing on Linux

If you're on linux and can't stand the fact of having to call japl with `./src/japl`, we have some good news! The build script can
optionally move the compiled binary in the first writeable entry inside your PATH so that you can just type `jpl` inside your terminal
to open the REPL. To avoid issues, this option is disabled by default and must be turned on by passing `--install`, but note that
if in _any_ directory listed in PATH there is either a file or a folder named `jpl` the build script will complain about it and refuse to overwrite
the already existing data unless `--ignore-binary` is passed!

### Environment variables

On both Windows and Linux, the build script supports reading parameters from environment variables if they are not specified via the command line.
All options follow the same naming scheme: `JAPL_OPTION_NAME=value` and will only be applied only if no explicit override for them is passed
when running the script
