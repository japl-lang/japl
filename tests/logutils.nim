# Copyright 2020 Mattia Giambirtone
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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
var logfiles: seq[string]
proc setVerbosity*(verb: bool) =
    verbose = verb

proc log*(level: LogLevel, msg: string) =
    let msg = &"[{$level} - {$getTime()}] {msg}"
    if level in savedLogs:
        totalLog &= msg & "\n"
        if logfiles.len() > 0:
            for file in logfiles:
                let handle = file.open(fmAppend)
                handle.writeLine(msg)
                handle.close()
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
    if verbose: #and buf.previous != buf.contents:
        clearLineAndWrite(buf.contents, buf.previous.len())
        buf.previous = buf.contents

proc endBuffer*(buf: Buffer) =
    showCursor()

proc setLogfiles*(files: seq[string]) =
    logfiles = files
