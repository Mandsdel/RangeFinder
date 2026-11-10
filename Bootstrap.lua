local addonName, RangeFinder = ...

local controller
local rangeChecker = LibStub("LibRangeCheck-3.0", true)

local function diagnostic(message)
    print("|cff00bfff" .. addonName .. ":|r " .. message)
end

local function getDistance()
    local distanceSquared, checkedDistance = UnitDistanceSquared("target")
    if type(distanceSquared) == "number" and checkedDistance then
        return math.sqrt(distanceSquared)
    end

    if not rangeChecker then
        error("RangeFinder: LibRangeCheck-3.0 failed to load")
    end

    -- A unit-token cache can still contain the previous target when GUIDs are secret.
    local minimum, maximum = rangeChecker:GetRange("target", nil, nil, 0)
    if minimum and maximum then
        return RangeFinder.Range.Approximate(minimum, maximum)
    end
    if minimum then
        return RangeFinder.Range.Above(minimum)
    end
    return nil, "no checked or approximate target range"
end

local function createOptions()
    if not Settings or not Settings.RegisterVerticalLayoutCategory
        or not Settings.RegisterAddOnSetting or not Settings.CreateSlider then
        diagnostic("Options panel is unavailable on this client.")
        return
    end

    local category = Settings.RegisterVerticalLayoutCategory("RangeFinder")
    local setting = Settings.RegisterAddOnSetting(
        category,
        "RANGEFINDER_FONT_SIZE",
        "fontSize",
        RangeFinderDB,
        Settings.VarType.Number,
        "Font size",
        RangeFinderDB.fontSize
    )
    setting:SetValueChangedCallback(function(_, value)
        controller.options:SetFontSize(value)
    end)

    local options = Settings.CreateSliderOptions(8, 32, 1)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return value .. " px"
    end)
    Settings.CreateSlider(category, setting, options, "Size of the RangeFinder text.")
    Settings.RegisterAddOnCategory(category)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then
            return
        end
        RangeFinderDB = type(RangeFinderDB) == "table" and RangeFinderDB or {}
        return
    end

    if event == "PLAYER_LOGIN" then
        local view = RangeFinder.Display.CreateView(
            CreateFrame,
            UIParent,
            STANDARD_TEXT_FONT,
            TargetFrame and TargetFrame.TargetFrameContainer
                and TargetFrame.TargetFrameContainer.Portrait
        )
        controller = RangeFinder.Core.New({
            view = view,
            hasTarget = function()
                return UnitExists("target")
            end,
            getDistance = getDistance,
            diagnostic = diagnostic,
        }, RangeFinderDB)
        controller:Initialize()
        createOptions()
        return
    end

    if controller then
        if event == "PLAYER_TARGET_CHANGED" then
            controller:OnTargetChanged()
        elseif event == "PLAYER_ENTERING_WORLD" then
            controller:OnWorldEntry()
        end
    end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
    if controller then
        controller:OnUpdate(elapsed)
    end
end)
