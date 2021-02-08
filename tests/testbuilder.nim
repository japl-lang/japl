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

import testobject
import logutils
import testconfig

import os
import strutils
import sequtils
import strformat

proc parseModalLine(line: string): tuple[modal: bool, mode: string, detail: string] =
    let line = line.strip()
    result.modal = false
    result.mode = ""
    result.detail = ""
    if line.len() > 0 and line[0] == '[':
        result.modal = true
    else:
        return result
    
    var colon = false

    for i in countup(0, line.high()):
        let ch = line[i]
        if ch in Letters:
            if colon:
                result.detail &= ($ch).toLower()
            else:
                result.mode &= ($ch).toLower()
        elif ch == ':':
            if not colon:
                colon = true
            else:
                fatal &"Two colons in <{line}> not allowed."
        elif ch in Whitespace:
            discard
        elif ch == ']':
            if i != line.high():
                fatal &"] is only allowed to close the line <{line}>."
        elif ch == '[':
            if i > 0:
                fatal &"[ is only allowed to open the modal line <{line}>."
        else:
            fatal &"Illegal character in <{line}>: {ch}."
    if line[line.high()] != ']':
        fatal &"Line <{line}> must be closed off by ']'."    

proc buildTest(lines: seq[string], i: var int, name: string, path: string): Test =
    result = newTest(name, path)
    # since this is a very simple parser, some state can reduce code length
    var mode: string
    var detail: string
    var inside: bool
    var body: string
    while i < lines.len():
        let line = lines[i].strip()
        let parsed = parseModalLine(line)
        let modal = parsed.modal
        if parsed.modal:
            if inside:
                if mode == "end":
                    # end inside
                    if mode == "source" and (detail == "" or detail == "mixed"):
                        result.parseMixed(body)
                    elif mode == "source" and detail == "raw":
                        result.parseSource(body)
                    elif mode == "stdout" and (detail == ""):
                        result.parseStdout(body)
                    elif mode == "stdoutre" or (mode == "stdout" and detail == "re"):
                        result.parseStdout(body, true)
                    elif mode == "stderr" and (detail == ""):
                        result.parseStderr(body)
                    elif mode == "stderrre" or (mode == "stderr" and detail == "re"):
                        result.parseStderr(body, true)
                    elif detail != "":
                        fatal &"Invalid mode detail {detail} for mode {mode} in test {name} at {path}."
                    # non-modedetail modes below:
                    elif mode == "stdin":
                        result.parseStdin(body)
                    elif mode == "python":
                        result.parsePython(body)
                    elif mode == "comment":
                        discard # just a comment
                    else:
                        fatal &"Invalid mode {mode} for test {name} at {path}."
                    inside = false
                    mode = ""
                    detail = ""
                    body = ""
                else:
                    discard # it's inside, so let's pretend it's not modal and let it get added to the body
            else:
                if mode == "skip":
                    result.skip()
                else:
                    # start a new mode
                    inside = true
                    mode = parsed.mode
                    detail = parsed.detail
        elif inside:
            body &= line & "\n"
        else:
            # invalid
            fatal &"Invalid code inside a test: {line} in test {name} at {path}"
        inc i

proc buildTestFile(path: string): seq[Test] =
    log(LogLevel.Debug, &"Checking {path} for tests")
    let lines = path.readFile().split('\n') 
    var i = 0
    while i < lines.len():
        let line = lines[i].strip()
        let parsed = line.parseModalLine()
        if parsed.modal:
            if parsed.mode == "test":
                let testname = parsed.detail
                log(LogLevel.Debug, &"Building test {testname} at {path}")
                result.add buildTest(lines, i, testname, path)
            else:
                fatal &"Invalid mode at root-level {parsed.mode} at line {i} of file {path}."
        # root can only contain "test" modes, anything else is just a comment
        inc i
        
proc buildTests*(testDir: string): seq[Test] =
    for candidateObj in walkDir(testDir):
        let candidate = candidateObj.path
        if dirExists(candidate):
            log(LogLevel.Debug, &"Descending into dir {candidate}")
            result &= buildTests(candidate)
        else:
            try:
                result &= buildTestFile(candidate)
            except:
                write stderr, getCurrentExceptionMsg()
                write stderr, getCurrentException().getStacktrace()
                log(LogLevel.Error, &"Building test file {candidate} failed")


