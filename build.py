#!/usr/bin/env python3

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

# A minimalistic build script for JAPL

import os
import stat
import shlex
import shutil
import logging
import argparse
from time import time
from typing import Dict
from subprocess import Popen, PIPE, DEVNULL, run



CONFIG_TEMPLATE = '''# Copyright 2020 Mattia Giambirtone
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

import strformat


const MAP_LOAD_FACTOR* = {map_load_factor}  # Load factor for builtin hashmaps (TODO)
const ARRAY_GROW_FACTOR* = {array_grow_factor}   # How much extra memory to allocate for dynamic arrays (TODO)
const FRAMES_MAX* = {frames_max}  # The maximum recursion limit
const JAPL_VERSION* = "0.3.0"
const JAPL_RELEASE* = "alpha"
const DEBUG_TRACE_VM* = {debug_vm} # Traces VM execution
const SKIP_STDLIB_INIT* = {skip_stdlib_init} # Skips stdlib initialization in debug mode
const DEBUG_TRACE_GC* = {debug_gc}    # Traces the garbage collector (TODO)
const DEBUG_TRACE_ALLOCATION* = {debug_alloc}   # Traces memory allocation/deallocation (WIP)
const DEBUG_TRACE_COMPILER* = {debug_compiler}  # Traces the compiler
const JAPL_VERSION_STRING* = &"JAPL {{JAPL_VERSION}} ({{JAPL_RELEASE}}, {{CompileDate}} {{CompileTime}})"
const HELP_MESSAGE* = """The JAPL runtime interface, Copyright (C) 2020 Mattia Giambirtone

This program is free software, see the license distributed with this program or check
http://www.apache.org/licenses/LICENSE-2.0 for more info.

Basic usage
-----------

$ jpl  -> Start the REPL

$ jpl filename.jpl -> Run filename.jpl


Command-line options
--------------------

-h, --help  -> Show this help text and exit
-v, --version -> Print the JAPL version number and exit
-c -> Executes the passed string
"""'''


def run_command(command: str, mode: str = "Popen", **kwargs):
    """
    Runs a command with subprocess and returns the process'
    return code, stderr and stdout
    """

    if mode == "Popen":
        process = Popen(shlex.split(command, posix=os.name != "nt"), **kwargs)
    else:
        process = run(command, **kwargs)
    if mode == "Popen":
        stdout, stderr = process.communicate()
    else:
        stdout, stderr = None, None
    return stdout, stderr, process.returncode


