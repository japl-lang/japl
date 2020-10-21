# JAPL - Just Another Programming Language
JAPL is an interpreted, dynamically-typed, garbage-collected and minimalistic programming language with C- and Java-like syntax.

# J.. what?


You may wonder what's the meaning of JAPL: well, it turns out to be an acronym
for __Just Another Programming Language__, but beware! Despite the name, the pronounciation is actually the same as "JPL".

## Disclaimer

This project is currently a WIP (Work in Progress) and is not optimized nor complete.
The design of the language may change at any moment and all the source inside this repo
is alpha code quality, for now. 

For other useful information, check the LICENSE file in this repo.

JAPL is licensed under the Apache 2.0 license.


## Project roadmap

In no particular order, here's a list that is constantly updated and that helps us to keep track
of what's done in JAPL:

- Parsing/Lexing ✅
- Type system  (__Rework Needed__)
- Control flow (if/else)  ✅
- Loops (for/while)  ✅
- Basic comparisons operators (`>`, `<`, `>=`, `<=`, `!=`, `==`) ✅
- Logical operators (`!`, `or`, `and`)  ✅
- Multi-line comments `/* like this */` (can be nested)  ✅
- Differentiation between integers and floating point numbers  ✅
- `inf` and `nan` types  ✅
- Basic arithmetic (`+`, `-`, `/`, `*`)  ✅
- Modulo division (`%`) and exponentiation (`**`)  ✅
- Bitwise operators (AND, OR, XOR, NOT)  ✅
- Global and local variables  (__WIP__)
- Explicit scopes using brackets (__WIP__)
- Garbage collector
- String slicing, with start:end syntax as well  ✅
- Operations on strings (addition, multiplication)  ✅
- Functions and Closures (__WIP__)
- Functions default and keyword arguments (__WIP__)
- An OOP system (prototype- or class-based)  (__Coming soon__)
- A proper import system (__Coming soon__)
- Native asynchronous (`await`/`async fun`) support (__Coming soon__)
- Bytecode optimizations such as constant folding and stack caching (__Coming Soon__)
- Arbitrary-precision arithmetic (__Coming soon__)
- Generators (__Coming soon__)
- A standard library with collections, I/O utilities, scientific modules, etc (__Coming soon__)
- Multithreading and multiprocessing support with a global VM Lock like CPython (__Coming soon__)
- Exceptions (__Coming soon__)
- Optional JIT Compilation (__Coming soon__)



### Classifiers

- __WIP__: Work In Progress, being implemented right now
- __Coming Soon__: Not yet implemented/designed but scheduled
- __Rework Needed__: The feature works, but can (and must) be optimized/reimplemented properly
- ✅: The feature works as intended


## Contributing

If you want to contribute, feel free to send a PR!

Right now there are some major issues with the virtual machine which need to be addressed
before the development can proceed, and some help is ~~desperately needed~~ greatly appreciated!

To get started, you might want to have a look at the currently open issues and start from there


## Community

Our first goal is to create a welcoming and helpful community, so if you are so inclined,
you might want to join our [Discord server](https://discord.gg/P8FYZvM)! We can't wait to welcome you into
our community :D


## A special thanks

JAPL is born thanks to the amazing work of Bob Nystrom that wrote a book available completely for free
at [this](https://craftinginterpreters.com) link, where he describes the implementation of a simple language called Lox.

