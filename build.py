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
import json
import shlex
import shutil
import logging
import argparse
from time import time
from typing import Dict, Optional
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


const MAP_LOAD_FACTOR* = {map_load_factor}  # Load factor for builtin hashmaps
const ARRAY_GROW_FACTOR* = {array_grow_factor}   # How much extra memory to allocate for dynamic arrays when resizing
const FRAMES_MAX* = {frames_max}  # The maximum recursion limit
const JAPL_VERSION* = "0.3.0"
const JAPL_RELEASE* = "alpha"
const DEBUG_TRACE_VM* = {debug_vm} # Traces VM execution
const SKIP_STDLIB_INIT* = {skip_stdlib_init} # Skips stdlib initialization in debug mode
const DEBUG_TRACE_GC* = {debug_gc}    # Traces the garbage collector (TODO)
const DEBUG_TRACE_ALLOCATION* = {debug_alloc}   # Traces memory allocation/deallocation
const DEBUG_TRACE_COMPILER* = {debug_compiler}  # Traces the compiler
const JAPL_VERSION_STRING* = &"JAPL {{JAPL_VERSION}} ({{JAPL_RELEASE}}, {{CompileDate}} {{CompileTime}})"
const HELP_MESSAGE* = """The JAPL runtime interface, Copyright (C) 2020 Mattia Giambirtone

This program is free software, see the license distributed with this program or check
http://www.apache.org/licenses/LICENSE-2.0 for more info.

Basic usage
-----------

$ jpl  -> Starts the REPL

$ jpl filename.jpl -> Runs filename.jpl


Command-line options
--------------------

-h, --help  -> Shows this help text and exit
-v, --version -> Prints the JAPL version number and exit
-s, --string -> Executes the passed string as if it was a file
-i, --interactive -> Enables interactive mode, which opens a REPL session after execution of a file or source string
"""'''


def run_command(command: str, mode: str = "Popen", **kwargs):
    """
    Runs a command with subprocess and returns the process'
    return code, stderr and stdout
    """

    logging.debug(f"Running '{command}'")
    if mode == "Popen":
        process = Popen(shlex.split(command, posix=os.name != "nt"), **kwargs)
        stdout, stderr = process.communicate()
    else:
        process = run(command, **kwargs)
        stdout, stderr = None, None
    return stdout, stderr, process.returncode


def build(path: str, flags: Optional[Dict[str, str]] = {}, options: Optional[Dict[str, bool]] = {},
          override: Optional[bool] = False, skip_tests: Optional[bool] = False,
          install: Optional[bool] = False, ignore_binary: Optional[bool] = False,
          verbose: Optional[bool] = False):
    """
    Builds the JAPL runtime.

    This function generates the required configuration
    according to the user's choice, runs tests and 
    performs installation when possible.

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
    :param override: Wether to ignore an already existing
    config.nim file from a previous build or not. Setting this
    to True will overwrite the configuration file and is useful
    for when build options have to be tweaked, while setting it
    to False will not touch the file at all. Defaults to False
    :type override: bool, optional
    :param skip_tests: Wether to skip running JATS (just another
    test suite) or not, defaults to False
    :type skip_tests: bool, optional
    :param install: Wether to try to install JAPL in PATH so that
    it can be invoked with "jpl" as a command instead of running it
    via the binary directly, defaults to False
    :type install: bool, optional
    :param ignore_binary: Wether to ignore (and overwrite) a previous
    JAPL entry in PATH. The build script will complain if there is a file
    or folder already named "jpl" in ANY entry in PATH so this option allows
    to overwrite whatever data is there. Note that JAPL right now isn't aware
    of what it is replacing so make sure you don't lose any sensitive data!
    :type ignore_binary: bool, optional
    :param verbose: This parameter tells the test suite to use verbose logs,
    defaults to False
    :type verbose: bool, optional
    """


    config_path = os.path.join(path, "config.nim")
    main_path = os.path.join(path, "japl.nim")
    listing = "\n- {} = {}"
    if not os.path.exists(path):
        logging.error(f"Input path '{path}' does not exist")
        return False
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
            return False
        else:
            logging.debug(f"Config file has been generated, compiling with options as follows: {''.join(listing.format(k, v) for k, v in options.items())}")
    logging.debug(f"Nim compiler options: {''.join(listing.format(k, v) for k, v in flags.items())}")
    logging.debug(f"Compiling '{main_path}'")
    nim_flags = " ".join(f"-{name}:{value}" if len(name) == 1 else f"--{name}:{value}" for name, value in flags.items())
    command = "nim {flags} compile {path}".format(flags=nim_flags, path=main_path)
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
            test_runner_path = "./tests/jatr" if os.name != "nt" else ".\tests\jatr"
            tests_path = "./tests/jats" if os.name != "nt" else ".\tests\jats"
            command = "nim {flags} compile {path}".format(flags=nim_flags, path=test_runner_path)
            _, stderr, status = run_command(command, stdout=DEVNULL, stderr=PIPE)
            if status != 0:
                logging.error(f"Command '{command}' exited with non-0 exit code {status}, output below:\n{stderr.decode()}")
                return False
            command = f"nim compile --opt:speed {tests_path}"
            _, stderr, status = run_command(command, stdout=DEVNULL, stderr=PIPE)
            if status != 0:
                logging.error(f"Command '{command}' exited with non-0 exit code {status}, output below:\n{stderr.decode()}")
                return False
            logging.debug(f"Test suite compilation completed in {time() - start:.2f} seconds")
            logging.debug("Running tests")
            start = time()
            # TODO: Find a better way of running the test suite
            process = run_command(f"{tests_path} {'-e' if verbose else ''}", mode="run", shell=True, stderr=PIPE)
            if status != 0:
                logging.error(f"Command '{command}' exited with non-0 exit code {status}, output below:\n{stderr.decode()}")
                return False
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
        return True


if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser()
        parser.add_argument("path", help="The path to JAPL's source directory")
        parser.add_argument("--verbose", help="Prints debug information to stdout", action="store_true", default=os.getenv("JAPL_VERBOSE"))
        parser.add_argument("--flags", help="Optional flags to be passed to the nim compiler. Must be a comma-separated list of name:value (without spaces)", default=os.getenv("JAPL_FLAGS"))
        parser.add_argument("--options", help="Set compile-time options and constants, pass a comma-separated list of name:value (without spaces)."
        " Note that if a config.nim file already exists in the destination directory, that will override any setting defined here unless --override-config is used", default=os.getenv("JAPL_OPTIONS"))
        parser.add_argument("--override-config", help="Overrides the setting of an already existing config.nim file in the destination directory", action="store_true", default=os.getenv("JAPL_OVERRIDE_CONFIG"))
        parser.add_argument("--skip-tests", help="Skips running the JAPL test suite, useful for debug builds", action="store_true", default=os.getenv("JAPL_SKIP_TESTS"))
        parser.add_argument("--install", help="Tries to move the compiled binary to PATH (this is always disabled on windows)", action="store_true", default=os.environ.get("JAPL_INSTALL"))
        parser.add_argument("--ignore-binary", help="Ignores an already existing 'jpl' binary in any installation directory and overwrites it, use (with care!) with --install", action="store_true", default=os.getenv("JAPL_IGNORE_BINARY"))
        parser.add_argument("--profile", help="The path to a json file specifying build options and arguments. Overrides ANY other option!", default=os.environ.get("JAPL_PROFILE"))
        args = parser.parse_args()
        flags = {
                "gc": "refc",
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
        logging.basicConfig(format="[JABT - %(levelname)s - %(asctime)s] %(message)s",
                            datefmt="%T",
                            level=logging.DEBUG if args.verbose else logging.INFO
                            )
        logging.info("Just Another Build Tool, version 0.3.4")
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
                        logging.error(f"Invalid compile-time option '{k}'")
                        exit()
                    options[k] = v
            except Exception:
                logging.error("Invalid parameter for --options")
                exit()
        if args.profile:
            try:
                with open(args.profile) as profile:
                    skip = 0
                    line = profile.readline()
                    while line.startswith("//"):
                        # We skip comments and keep track of
                        # where we should reset our buffer
                        skip = profile.tell()
                        line = profile.readline()
                    profile.seek(skip - 1)
                    data = json.load(profile)
                    if "options" in data:
                        for option, value in data["options"].items():
                            options[option] = value
                    if "flags" in data:
                        for flag, value in data["flags"].items():
                            flags[flag] = value
                    for arg in {"override_config", "skip_tests", "verbose", "install", "ignore_binary"}:
                        setattr(args, arg, data.get(arg, getattr(args, arg)))
            except Exception as e:
                logging.error(f"An error occurred while loading profile '{args.profile}' -> {type(e).__name__}: {e}")
                exit()
            else:
                logging.info(f"Using profile '{args.profile}'")
        if build(args.path,
              flags,
              options,
              args.override_config,
              args.skip_tests,
              args.install,
              args.ignore_binary,
              args.verbose):
            logging.debug("Build tool exited successfully")
        else:
            logging.debug("Build tool exited with error")
            exit(1)
    except KeyboardInterrupt:
        logging.info("Interrupted by the user")
