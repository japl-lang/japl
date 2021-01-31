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

# Test object helpers

import testobject
import logutils

import os
import osproc
import streams
import strformat
import testconfig

proc evalTest(test: Test) =
    test.output = test.output.tuStrip()
    test.error = test.error.tuStrip()
    test.expectedOutput = test.expectedOutput.tuStrip()
    test.expectedError = test.expectedError.tuStrip()
    if test.output != test.expectedOutput or test.error != test.expectedError:
        test.result = TestResult.Mismatch
    else:
        test.result = TestResult.Success


proc evalTests*(tests: seq[Test]) =
    for test in tests:
        if test.result == TestResult.ToEval:
            evalTest(test)


proc printResults*(tests: seq[Test]): bool =
    var
        skipped = 0
        success = 0
        fail = 0
        crash = 0
    for test in tests:
        log(LogLevel.Debug, &"Test {test.path} result: {test.result}")
        case test.result:
            of TestResult.Skip:
                inc skipped
            of TestResult.Mismatch:
                inc fail
                log(LogLevel.Debug, &"[{test.path}\noutput:\n{test.output}\nerror:\n{test.error}\nexpected output:\n{test.expectedOutput}\nexpectedError:\n{test.expectedError}\n]")
            of TestResult.Crash:
                inc crash
                log(LogLevel.Debug, &"{test.path} \ncrash:\n{test.output}")
            of TestResult.Success:
                inc success
            else:
                log(LogLevel.Error, &"Probably a testing suite bug: test {test.path} has result {test.result}")
    let finalLevel = if fail == 0 and crash == 0: LogLevel.Info else: LogLevel.Error
    log(finalLevel, &"{tests.len()} tests: {success} succeeded, {skipped} skipped, {fail} failed, {crash} crashed.")
    result = fail == 0 and crash == 0


