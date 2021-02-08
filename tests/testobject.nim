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

# Test object and helpers

import testconfig

import re
import strutils
import osproc
import streams
import strutils

# types

type
    TestResult* {.pure.} = enum
        Unstarted, Running, ToEval, Success, Skip, Mismatch, Crash, Killed

    ExpectedLineKind* {.pure.} = enum
        Raw, Regex

    ExpectedLine* = object
        kind*: ExpectedLineKind
        content*: string        

    Test* = ref object
        # test origins
        source*: string
        path*: string
        name*: string
        # generated after building
        expectedOutput*: seq[ExpectedLine]
        expectedError*: seq[ExpectedLine]
        input*: string
        # during running/output of running
        output*: string
        error*: string
        process*: Process
        cycles*: int
        # after evaluation
        result*: TestResult
        mismatchPos*: int # only for result mismatch
        errorMismatchPos*: int # same but for stderr

# Helpers for building tests:

proc genEL(content: string, kind: ExpectedLineKind): ExpectedLine =
    ExpectedLine(kind: kind, content: content)

proc compileExpectedOutput(source: string, rawkw: string, rekw: string): seq[ExpectedLine] =
    for line in source.split('\n'):
        if line =~ re("^.*//" & rawkw & ":[ ]?(.*)$"):
            result &= genEL(matches[0], ExpectedLineKind.Raw)
        elif line =~ re("^.*//" & rekw & ":[ ]?(.*)$"):
            result &= genEL(matches[0], ExpectedLineKind.Regex)

proc compileExpectedOutput(source: string): seq[ExpectedLine] =
    compileExpectedOutput(source, "stdout", "stdoutre")

proc compileExpectedError(source: string): seq[ExpectedLine] =
  compileExpectedOutput(source, "stderr", "stderrre")

proc compileInput(source: string): string =
    for line in source.split('\n'):
        if line =~ re"^.*//stdin:[ ]?(.*)$":
            result &= matches[0] & "\n"

proc parseMixed*(test: Test, source: string) =
    test.source &= source
    test.expectedOutput = compileExpectedOutput(source)
    test.expectedError = compileExpectedError(source)
    test.input = compileInput(source)

proc parseSource*(test: Test, source: string) =
    test.source &= source

proc parseStdin*(test: Test, source: string) =
    test.input &= source

proc parseStdout*(test: Test, source: string, regex: bool = false, stderr: bool = false) =
    var kind = ExpectedLineKind.Raw
    if regex:
        kind = ExpectedLineKind.Regex
    for line in source.split('\n'):
        if stderr:
            test.expectedError.add(genEL(line, kind))
        else:
            test.expectedOutput.add(genEL(line, kind))

    if stderr:
        while test.expectedError.len() > 0 and test.expectedError[test.expectedError.high()].content == "":
            discard test.expectedError.pop()
    else:
        while test.expectedOutput.len() > 0 and test.expectedOutput[test.expectedOutput.high()].content == "":
            discard test.expectedOutput.pop()

proc parseStderr*(test: Test, source: string, regex: bool = false) =
    parseStdout(test, source, regex, true)

proc parsePython*(test: Test, source: string) =
    discard # TODO

proc newTest*(name: string, path: string): Test =
    new(result)
    result.result = TestResult.Unstarted
    result.path = path
    result.name = name
    result.mismatchPos = -1
    result.errorMismatchPos = -1

proc skip*(test: Test) =
    test.result = TestResult.Skip

# Expected line displayer
proc `$`*(el: ExpectedLine): string =
    case el.kind:
        of ExpectedLineKind.Raw:
            result &= "raw \""
        of ExpectedLineKind.Regex:
            result &= "regex \""
    result &= el.content & "\""

proc `$`*(els: seq[ExpectedLine]): string =
    for el in els:
        result &= $el & "\n"

# Helpers for running tests

proc start*(test: Test) =
    test.process = startProcess(testRunner, options = {})
    test.process.inputStream.write(test.source & $char(4) & test.input)
    test.process.inputStream.close() # this is advised against in the stdlib, but this is what gets the job
                             # done. (Yes I tried flushing)
    test.result = TestResult.Running

proc finish*(test: Test) =
    # only call when the process has ended execution gracefully. Don't call after closing.
    # Don't call while it's running.
    test.output = test.process.outputStream.readAll()
    test.error = test.process.errorStream.readAll()
    if test.process.peekExitCode() == 0:
        test.result = TestResult.ToEval # also means "finished running" with a zero exit code
    else:
        test.result = TestResult.Crash # also means "finished running" with a non-zero exit code
    test.process.close()

proc kill*(test: Test) =
    # alternative to finish
    test.process.kill()
    discard test.process.waitForExit()
    test.result = TestResult.Killed

proc running*(test: Test): bool =
    test.result == TestResult.Running and test.process.running()

# Helpers for evaluating tests

proc stdStrip(input: string): seq[string] =
    var lines = input.split('\n')
    var toRemove: seq[int]
    for i in countup(0, lines.high()):
        template line: string = lines[i]
        let hadContent = line.len() > 0
        for op in countup(0, outputStripReplaces.high()):
            line = line.replace(re(outputStripReplaces[op]), outputStripReplaceTargets[op])
        if hadContent and line.len() == 0:
            toRemove.add(i)
    
    for i in toRemove:
        lines.delete(i)

    while lines.len() > 0 and lines[lines.high()] == "":
        discard lines.pop()
    lines

proc eval*(test: Test): bool =
    let
        outputLines = test.output.stdStrip()
        errorLines = test.error.stdStrip()

    if test.expectedOutput.len() != outputLines.len():
        test.mismatchPos = outputLines.len()
        return false
    if test.expectedError.len() != errorLines.len():
        test.errorMismatchPos = errorLines.len()
        return false

    for i in countup(0, test.expectedOutput.high()):
        let line = test.expectedOutput[i]
        case line.kind:
            of ExpectedLineKind.Raw:
                if line.content.strip() != outputLines[i].strip():
                    test.mismatchPos = i
                    return false
            of ExpectedLineKind.Regex:
                if not outputLines[i].strip().match(re(line.content.strip())):
                    test.mismatchPos = i
                    return false
    for i in countup(0, test.expectedError.high()):
        let line = test.expectedError[i]
        case line.kind:
            of ExpectedLineKind.Raw:
                if line.content.strip() != errorLines[i].strip():
                    test.errorMismatchPos = i
                    return false
            of ExpectedLineKind.Regex:
                if not errorLines[i].strip().match(re(line.content.strip())):
                    test.errorMismatchPos = i
                    return false

    return true
