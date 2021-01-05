import ../src/multibyte


template testMultibyte* =
    for i in countup(0, int(uint16.high())):
        assert fromDouble(toDouble(i)) == uint16(i)

