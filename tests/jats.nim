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

## Just Another Test Suite for running JAPL tests

import nim/nimtests
import testobject
import logutils
import testconfig
import testbuilder
import testrun
import testeval
import localization

import os
import strformat
import parseopt
import strutils
import terminal
import re

type 
    Action {.pure.} = enum
        Run, Help, Version
    ## The action JATS takes.

    DebugAction {.pure.} = enum
        Interactive, Stdout
    ## The action JATS takes with the Debug Log output.

    QuitValue {.pure.} = enum
        Success, Failure, ArgParseErr, Unreachable, Interrupt, JatrNotFound,
        UncaughtException
    ## The enum that specifies what each exit code means

when isMainModule:
    # command line option parser
    var optparser = initOptParser(commandLineParams())

    # variables that define what JATS does
    var action: Action = Action.Run
    var debugActions: seq[DebugAction]
    var targetFiles: seq[string]
    var verbose = true
    var quitVal = QuitValue.Success
    var testDir = "japl"

    proc evalKey(key: string) =
        ## Modifies the globals that define what JATS does based on the 
        ## provided key/flag
        let key = key.toLower()
        if key == "h" or key == "help":
            action = Action.Help
        elif key == "v" or key == "version":
            action = Action.Version
        elif key == "i" or key == "interactive":
            debugActions.add(DebugAction.Interactive)
        elif key == "s" or key == "silent":
            verbose = false
        elif key == "stdout":
            debugActions.add(DebugAction.Stdout)
        elif key == "f" or key == "force":
            force = true
        elif key == "e" or key == "enumerate":
            enumerate = true
        else:
            echo &"Unknown flag: {key}"
            action = Action.Help
            quitVal = QuitValue.ArgParseErr


    proc evalKeyVal(key: string, val: string) =
        ## Modifies the globals that specify what JATS does based on
        ## the provided key/value pair
        let key = key.toLower()
        if key == "o" or key == "output":
            targetFiles.add(val)
        elif key == "j" or key == "jobs":
            if val.match(re"^[0-9]*$"):
                maxAliveTests = parseInt(val)
            else:
                echo "Can't parse non-integer option passed to -j/--jobs."
                action = Action.Help
                quitVal = QuitValue.ArgParseErr
        elif key == "t" or key == "test" or key == "tests":
            testDir = val
        elif key == "timeout":
            try:
                var timeoutSeconds = parseFloat(val)
                # a round is 100 ms, so let's not get close to that
                if timeoutSeconds < 0.3:
                    timeoutSeconds = 0.3
                # I don't want anything not nicely convertible to int, 
                # so how about cut it off at 10 hours. Open an issue
                # if that's not enough... or just tweak it you lunatic
                if timeoutSeconds > 36000.0:
                    timeoutSeconds = 36000.0
                timeout = (timeoutSeconds * 10).int
            except ValueError:
                echo "Can't parse invalid timeout value " & val
                action = Action.Help
                quitVal = QuitValue.ArgParseErr
        else:
            echo &"Unknown option: {key}"
            action = Action.Help
            quitVal = QuitValue.ArgParseErr


    proc evalArg(key: string) =
        ## Modifies what JATS does based on a provided argument
        echo &"Unexpected argument"
        action = Action.Help
        quitVal = QuitValue.ArgParseErr

    # parse arguments
    while true:
        optparser.next()
        case optparser.kind:
            of cmdEnd: break
            of cmdShortOption, cmdLongOption:
                if optparser.val == "":
                    evalKey(optparser.key)
                else:
                    evalKeyVal(optparser.key, optparser.val)
            of cmdArgument:
                evalArg(optparser.key)


    proc printUsage =
        ## Prints JATS usage/help information to the terminal
        echo """
JATS - Just Another Test Suite

Usage: ./jats <flags>
Debug output flags:
-i (or --interactive) displays all debug info
-o:<filename> (or --output:<filename>) saves debug info to a file
-s (or --silent) will disable all output (except --stdout)
--stdout will put all debug info to stdout
-e (or --enumerate) will list all tests that fail, crash or get killed
Test behavior flags:
-j:<parallel test count> (or --jobs:<parallel test count>) to specify number of tests to run parallel
-t:<test file or dir> (or --test:<path> or --tests:<path>) to specify where tests are
--timeout <timeout in seconds> to specify when to kill tests
-f (or --force) will run skipped tests
Miscellaneous flags:
-h (or --help) displays this help message
-v (or --version) displays the version number of JATS
"""

    proc printVersion =
        ## Prints JATS version information to the terminal
        echo &"JATS - Just Another Test Suite version {jatsVersion}"

    # execute the action defined. Run is executed below, so not quitting
    # runs it.
    if action == Action.Help:
        printUsage()
        quit int(quitVal)
    elif action == Action.Version:
        printVersion()
        quit int(quitVal)
    elif action == Action.Run:
        discard
    else:
        echo &"Unknown action {action}, please contact the devs to fix this."
        quit int(QuitValue.Unreachable)


    # action Run

    # define globals in logutils
    setVerbosity(verbose)
    setLogfiles(targetFiles)

    # run the test suite
    try:
        log(LogLevel.Debug, &"Welcome to JATS")

        # the first half of the test suite defined in ~japl/tests/nim
        runNimTests()

        # the second half of the test suite defined in ~japl/tests/japl
        # Find ~japl/tests/japl and the test runner JATR
        var jatr = "jatr"
        if not fileExists(jatr):
            if fileExists("tests" / jatr):
                log(LogLevel.Debug, 
                    &"Must be in root: prepending \"tests\" to jatr path")
                jatr = "tests" / jatr
            else:
                # only those two dirs are realistically useful for now,
                echo "The test runner was not found."
                quit int(QuitValue.JatrNotFound)

        if not dirExists(testDir) and not fileExists(testDir):
          if dirExists("tests" / testDir) or fileExists("tests" / testDir):
            log(LogLevel.Debug, "Prepending \"tests\" to test path")
            testDir = "tests" / testDir
          else:
            echo "The test dir/file was not found."
            quit int(QuitValue.JatrNotFound)

        # set the global var which specifies the path to the test runner
        testRunner = jatr
        log(LogLevel.Info, &"Running JAPL tests.")
        log(LogLevel.Info, &"Building tests...")
        # build tests (see testbuilder.nim)
        let tests: seq[Test] = buildTests(testDir)
        log(LogLevel.Debug, &"Tests built.")
        # define interrupt (only here, because it's a closure over tests, so
        # they can be killed)
        proc ctrlc() {.noconv.} =
            showCursor()
            tests.killTests()
            echo "Interrupted by ^C."
            quit(int(QuitValue.Interrupt))
        setControlCHook(ctrlc)
        log(LogLevel.Info, &"Running tests...")
        # run tests (see testrun.nim)
        tests.runTests()
        log(LogLevel.Debug, &"Tests ran.")
        log(LogLevel.Debug, &"Evaluating tests...")
        # evaluate tests (see testeval.nim)
        tests.evalTests()
        log(LogLevel.Debug, &"Tests evaluated.")
        # print test results (see testeval.nim)
        if not tests.printResults():
            quitVal = QuitValue.Failure
        log(LogLevel.Debug, &"Quitting JATS.")
        # special options to view the entire debug log
    except FatalError:
        # a fatal raised by some code
        writeLine stderr, getCurrentExceptionMsg()
        quit(int(QuitValue.UncaughtException))
    except:
        # write the current exception message
        writeLine stdout, getCurrentExceptionMessage()
        writeLine stdout, getCurrentException().getStackTrace()
        quit(int(QuitValue.UncaughtException))
        
    finally:
        # Always show logs, even if there's a crash
        let logs = getTotalLog()
        for action in debugActions:
            case action:
                of DebugAction.Interactive:
                    # try to find 'more' and 'less' as pagers
                    let lessExe = findExe("less", extensions = @[""])
                    let moreExe = findExe("more", extensions = @[""])
                    # prioritize 'less' if found, otherwise go for more
                    # or if both are "" = not found, then inform the lack
                    # of a recognized terminal pager
                    var viewer = if lessExe == "": moreExe else: lessExe
                    if viewer != "":
                        # more reliable than pipes
                        writeFile("testresults.txt", logs) # yes, testresults.txt is reserved
                        discard execShellCmd(viewer & " testresults.txt") # this way because of pipe buffer sizes
                        removeFile("testresults.txt")
                    else:
                        write stderr, "Interactive mode not supported on your platform, try --stdout and piping, or install/alias 'more' or 'less' to a terminal pager.\n"
                of DebugAction.Stdout:
                    echo logs
    quit int(quitVal)

