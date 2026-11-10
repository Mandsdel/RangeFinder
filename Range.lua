local _, RangeFinder = ...

local Range = {}
RangeFinder.Range = Range

function Range.IsValid(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value < math.huge
end

function Range.Read(getDistance)
    local value, reason = getDistance()
    if not Range.IsValid(value) then
        return nil, reason or "invalid or unavailable measurement"
    end
    return value
end

function Range.Format(value)
    if not Range.IsValid(value) then
        return "N/A"
    end
    return string.format("%.0f yd", math.floor(value + 0.5))
end
