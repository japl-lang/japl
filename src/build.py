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
import shlex
import logging
import argparse
from time import time
from typing import Dict
from subprocess import Popen, PIPE, DEVNULL


def build(path: str = os.getcwd(), flags: Dict[str, str] = {}):
    """
    Compiles the JAPL runtime, nim 1.2 or above is required to build it

    :param path: The directory where JAPL's main.nim file
    is located, defaults to the current directory
    :type path: string, optional
    :param flags: Any extra compiler flags that will
    be passed to nim. Keys and values should be strings,
    but any object with a proper __str__ or __repr__
    method is probably fine as long as it's a valid
    nim option for the compiler. Defaults to {} (no flags)
    :type flags: dict, optional
    """

    logging.info("JAPL build script version 0.1")
    if not os.path.exists(path):
        logging.error(f"Input path '{path}' does not exist")
        return
    logging.debug(f"Compiling '{os.path.join(path, 'main.nim')}'")
    nim_flags = " ".join(f"-{name}:{value}" if len(name) == 1 else f"--{name}:{value}" for name, value in flags.items())
    command = "nim {flags} compile {path}"
    command = command.format(flags=nim_flags, path=os.path.join(path, 'main.nim'))
    logging.debug(f"Running '{command}'")
    logging.info("Compiling JAPL")
    start = time()
    try:
        process = Popen(shlex.split(command), stdout=DEVNULL, stderr=PIPE)
        _, stderr = process.communicate()
        stderr = stderr.decode()
        assert process.returncode == 0, f"Command '{command}' exited with non-0 exit code {process.returncode}, output below:\n{stderr}"
    except Exception as fatal:
        logging.error(f"A fatal unhandled exception occurred -> {type(fatal).__name__}: {fatal}")
    else:
        logging.debug(f"Compilation completed in {time() - start:.2f} seconds")
        logging.info("Build completed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", help="The directory where JAPL's main.nim file is located, defaults to the current directory")
    parser.add_argument("--verbose", help="Prints debug information to stdout", action="store_true")
    parser.add_argument("--flags", help="Optional flags to be passed to the nim compiler. Must be a comma-separated list of name:value (without spaces)")
    args = parser.parse_args()
    flags = {}
    level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(format="[%(levelname)s - %(asctime)s] %(message)s",
                        datefmt="%T",
                        level=level
                        )
    if args.flags:
        try:
            for value in args.flags.split(","):
                k, v = value.split(":", maxsplit=2)
                flags[k] = v
        except Exception:
            logging.error("Invalid parameter for --flags")
            exit()
    build(args.path or os.getcwd(), flags)
    logging.debug("Build tool exited")
