local addonName, RangeFinder = ...

local controller
local rangeChecker = LibStub("LibRangeCheck-3.0", true)

local function diagnostic(message)
    print("|cff00bfff" .. addonName .. ":|r " .. message)
end

local function isReadable(value)
    return not (type(issecretvalue) == "function" and issecretvalue(value))
end

local function isFiniteNumber(value)
    return isReadable(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

local function getPositionDistance()
    if type(UnitPosition) ~= "function" then
        return nil
    end

    local playerX, playerY, playerZ, playerInstance = UnitPosition("player")
    local targetX, targetY, targetZ, targetInstance = UnitPosition("target")
    if not isFiniteNumber(playerX) or not isFiniteNumber(playerY)
        or not isFiniteNumber(playerZ) or not isFiniteNumber(targetX)
        or not isFiniteNumber(targetY) or not isFiniteNumber(targetZ)
        or not isFiniteNumber(playerInstance) or not isFiniteNumber(targetInstance)
        or playerInstance ~= targetInstance then
        return nil
    end

    -- World coordinates are comparable only within the same instance.
    local dx, dy, dz = targetX - playerX, targetY - playerY, targetZ - playerZ
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    if RangeFinder.Range.IsValid(distance) then
        return distance
    end
end

local function getDistance()
    if type(UnitDistanceSquared) == "function" then
        local distanceSquared, checkedDistance = UnitDistanceSquared("target")
        if isReadable(checkedDistance) and checkedDistance
            and isFiniteNumber(distanceSquared) and distanceSquared >= 0 then
            return math.sqrt(distanceSquared)
        end
    end

    local positionDistance = getPositionDistance()
    if positionDistance ~= nil then
        return positionDistance
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
local polling = false
local function onUpdate(_, elapsed)
    controller:OnUpdate(elapsed)
    if not controller.hasTarget then
        frame:SetScript("OnUpdate", nil)
        polling = false
    end
end

local function updatePolling()
    if controller.hasTarget ~= polling then
        polling = controller.hasTarget
        frame:SetScript("OnUpdate", polling and onUpdate or nil)
    end
end

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
        frame:UnregisterEvent("ADDON_LOADED")
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
        updatePolling()
        return
    end

    if controller then
        if event == "PLAYER_TARGET_CHANGED" then
            controller:OnTargetChanged()
        elseif event == "PLAYER_ENTERING_WORLD" then
            controller:OnWorldEntry()
        end
        updatePolling()
    end
end)
