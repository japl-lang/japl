import base64
const language = 1

when language == 1:
  const aa* = "ICBfX18gICAgX19fICAgX19fICBfX18gIF9fXyAgX19fICAgICAgIF9fICAgICAgX18gIF9fXyAgICBfX18gICBfX18gIF9fXyAgX19fICBfX18gCiAvIF8gXCAgLyBfIFwgfCBfIFwvIF9ffHxfIF98fCBfX3wgICAgICBcIFwgICAgLyAvIC8gXyBcICAvIF8gXCB8IF8gXC8gX198fF8gX3x8IF9ffAp8IChfKSB8fCAoXykgfHwgIF8vXF9fIFwgfCB8IHwgX3wgICAgICAgIFwgXC9cLyAvIHwgKF8pIHx8IChfKSB8fCAgXy9cX18gXCB8IHwgfCBffCAKIFxfX18vICBcX19fLyB8X3wgIHxfX18vfF9fX3x8X19ffCAgICAgICAgXF8vXF8vICAgXF9fXy8gIFxfX18vIHxffCAgfF9fXy98X19ffHxfX198Cgo="

  const bb* = "VXd1IFdlIG1hZGUgYSBmKmNreSB3dWNreSEhIEEgd2l0dGxlIGYqY2tvIGJvaW5nbyE="
  const cc* = "VGhlIGNvZGUgbW9ua2V5cyBhdCBvdXIgaGVhZHF1YXJ0ZXJzIGFyZSB3b3JraW5nIFZFV1kgSEFXRCB0byBmaXggdGhpcyEK"

proc errorDisplay* =
    when language == 1:
        echo decode aa
        echo decode bb
        echo decode cc
    else:
        echo "Unsupported language."
