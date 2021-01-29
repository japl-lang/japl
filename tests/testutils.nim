# Common code from between the JAPL testing suites
# (during transition from runtests -> Just Another Test Runner

import re, strutils, terminal, osproc, strformat, times

# types

type
    TestResult* {.pure.} = enum
        Unstarted, Running, ToEval, Success, Skip, Mismatch, Crash

    Test* = ref object
        result*: TestResult
        path*: string
        expectedOutput*: string
        expectedError*: string
        output*: string
        error*: string
        process*: Process
        cycles*: int



# logging stuff

type LogLevel* {.pure.} = enum
    Debug, # always written to file only (large outputs, such as the entire output of the failing test or stacktrace)
    Info, # important information about the progress of the test suite
    Error, # failing tests (printed with red)
    Stdout, # always printed to stdout only (for cli experience)


const echoedLogs = {LogLevel.Info, LogLevel.Error, LogLevel.Stdout}
const savedLogs = {LogLevel.Debug, LogLevel.Info, LogLevel.Error}

const logColors = [LogLevel.Debug: fgDefault, LogLevel.Info: fgGreen, LogLevel.Error: fgRed, LogLevel.Stdout: fgYellow]

proc log*(level: LogLevel, file: File, msg: string) =
    let msg = &"[{$level} - {$getTime()}] {msg}"
    if level in savedLogs:
        file.writeLine(msg)
    if level in echoedLogs:
        setForegroundColor(logColors[level])
        echo msg
        setForegroundColor(fgDefault)


# parsing the test notation

proc compileExpectedOutput*(source: string): string =
    for line in source.split('\n'):
        if line =~ re"^.*//output:(.*)$":
            result &= matches[0] & "\n"

# stuff for cleaning test output

proc strip*(input: string): string =
    return input.replace(re"[\n\r]*$", "")

