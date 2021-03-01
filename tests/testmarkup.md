# JATS test markup specification

This document specifies the format tests are written
in for JATS (Just Another Test Suite).

## Definitions

A **test file** represents a file inside the `~japl/tests/japl/` directory. All of these files are parsed
to find any defined tests.

A test file can contain multiple tests. A **test** is a
piece of JAPL source code, along with its input
(given in stdin) and expected output (in stdout and stderr), or the means to construct these fields. It
may also contain other metadata, such as the name 
of the test, or whether it is to be skipped.

The test files are parsed line by line. The parser
switches **modes** during the parsing. The modes
dictate the state of the parser, and where each line
ends up (which field of which test).

There is a special mode, **root mode**, which describes
the state of the parser when it just enters the file.
It can stay in this state during parsing, can leave
it by entering another mode and can
return to it, by leaving any mode it has entered.

## Test files

Must be utf-8 (for now only ascii was tested).
Must not contain a BOM. Line endings must be a single 
`\n`. Please configure your editor to support this.

## Syntax

### Mode syntax

The modes are constructed from modelines,
which are lines starting with the character '[', or alternatively
they can also start with the sequence "//[".
Modelines also have to be closed by a ']' character
on the end of this line. These lines may not contain
whitespace before the opening '[' or "//[" nor after then ending
']' characters. Inside the brackets, letters (case
insensitive), numbers, underscores and dashes form
a name describing what the modeline does.

```
[ name ]
//[ name ]
```

Optionally, an argument may be passed, which is 
separated by a colon.

```
[ name : detail ]
//[name: detail]
```

Whitespace inside the brackets is ignored (even inside
names). More than one colon, or any character that
is not whitespace, a letter, a digit, a colon, an 
underscore or a dash inside is a syntax error, which
results in a fatal error, causing the whole test
file to be invalid. The user is always warned when
such a fatal syntax error occurs.

It is possible for lines beginning with '[' to not
be modelines. When a line starts with '[[', it escapes
the opening left bracket, as if the line was a regular
one (the '[[' is reduced to '['). When a line starts
with '[;' it is a comment, which is not a modeline nor
a line that shows up in the current mode.

A different mode can be entered and left by the 
following syntax.

```
[Modename]

[end]
```

A modeline that is not defined to be a legal one 
for the current mode is a syntax error, which
invalidates the whole test file. It also raises 
a visible warning to the user.

## Possible modes

### Root mode

Inside the root mode, all lines that are not modelines
are assumed to be comments.

There is one possible mode to enter from the root mode,
a test mode. The test modes are entered when the "test"
mode line is specified. The detail for the modeline
corresponds to the name of the test.

```
[test: testname]

[end]
```

### Test modes

Inside test modes, all lines that are not modelines are
assumed to be comments.

There are different modelines that do actions or
modes that can be entered from tests. They are all
defined below.

#### Skipping a test

The modeline `skip` skips a test. It does not enter
a different mode, so no `end` is neccessary.

```
[skip]
```

#### Adding JAPL source to a test

The modeline `source` enters the mode source, which
is useful for appending to the JAPL source of the
test.
```
[source]
print("Hello from JAPL!");
[end]
```

There are two kinds of source modes, raw and mixed.
Mixed source mode can be entered if the detail `mixed`
is specified. Raw source mode can be entered if the
detail `raw` is specified. When no detail is specified,
raw source mode is assumed.

In raw source mode, all lines in the mode are
appended as they are to the JAPL source. In mixed
mode, comments inside this JAPL source can be
added to add lines to the expected stdout/stderr or
the stdin of the test using the legacy test format.

They are defined by the sequences `//stdout:`, 
`//stderr:`, `//stdin:`, `//matchout:` and 
`//matcherr:`. Every character after the colon and
before the end of the line is appended to the respective
field of the test. `stdout` adds a raw line to be
matched to the expected stdout of the test. `matchout`
adds a regex to match a line of the stdout of the test.
`stderr` and `matcherr` are the stderr equivalents.
`stdin` adds a line to the stdin that the JAPL source
can read from.

```
[source: mixed]
print("Hello from JAPL!");//stdout:Hello from JAPL!
[end]
```

#### Adding expected output to the test

The mode `stdout` can add standard output to expect
from the JAPL source when it is ran.

```
[test: hello]
[source: raw]
print("Banana.");
[end]
[stdout]
Banana.
[end]
[end]
```

The option `re` can be added if every line is to
be a regex matched against a line of stdout.
The option `nw` will strip leading and trailing 
whitespace from every line in the mode before
adding it to the expected lines. The option `nwre`
adds regex based matching lines after stripping
whitespace.

The mode `stderr` does the same as `stdout`, but
for the standard error. It accepts the same options.

#### Adding input to the test

The mode `stdin` can add standard input that the
JAPL source of the test can read from.

```
[test: inputtest]
[source: raw]
print(readLine());
[end]
[stdin]
Hello there
[end]
[stdout]
Hello there
[end]
```

#### Adding python to the tests

Coming soon.

# Best practices

Tests should be written so that they are valid jpl code. The test title
and modes surrounding source code should be prefixed with `//`. Stdin/stdout 
and other raw non-jpl sources should be inside `/* */` blocks. Single line
commands such as skips should be either prefixed with `//` or inside a `/* */`
block.
