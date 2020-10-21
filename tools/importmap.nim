## Walks through a dir recursively and maps all imports into a chart
## - reads only *.nim files
## - descends into subdirs
## - if it encounters an import it figures out which files are being
## imported from where
## - creates a tree and prints it to terminal/stdout

import strutils, os, re, sets, sequtils, sugar

# Types
type
  Nim = ref object
    path: string
    imports: seq[string]

func newNim(path: string, imports: seq[string]) : Nim =
  Nim(path: path, imports: imports)

# Vars

var
  project: seq[Nim]
let
  toIgnore: HashSet[string] = toHashSet(["os", #non-exhaustive!
    # maybe not even neccessary with the dep listing in sort()
    # but sort() is unfinished
    "strutils",
    "algorithm",
    "tables",
    "sequtils",
    "bitops",
    "cpuinfo",
    "endians",
    "lenientops",
    "locks",
    "macros",
    "rlocks",
    "typeinfo",
    "typetraits",
    "volatile",
    "critbits",
    "deques",
    "heapqueue",
    "intsets",
    "lists",
    "options",
    "sets",
    "sharedlist",
    "sharedtables",
    "cstrutils",
    "std/editdistance",
    "encodings",
    "parseutils",
    "pegs",
    "punycode",
    "ropes",
    "strformat",
    "strmisc",
    "strscans",
    "strtabs",
    "unicode",
    "unidecode",
    "std/wordwrap",
    "std/monotimes",
    "times",
    "distros",
    "dynlib",
    "marshal",
    "memfiles",
    "osproc",
    "streams",
    "terminal",
    "complex",
    "fenv",
    "math",
    "mersenne",
    "random",
    "rationals",
    "stats",
    "std/sums",
    "threadpool",
    "json",
    "lexbase",
    "parsecsv",
    "parseopt",
    "parsesql",
    "parsexml",
    "htmlgen",
    "base64",
    "hashes",
    "md5",
    "oids",
    "std/sha1",
    "colors",
    "logging",
    "segfaults",
    "sugar",
    "unittest",
    "std/variants",
    "browsers"
    ])

# Procs

proc importList(path: string) : seq[string] =
  ## Gets the list of imports the file at path uses

  var temp: string
  var imports: seq[string]
  for line in lines(path):
    if line.find(re"^[ ]*import") != -1:
      temp = line
      temp.removeSuffix(' ')
      temp.removePrefix("import")
      temp.removePrefix(' ')
      imports = temp.split(",")
      for cImport in imports:
        if not toIgnore.contains(cImport):
          result.add(cImport.strip())

proc absolutize(pre: seq[string], path: string): seq[string] =
  ## Takes relative paths and a path of the nim file.
  ## Produces a list of absolute paths.
  for localPath in pre:
    result.add(joinPath(parentDir(path), localPath))

proc mapDir(toMap: string) =
  for a, path in walkDir(toMap):
    if dirExists(path):
      mapDir(path)
    else:
      project.add(newNim(path, importList(path).absolutize(path)))


proc sort(project: seq[Nim]): seq[Nim] =
  # WIP AND DOES NOT WORK YET


  ## Sorts them so no module depends on a module below it
  # homebrew, slow sorting algorithm (yes I do not have formal training
  # in writing (sorting) algorithms)
  #
  # - Iterate through the entire list, getting the list of possible dependencies
  # (external dependencies should not be passed)
  # - go throught the list, and put those which have no unresolved dependencies to the top
  # - shrink the original list like this, until it's empty
  # - error with circular deps if can't empty after 255 cycles
  var
    unassigned: seq[Nim]
    depSet: seq[string]
    ordered: seq[Nim]
    cUnassigned: Nim
    toRemove: seq[string]
  for dep in project:
    depSet.add(dep.path)
    unassigned.add(dep)
  
  proc inOrder(): bool =
    depSet.len() == 0

  while not inOrder():
    for i in 0..unassigned.high():
      cUnassigned = unassigned[i]
      block eval:
        for cDep in cUnassigned.imports:
          if cDep in depSet:
            break eval
        # eval not broken: no deps
        depSet = depSet.filter((x) => x != cUnassigned.path)
        ordered.add(cUnassigned)
        toRemove.add(cUnassigned.path)
    unassigned = unassigned.filter((x) => x.path notin toRemove)
    toRemove = @[]

  ordered

# Main code

mapDir(".")
project = sort(project)

for module in project:
  echo module.path & ":"
  for dep in module.imports:
    echo "  " & dep
