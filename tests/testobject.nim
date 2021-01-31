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

# Helpers for building tests:

proc genEL(content: string, kind: ExpectedLineKind): ExpectedLine =
    ExpectedLine(kind: kind, content: content)

proc compileExpectedOutput(source: string, rawkw: string, rekw: string): seq[ExpectedLine] =
    for line in source.split('\n'):
        if line =~ re("^.*//" & rawkw & ":[ ]?(.*)$"):
            result &= genEL(matches[0], ExpectedLineKind.Raw)
        elif line =~ re("^.*//" & rekw & ":[ ]?(.*$"):
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
    test.result = TestResult.Unstarted

proc parseSource*(test: Test, source: string) =
    test.source &= source

proc parseStdin*(test: Test, source: string) =
    test.input &= source

proc parseStdout*(test: Test, source: string, regex: bool = false, stderr: bool = false) =
    var kind: ExpectedLineKind.Raw
    if regex:
        kind = ExpectedLineKind.Regex
    for line in source.split('\n'):
        if stderr:
            test.expectedError.add(genEL(line, kind))
        else:
            test.expectedOutput.add(genEL(line, kind))

proc parseStderr*(test: Test, source: string, regex: bool = false) =
    parseStdout(test, source, regex, true)

proc parsePython*(test: Test, source: string) =
    discard # TODO

proc newTest*(name: string, path: string): Test =
    result.path = path
    result.name = name

proc skip*(test: Test) =
    test.result = TestResult.Skip

# Helpers for running tests

proc start*(test: Test) =
    test.process = startProcess(testRunner, options = {})
    test.inputStream.write(test.source & $char(4) & test.input)
    test.inputStream.close() # this is advised against in the stdlib, but this is what gets the job
                             # done. (Yes I tried flushing)
    test.result = TestResult.Running

proc finish*(test: Test) =
    # only call when the process has ended execution gracefully. Don't call after closing.
    # Don't call while it's running.
    test.output = test.outputStream.readAll()
    test.error = test.errorStream.readAll()
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

proc toStrip(input: string): string =
    var text = input
    for i in countup(0, outputStripReplaces.high()):
        text = text.replace(outputStripReplaces[i], outputStripReplaceTargets[i])


proc eval*(test: Test): bool =
    
    test.output = test.output.toStrip()
    test.error = test.error.toStrip()

    for line in test.expectedOutput:
        case line.kind:
            of ExpectedLineKind.Raw:
                # TODO HERE
                




