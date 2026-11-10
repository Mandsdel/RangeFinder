local _, RangeFinder = ...

local Options = {}
RangeFinder.Options = Options

local function normalize(value)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge then
        return 14
    end
    return math.max(8, math.min(32, math.floor(value + 0.5)))
end

function Options.New(saved, display, diagnostic)
    local options = { saved = saved, display = display, diagnostic = diagnostic }

    function options:SetFontSize(value)
        local normalized = normalize(value)
        if value ~= nil and normalized ~= value then
            self.diagnostic("RangeFinder: invalid font size repaired to " .. normalized)
        end
        self.saved.fontSize = normalized
        self.display:SetFontSize(normalized)
        return normalized
    end

    function options:Initialize()
        return self:SetFontSize(self.saved.fontSize)
    end

    return options
end
