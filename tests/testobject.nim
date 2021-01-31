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

import re, strutils, osproc

# types

type
    TestResult* {.pure.} = enum
        Unstarted, Running, ToEval, Success, Skip, Mismatch, Crash

    Test* = ref object
        result*: TestResult
        path*: string
        expectedOutput*: string
        expectedError*: string
        input*: string
        output*: string
        error*: string
        process*: Process
        cycles*: int

# parsing the test notation

proc compileExpectedOutput*(source: string): string =
    for line in source.split('\n'):
        if line =~ re"^.*//stdout:[ ]?(.*)$":
            result &= matches[0] & "\n"


proc compileExpectedError*(source: string): string =
    for line in source.split('\n'):
        if line =~ re"^.*//stderr:[ ]?(.*)$":
            result &= matches[0] & "\n"

proc compileInput*(source: string): string =
    for line in source.split('\n'):
        if line =~ re"^.*//stdin:[ ]?(.*)$":
            result &= matches[0] & "\n"


# stuff for cleaning test output

proc tuStrip*(input: string): string =
    return input.replace(re"\[DEBUG.*\n","\n").replace(re"[\n\r]*", "\n").replace(re"\n$","")

