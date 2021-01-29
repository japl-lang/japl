# Common code from between the JAPL testing suites
# (during transition from runtests -> Just Another Test Runner

import re, strutils, terminal, osproc, strformat, times, os

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

var totalLog = ""

proc log*(level: LogLevel, msg: string) =
    let msg = &"[{$level} - {$getTime()}] {msg}"
    if level in savedLogs:
        totalLog &= msg & "\n"
    if level in echoedLogs:
        setForegroundColor(logColors[level])
        echo msg
        setForegroundColor(fgDefault)

proc getTotalLog*: string =
    totalLog

const progbarLength = 25
type Buffer* = ref object
    contents: string
    previous: string

proc newBuffer*: Buffer =
    new(result)

proc updateProgressBar*(buf: Buffer, text: string, total: int, current: int) =
    var newline = ""
    newline &= "["
    let ratio = current / total
    let filledCount = int(ratio * progbarLength)
    for i in countup(1, filledCount):
        newline &= "="
    for i in countup(filledCount + 1, progbarLength):
        newline &= " "
    newline &= &"] ({current}/{total}) {text}"
    # to avoid process switching during half-written progress bars and whatnot all terminal editing happens at the end
    buf.contents = newline

proc render*(buf: Buffer) =
    if buf.previous != buf.contents:
        echo buf.contents
        buf.previous = buf.contents

# parsing the test notation

proc compileExpectedOutput*(source: string): string =
    for line in source.split('\n'):
        if line =~ re"^.*//output:[ ]?(.*)$":
            result &= matches[0] & "\n"

proc compileExpectedError*(source: string): string =
    for line in source.split('\n'):
        if line =~ re"^.*//error:[ ]?(.*)$":
            result &= matches[0] & "\n"

# stuff for cleaning test output

proc strip*(input: string): string =
    return input.replace(re"[\n\r]*$", "")

