
# logging stuff

import terminal, strformat, times, strutils

type LogLevel* {.pure.} = enum
    Debug, # always written to file only (large outputs, such as the entire output of the failing test or stacktrace)
    Info, # important information about the progress of the test suite
    Error, # failing tests (printed with red)
    Stdout, # always printed to stdout only (for cli experience)


const echoedLogs = {LogLevel.Info, LogLevel.Error, LogLevel.Stdout}
const echoedLogsSilent = {LogLevel.Error}
const savedLogs = {LogLevel.Debug, LogLevel.Info, LogLevel.Error}

const logColors = [LogLevel.Debug: fgDefault, LogLevel.Info: fgGreen, LogLevel.Error: fgRed, LogLevel.Stdout: fgYellow]

var totalLog = ""
var verbose = true
proc setVerbosity*(verb: bool) =
    verbose = verb

proc log*(level: LogLevel, msg: string) =
    let msg = &"[{$level} - {$getTime()}] {msg}"
    if level in savedLogs:
        totalLog &= msg & "\n"
    if (verbose and (level in echoedLogs)) or ((not verbose) and (level in echoedLogsSilent)):
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
    hideCursor()
    new(result)

proc updateProgressBar*(buf: Buffer, text: string, total: int, current: int) =
    var newline = ""
    newline &= "["
    let ratio = current / total
    let filledCount = int(ratio * progbarLength)
    if filledCount > 0:
        newline &= "=".repeat(filledCount)
    if filledCount < progbarLength:
        newline &= " ".repeat(progbarLength - filledCount - 1)
    newline &= &"] ({current}/{total}) {text}"
    # to avoid process switching during half-written progress bars and whatnot all terminal editing happens at the end
    let w = terminalWidth()
    if w > newline.len():
        newline &= " ".repeat(w - newline.len() - 1)
    buf.contents = newline

proc clearLineAndWrite(text: string, oldsize: int) =
    write stdout, text & "\r"

proc render*(buf: Buffer) =
    if verbose and buf.previous != buf.contents:
        clearLineAndWrite(buf.contents, buf.previous.len())
        buf.previous = buf.contents

proc endBuffer*(buf: Buffer) =
    showCursor()
