
func stringify*(value: Value): string =
    case value.kind:
        of ValueType.Integer:
            result = $value.toInt()
        of ValueType.Double:
            result = $value.toFloat()
        of ValueType.Bool:
            result = $value.toBool()
        of ValueType.Nil:
            result = "nil"
        of ValueType.Object:
            case value.obj.kind:
                of ObjectType.String:
                    result = cast[ptr String](value.obj).stringify
                of ObjectType.Function:
                    result = cast[ptr Function](value.obj).stringify
                else:
                    result = "TODO this was not implemented"
        of ValueType.Nan:
            result = "nan"
        of ValueType.Inf:
            result = "inf"
        of ValueType.Minf:
            result = "-inf"

func bool*(value: Value): bool =
    case value.kind:
        of ValueType.Bool:
            result = not value.toBool()
        of ValueType.Object:
            case value.obj.kind:
                of ObjectType.String:
                    result = cast[ptr String](value.obj).isFalsey()
                of ObjectType.Function:
                    result = cast[ptr Function](value.obj).isFalsey()
                of ObjectType.Exception:
                    result = cast[ptr JaplException](value.obj).isFalsey()
                of ObjectType.Class:
                    result = cast[ptr JaplException](value.obj).isFalsey()
                of ObjectType.Module:
                    result = cast[ptr JaplException](value.obj).isFalsey()
                of ObjectType.BaseObject:
                    result = cast[ptr JaplException](value.obj).isFalsey()
        of ValueType.Integer:
            result = value.toInt() == 0
        of ValueType.Double:
            result = value.toFloat() == 0.0
        of ValueType.Nil:
            result = true
        of ValueType.Inf, ValueType.Minf:
            result = false
        of ValueType.Nan:
            result = true

func typeName*(value: Value): string =
    case value.kind:
        of ValueType.Bool, ValueType.Nil, ValueType.Double,
          ValueType.Integer, ValueType.Nan, ValueType.Inf:
            result = ($value.kind).toLowerAscii()
        of ValueType.Minf:
           result = "inf"
        of ValueType.Object:
            case value.obj.kind:
                of ObjectType.String:
                    result = cast[ptr String](value.obj).typeName()
                of ObjectType.Function:
                    result = cast[ptr Function](value.obj).typeName()
                else:
                    result = value.obj.typeName()

proc eq*(a: Value, b: Value): bool =
    if a.kind != b.kind:
        result = false
    else:
        case a.kind:
            of ValueType.Bool:
                result = a.toBool() == b.toBool()
            of ValueType.Nil:
                result = true
            of ValueType.Integer:
                result = a.toInt() == b.toInt()
            of ValueType.Double:
                result = a.toFloat() == b.toFloat()
            of ValueType.Object:
                case a.obj.kind:
                    of ObjectType.String:
                        var a = cast[ptr String](a.obj)
                        var b = cast[ptr String](b.obj)
                        result = valuesEqual(a, b)
                    of ObjectType.Function:
                        var a = cast[ptr Function](a.obj)
                        var b = cast[ptr Function](b.obj)
                        result = valuesEqual(a, b)
                    else:
                        result = valuesEqual(a.obj, b.obj)
            of ValueType.Inf:
                result = b.kind == ValueType.Inf
            of ValueType.Minf:
                result = b.kind == ValueType.Minf
            of ValueType.Nan:
                result = false
  
