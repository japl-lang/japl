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
import strformat

## A rudimentary test builder. Converts test directories to test
## sequences.

proc parseModalLine(line: string): tuple[modal: bool, mode: string, detail: string, comment: bool] =
    ## parses one line. If it's a line that's a mode (in format [modename: detail] it returns modal: true, else modal: false.
    ## mode contains the content of the line, if it's modal the mode name
    ## detail contains the content of the detail of the modename. If empty or non modal ""
    ## if comment is true, the returned value has to be ignored
    # when non modal, mode becomes the line
    # when comment is true, it must not do anything to whenever it is exported
    # initialize result
    var start = 0
    result.modal = false
    result.mode = ""
    result.detail = ""
    result.comment = false
    if line.len() > 0 and line[0] == '[':
        if line.len() > 1:
            if line[1] == '[':
                # escaped early return
                result.mode = line[1..line.high()]
                return result 
            elif line[1] == ';':
                # comment early return
                result.comment = true
                result.modal = true
                return result
        result.modal = true
        start = 1
    # not modal line early return
    elif line.len() >= 3 and line[0..2] == "//[":
        if line.len() > 3:
            result.modal = true
            start = 3
        else:
            fatal "Invalid line //[, no mode defined."
    else:
        result.mode = line
        return result

    # normal modal line:
    var colon = false # if there has been a colon already
    for i in countup(start, line.high()):
        let ch = line[i]
        if ch in Letters or ch in Digits or ch in {'_', '-'}:
            # legal characters
            if colon:
                result.detail &= ($ch).toLower()
            else:
                result.mode &= ($ch).toLower()
        elif ch == ':':
            # colon
            if not colon:
                colon = true
            else:
                fatal &"Two colons in <{line}> not allowed."
        elif ch in Whitespace:
            discard
        elif ch == ']':
            # closing can only come at the end
            if i != line.high():
                fatal &"] is only allowed to close the line <{line}>."
        elif ch == '[':
            # can only start with it
            if i > 0:
                fatal &"[ is only allowed to open the modal line <{line}>."
        else:
            fatal &"Illegal character in <{line}>: {ch}."
    # must be closed by it
    if line[line.high()] != ']':
        fatal &"Line <{line}> must be closed off by ']'."    


proc buildTest(lines: seq[string], i: var int, name: string, path: string): Test =
    ## Builds a single test (starting with index i in lines, while i is modified)
    result = newTest(name, path)
    # since this is a very simple parser, some state can reduce code length
    inc i # to discard the first "test" mode
    var mode: string
    var detail: string
    var inside: bool = false
    var body: string
    var modeline: int = -1
    while i < lines.len():
        let parsed = parseModalLine(lines[i])
        let line = parsed.mode
        if parsed.modal and not parsed.comment:
            if inside:
                if parsed.mode == "end":
                    # end inside
                    if mode == "source" and (detail == "mixed"):
                        result.parseMixed(body)
                    elif mode == "source" and (detail == "raw" or detail == ""):
                        result.parseSource(body)
                    elif mode == "stdout" or mode == "stderr":
                        let err = (mode == "stderr")
                        if detail == "":
                            result.parseStdout(body, err = err)
                        elif detail == "re":
                            result.parseStdout(body, re = true, err = err)
                        elif detail == "nw":
                            result.parseStdout(body, nw = true, err = err)
                        elif detail == "nwre":
                            result.parseStdout(body, nw = true, re = true, err = err)
                        else:
                            fatal &"Invalid mode detail {detail} for mode {mode} in test {name} at line {modeline} in {path}. Valid are re, nw and nwre."
                    elif detail != "":
                        fatal &"Invalid mode detail {detail} for mode {mode} in test {name} at line {modeline} in {path}."
                    # non-modedetail modes below:
                    elif mode == "stdin":
                        result.parseStdin(body)
                    elif mode == "python":
                        result.parsePython(body)
                    else:
                        fatal &"Invalid mode {mode} for test {name} at line {modeline} in {path}."
                    inside = false
                    mode = ""
                    detail = ""
                    body = ""
                    modeline = -1
                else:
                    fatal &"Invalid mode {parsed.mode} when inside a block (currently in mode {mode}) at line {i} in {path}."
            else: # still if modal, but not inside
                if parsed.mode == "skip":
                    result.m_skipped = true
                    if not force:
                        result.skip()
                elif parsed.mode == "end":
                    # end of test
                    return result
                else:
                    # start a new mode
                    inside = true
                    mode = parsed.mode
                    detail = parsed.detail
                    modeline = i
        elif parsed.comment:
            discard
        elif inside: # when not modal
            body &= line & "\n"
        inc i
    fatal &"Test mode unfinished (missing [end]?)."


proc buildTestFile(path: string): seq[Test] =
    ## Builds a test file consisting of multiple tests
    log(LogLevel.Debug, &"Checking {path} for tests")
    let lines = path.readFile().split('\n') 
    var i = 0
    while i < lines.len():
        let parsed = lines[i].parseModalLine()
        if parsed.modal and not parsed.comment:
            if parsed.mode == "test":
                let testname = parsed.detail
                log(LogLevel.Debug, &"Building test {testname} at {path}")
                result.add buildTest(lines, i, testname, path)
            else:
                fatal &"Invalid mode at root-level {parsed.mode} at line {i} of file {path}."
        
        # root can only contain "test" modes, anything else is just a comment (including modal and non modal comments)
        inc i


proc buildTests*(testDir: string): seq[Test] =
    ## Builds all test within the directory testDir
    ## if testDir is a file, only build that one file
    if not dirExists(testDir):
        if fileExists(testDir):
            result &= buildTestFile(testDir)
            for test in result:
                test.important = true
        else:
            fatal "test dir/file doesn't exist"

    for candidateObj in walkDir(testDir):
        let candidate = candidateObj.path
        if dirExists(candidate):
            log(LogLevel.Debug, &"Descending into dir {candidate}")
            result &= buildTests(candidate)
        else:
            try:
                result &= buildTestFile(candidate)
            except FatalError:
                discard
            except:
                write stderr, getCurrentExceptionMsg()
                write stderr, getCurrentException().getStacktrace()
                log(LogLevel.Error, &"Building test file {candidate} failed")


