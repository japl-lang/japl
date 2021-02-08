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
import re

proc buildTest(lines: seq[string], i: var int, name: string, path: string): Test =
    result = newTest(name, path)
    # since this is a very simple parser, some state can reduce code length
    var mode: string
    var modedetail: string
    var inside: bool
    var body: string
    while i < lines.len():
        let line = lines[i]
        if line =~ re"^[ \t]*\[[ \t]*(.*)[ \t]*\][ \t]*$":
            let content = matches[0]
            var parts: seq[string]
            for part in content.split(':'):
                parts.add(part.strip())
            if inside:
                if parts[0] == "end":
                    # end inside
                    if mode == "source" and (modedetail == "" or modedetail == "mixed"):
                        result.parseMixed(body)
                    elif mode == "source" and modedetail == "raw":
                        result.parseSource(body)
                    elif mode == "stdout" and (modedetail == ""):
                        result.parseStdout(body)
                    elif mode == "stdoutre" or (mode == "stdout" and modedetail == "re"):
                        result.parseStdout(body, true)
                    elif mode == "stderr" and (modedetail == ""):
                        result.parseStderr(body)
                    elif mode == "stderrre" or (mode == "stderr" and modedetail == "re"):
                        result.parseStderr(body, true)
                    elif modedetail != "":
                        fatal &"Invalid mode detail {modedetail} for mode {mode} in test {name} at {path}."
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
                    modedetail = ""
                    body = ""
            else:
                if parts[0] == "skip":
                    result.skip()
                else:
                    inside = true
                    mode = parts[0]
                    if parts.len() > 1:
                        modedetail = parts[1]
                    else:
                        modedetail = ""
        elif line =~ re"^[ \t]*$":
            discard # nothing interesting
        elif inside:
            body &= line & "\n"
        else:
            # invalid
            fatal &"Invalid test code: {line} in test {name} at {path}"

proc buildTestFile(path: string): seq[Test] =
    log(LogLevel.Debug, &"Building test {path}")
    let lines = path.split('\n') 
    var i = 0
    while i < lines.len():
        let line = lines[i]
        if line =~ re"\[Test:[ \t]*(.*)[ \t*]\]":
            let testname = matches[0]
            result.add buildTest(lines, i, testname, path)
        inc i
        
proc buildTests*(testDir: string): seq[Test] =
    for candidateObj in walkDir(testDir):
        let candidate = candidateObj.path
        if dirExists(candidate):
            log(LogLevel.Debug, &"Descending into dir {candidate}")
            result &= buildTests(candidate)
        else:
            result &= buildTestFile(candidate)


