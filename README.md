# japl
JAPL is an interpreted, dynamically-typed and minimalistic programming language

# J.. what?

You may wonder what's the meaning of JAPL: well, it turns out to be an acronym
for Just Another Programming Language, but beware! Despite the name, the name is actually read like "JPL".

## Some backstory

JAPL is born thanks to the amazing work of Bob (whose surname is obscure) that wrote a book available completely for free
at [this](https://craftinginterpreters.com) link.

Even though that books treats the implementation of a basic language named Lox, JAPL is (will, actually) much more feature-rich:

- Possibility to delete variables with the `del` statement
- `break` statement
- Nested comments (__Coming Soon__)
- Generators (__Coming soon__)
- A decent standard library (__Work in progress__)

Other than that, JAPL features closures, function definitions, classes and static scoping. You can check
the provided example `.jpl` files in the repo to find out more about JAPL.

### Disclaimer

This project is currently a WIP (Work in Progress) and is not optimized nor complete.
The first version of the interpreter is written in Python, but there are plans to create a bytecode VM using nim in the near future.

For other useful information, check the LICENSE file in this repo.

### Contributing

If you want to contribute, feel free to send a PR!
