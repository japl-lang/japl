import multibyte
import ../logutils

proc runNimTests* =
    log(LogLevel.Info, "Running nim tests.")
    testMultibyte()
    log(LogLevel.Debug, "Nim tests finished")

when isMainModule:
    runNimTests()
