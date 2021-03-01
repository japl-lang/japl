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

## A quick library for writing debug logs, errors, fatals and progress bars
## for the test suite.
##
## Global variables:
##
## totalLog (can be written to with the proc log)
## verbose (can be set with the proc setVerbosity)
## logfiles (can be set with the proc setLogfiles)
##
## The rationale behind all three is that they have one value accross
## one jats process/instance, and they would bloat up every single proc
## signature, because they are needed for the proc log to work.

import terminal
import strformat
import times
import strutils


type LogLevel* {.pure.} = enum
    ## All the different possible log levels
    Debug, # always written to file only (large outputs, such as the entire output of the failing test or stacktrace)
    Info, # important information about the progress of the test suite
    Enumeration, # a white output for the enumerate option
    Error, # failing tests (printed with yellow)
    Fatal # always printed with red, halts the entire suite (test parsing errors, printed with red)

# log config: which log levels to show, show in silent mode and save to the
# detailed debug logs
const echoedLogs = {LogLevel.Info, LogLevel.Error, LogLevel.Fatal, 
                    LogLevel.Enumeration}
const echoedLogsSilent = {LogLevel.Fatal, LogLevel.Enumeration} # will be echoed even if test suite is silent
const savedLogs = {LogLevel.Debug, LogLevel.Info, LogLevel.Error, 
                   LogLevel.Fatal, LogLevel.Enumeration}

# aesthetic config:
# progress bar length
const progbarLength = 25
# log level colors
const logColors = [LogLevel.Debug: fgDefault, LogLevel.Info: fgGreen, 
                   LogLevel.Enumeration: fgDefault,
                   LogLevel.Error: fgYellow, LogLevel.Fatal: fgRed]

# global vars for the proc log
var totalLog = ""
var verbose = true
var logfiles: seq[string]

# simple interfaces with the globals
proc setVerbosity*(verb: bool) =
    ## Sets the logging verbosity
    verbose = verb

proc getTotalLog*: string =
    ## Returns all the detailed logs in ever logged in the jats instance
    totalLog

proc setLogfiles*(files: seq[string]) =
    ## Sets files to write logs to
    logfiles = files

# main logging command
proc log*(level: LogLevel, msg: string) =
    ## Adds a line to the total logs/stdout depending on config, together
    ## with the timestamp
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


type FatalError* = ref object of CatchableError

proc fatal*(msg: string) =
    ## Creates a fatal error, logs it and raises it as an exception
    log(LogLevel.Fatal, msg)
    let e = new(FatalError)
    e.msg = msg
    raise e


# progress bar stuff

type Buffer* = ref object
    ## Represents an updateable line on the terminal
    contents: string
    previous: string
    termwidth: int

proc newBuffer*: Buffer =
    ## Creates a Buffer, hides the cursor
    hideCursor()
    new(result)

proc updateProgressBar*(buf: Buffer, text: string, total: int, current: int) =
    ## Fills a buffer with a progress bar with label (text) total cells (total)
    ## and filled cells (current)
    if total <= 0:
        return
    var newline = ""
    newline &= "["
    let ratio = current / total
    let filledCount = int(ratio * progbarLength)
    if filledCount > 0:
        newline &= "=".repeat(filledCount)
    if progbarLength - filledCount - 1 > 0:
        newline &= " ".repeat(progbarLength - filledCount - 1)
    newline &= &"] ({current}/{total}) {text}"
    # to avoid process switching during half-written progress bars and whatnot all terminal editing happens at the end
    let w = terminalWidth()
    if w > newline.len():
        newline &= " ".repeat(w - newline.len() - 1)
    else:
        newline = newline[0..w-2]
    buf.contents = newline

proc clearLineAndWrite(text: string, oldsize: int) =
    ## writes text to the beginning of the line 
    # oldsize is there for history, and so that the implementation
    # of line clearing is flexible
    write stdout, "\r" & text & "\r"

proc render*(buf: Buffer) =
    if verbose: #and buf.previous != buf.contents:
        clearLineAndWrite(buf.contents, buf.previous.len())
        buf.previous = buf.contents

proc endBuffer*(buf: Buffer) =
    ## Ends the existence of a buffer
    ## restores terminal status for good scrolling experience
    showCursor()

