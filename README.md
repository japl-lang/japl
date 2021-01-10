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

- [x] Parsing/Lexin
- [x] Object oriented type system
- [x] Control flow (if/else)
- [x] Loops (for/while)
- [x] Basic comparisons operators (`>`, `<`, `>=`, `<=`, `!=`, `==`)
- [x] Logical operators (`!`, `or`, `and`)  (:heavy_check_mark:)
- [x] Multi-line comments `/* like this */` (can be nested)
- [x] `inf` and `nan` types
- [x] Basic arithmetic (`+`, `-`, `/`, `*`)
- [x] Modulo division (`%`) and exponentiation (`**`)
- [x] Bitwise operators (AND, OR, XOR, NOT)
- [x] Global and local variables
- [x] Explicit scopes using bracket
- [x] Simple optimizations (constant string interning, singletons caching
- [ ] Garbage collector  (__Coming soon__)
- [x] String slicing, with start:end syntax as well
- [x] Operations on strings (addition, multiplication)
- [ ] Functions and Closures (__WIP__)
- [ ] Functions default and keyword arguments (__WIP__)
- [ ] An OOP system (class-based)  (__Coming soon__)
- [ ] Builtins as classes (types) (__Coming soon__)
- [ ] A proper import system (__Coming soon__)
- [ ] Native asynchronous (`await`/`async fun`) support (__Coming soon__)
- [ ] Bytecode optimizations such as constant folding and stack caching (__Coming Soon__)
- [ ] Arbitrary-precision arithmetic (__Coming soon__)
- [ ] Generators (__Coming soon__)
- [ ] A standard library with collections, I/O utilities, scientific modules, etc (__Coming soon__)
- [ ] Multithreading and multiprocessing support with a global VM Lock like CPython (__Coming soon__)
- [ ] Exceptions (__Coming soon__)
- [ ] Optional JIT Compilation (__Coming soon__)

### Classifiers

- __WIP__: Work In Progress, being implemented right now
- __Coming Soon__: Not yet implemented/designed but scheduled
- __Rework Needed__: The feature works, but can (and must) be optimized/reimplemented properly
- [x] : The feature works as intended

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

The build tool calls the system's nim compiler to build JAPL and by default, the only extra flag that's passed to it is `--gc:markAndSweep`. If you want to customize the options passed to the compiler, you can pass a comma separated list of key:value options (spaces are not allowed). For example, doing `python3 build.py src --flags d:release,threads:on` will call `nim compile src/japl --gc:markAndSweep -d:release --threads:on`.

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
