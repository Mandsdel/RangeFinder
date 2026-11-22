local _, RangeFinder = ...

local Range = {}
RangeFinder.Range = Range

function Range.IsReadable(value)
    return not (type(issecretvalue) == "function" and issecretvalue(value))
end

function Range.IsValid(value)
    return Range.IsReadable(value) and type(value) == "number"
        and value == value
        and value >= 0
        and value < math.huge
end

function Range.Approximate(minimum, maximum)
    if not Range.IsValid(minimum) or not Range.IsValid(maximum) or minimum >= maximum then
        return nil
    end
    return {
        minimum = minimum,
        maximum = maximum,
    }
end

function Range.IsApproximate(value)
    return Range.IsReadable(value) and type(value) == "table"
        and Range.IsValid(value.minimum)
        and Range.IsValid(value.maximum)
        and value.minimum < value.maximum
end

function Range.Above(minimum)
    if not Range.IsValid(minimum) then
        return nil
    end
    return { minimum = minimum }
end

function Range.IsAbove(value)
    return Range.IsReadable(value) and type(value) == "table"
        and Range.IsValid(value.minimum)
        and Range.IsReadable(value.maximum)
        and value.maximum == nil
end

function Range.Read(getDistance)
    local value, reason = getDistance()
    if not Range.IsValid(value) and not Range.IsApproximate(value) and not Range.IsAbove(value) then
        return nil, reason or "invalid or unavailable measurement"
    end
    return value
end

function Range.Format(value)
    if Range.IsValid(value) then
        return string.format("%.0f yd", math.floor(value + 0.5))
    end
    if Range.IsApproximate(value) then
        return string.format(
            "%.0f-%.0f yd",
            math.floor(value.minimum + 0.5),
            math.floor(value.maximum + 0.5)
        )
    end
    if Range.IsAbove(value) then
        return string.format("%.0f+ yd", math.floor(value.minimum + 0.5))
    end
    return "N/A"
end