def build(path: str, flags: Dict[str, str] = {}, options: Dict[str, bool] = {}, override: bool = False, skip_tests: bool = False, install: bool = False,
          ignore_binary: bool = False):
    """
    Compiles the JAPL runtime, generating the appropriate
    configuration needed for compilation to succeed,
    running tests and performing installation
    when possible.
    Nim 1.2 or above is required to build JAPL

    :param path: The path to JAPL's main source directory
    :type path: string, optional
    :param flags: Any extra compiler flags that will
    be passed to nim. Keys and values should be strings,
    but any object with a proper __str__ or __repr__
    method is probably fine as long as it's a valid
    nim option for the compiler. Defaults to {} (no flags)
    :type flags: dict, optional
    :param options: Compile-time options such as debugging the
    compiler or the VM, defaults to {} (use defaults)
    :type options: dict, optional
    """


    config_path = os.path.join(path, "config.nim")
    main_path = os.path.join(path, "japl.nim")
    logging.info("Just Another Build Tool, version 0.3.3")
    listing = "\n- {} = {}"
    if not os.path.exists(path):
        logging.error(f"Input path '{path}' does not exist")
        return
    if os.path.isfile(config_path) and not override:
        logging.warning(f"A config file exists at '{config_path}', keeping it")
    else:
        logging.warning(f"Overriding config file at '{config_path}'")
        logging.debug(f"Generating config file at '{config_path}'")
        try:
            with open(config_path, "w") as build_config:
                build_config.write(CONFIG_TEMPLATE.format(**options))
        except Exception as fatal:
            logging.error(f"A fatal unhandled exception occurred -> {type(fatal).__name__}: {fatal}")
            return
        else:
            logging.debug(f"Config file has been generated, compiling with options as follows: {''.join(listing.format(k, v) for k, v in options.items())}")
    logging.debug(f"Compiling '{main_path}'")
    nim_flags = " ".join(f"-{name}:{value}" if len(name) == 1 else f"--{name}:{value}" for name, value in flags.items())
    command = "nim {flags} compile {path}".format(flags=nim_flags, path=main_path)
    logging.debug(f"Running '{command}'")
    logging.info("Compiling JAPL")
    start = time()
    _, stderr, status = run_command(command, stdout=DEVNULL, stderr=PIPE)
    if status != 0:
        logging.error(f"Command '{command}' exited with non-0 exit code {status}, output below:\n{stderr.decode()}")
    else:
        logging.debug(f"Compilation completed in {time() - start:.2f} seconds")
        logging.info("Build completed")
        if skip_tests:
            logging.warning("Skipping test suite")
        else:
            logging.info("Running tests under tests/")
            logging.debug("Compiling test suite")
            start = time()
            tests_path = "./tests/runtests" if os.name != "nt" else ".\tests\runtests"
            _, stderr, status = run_command(f"nim compile {tests_path}", stdout=DEVNULL, stderr=PIPE)
            if status != 0:
                logging.error(f"Command '{command}' exited with non-0 exit code {status}, output below:\n{stderr.decode()}")
            else:
                logging.debug(f"Test suite compilation completed in {time() - start:.2f} seconds")
                logging.debug("Running tests")
                start = time()
                # TODO: Find a better way of running the test suite
                process = run_command(f"{tests_path}", mode="run", shell=True, stderr=PIPE)
                if status != 0:
                    logging.error(f"Command '{command}' exited with non-0 exit code {status}, output below:\n{stderr.decode()}")
                else:
                    logging.debug(f"Test suite ran in {time() - start:.2f} seconds")
                    logging.info("Test suite completed!")
        if args.install:
            if os.name == "nt":
                logging.warning("Sorry, but automatically installing JAPL is not yet supported on windows")
            else:
                # TODO -> Is PATH defined on all linux distros?
                logging.info(f"Installing JAPL at PATH")
                if not ignore_binary and any(os.path.exists(os.path.join(path, "jpl")) for path in os.getenv("PATH").split(":")):
                    logging.error("Could not install JAPL because a binary already exists in PATH")
                    return
                for path in os.getenv("PATH").split(":"):
                    install_path = os.path.join(path, "jpl")
                    logging.debug(f"Attempting to install JAPL at '{install_path}'")
                    try:
                        shutil.move(main_path.strip(".nim"), install_path)
                    except PermissionError:
                        logging.debug(f"Path '{path}' is not writable, attempting next entry in PATH")
                    except Exception as fatal:
                        logging.error(f"A fatal unhandled exception occurred -> {type(fatal).__name__}: {fatal}")
                    else:
                        logging.debug(f"JAPL installed at '{path}', setting executable permissions")
                        # TODO: Use external oschmod library once we support windows!
                        try:
                            os.chmod(install_path, os.stat(install_path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
                        except Exception as fatal:
                            logging.error(f"A fatal unhandled exception occurred -> {type(fatal).__name__}: {fatal}")
                        break


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("path", help="The path to JAPL's source directory")
    parser.add_argument("--verbose", help="Prints debug information to stdout", action="store_true", default=os.getenv("JAPL_VERBOSE"))
    parser.add_argument("--flags", help="Optional flags to be passed to the nim compiler. Must be a comma-separated list of name:value (without spaces)", default=os.getenv("JAPL_FLAGS"))
    parser.add_argument("--options", help="Set compile-time options and constants, pass a comma-separated list of name:value (without spaces)."
    "Note that if a config.nim file exists in the destination directory, that will override any setting defined here unless --override-config is used", default=os.getenv("JAPL_OPTIONS"))
    parser.add_argument("--override-config", help="Overrides the setting of an already existing config.nim file in the destination directory", action="store_true", default=os.getenv("JAPL_OVERRIDE_CONFIG"))
    parser.add_argument("--skip-tests", help="Skips running the JAPL test suite, useful for debug builds", action="store_true", default=os.getenv("JAPL_SKIP_TESTS"))
    parser.add_argument("--keep-results", help="Instructs the build tool not to delete the testresults.txt file from the test suite, useful for debugging", action="store_true", default=os.getenv("JAPL_KEEP_RESULTS"))
    parser.add_argument("--install", help="Tries to move the compiled binary to PATH (this is always disabled on windows)", action="store_true", default=os.environ.get("JAPL_INSTALL"))
    parser.add_argument("--ignore-binary", help="Ignores an already existing 'jpl' binary in any installation directory and overwrites it, use (with care!) with --install", action="store_true", default=os.getenv("JAPL_IGNORE_BINARY"))
    args = parser.parse_args()
    flags = {
            "gc": "markAndSweep",  # Because refc is broken ¯\_(ツ)_/¯
            }
    options = {
        "debug_vm": "false",
        "skip_stdlib_init": "false",
        "debug_gc": "false",
        "debug_compiler": "false",
        "debug_alloc": "false",
        "map_load_factor": "0.75",
        "array_grow_factor": "2",
        "frames_max": "800",
    }
    # We support environment variables!
    for key, value in options.items():
        if var := os.getenv(f"JAPL_{key.upper()}"):
            options[key] = var
    logging.basicConfig(format="[%(levelname)s - %(asctime)s] %(message)s",
                        datefmt="%T",
                        level=logging.DEBUG if args.verbose else logging.INFO
                        )
    if args.flags:
        try:
            for value in args.flags.split(","):
                k, v = value.split(":", maxsplit=2)
                flags[k] = v
        except Exception:
            logging.error("Invalid parameter for --flags")
            exit()
    if args.options:
        try:
            for value in args.options.split(","):
                k, v = value.split(":", maxsplit=2)
                if k not in options:
                    logging.error("Invalid compile-time option '{key}'")
                    exit()
                options[k] = v
        except Exception:
            logging.error("Invalid parameter for --options")
            exit()
    build(args.path, flags, options, args.override_config, args.skip_tests, args.install, args.ignore_binary)
    if not args.keep_results and not args.skip_tests:
        if os.path.isfile("testresults.txt"):
            try:
                os.remove("testresults.txt")
            except Exception as error:
                logging.warning(f"Could not remove test results file due to a {type(error).__name__}: {error}")
    logging.debug("Build tool exited")
