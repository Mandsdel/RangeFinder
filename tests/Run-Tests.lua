local namespace = {}
for _, file in ipairs({ "Range.lua", "Display.lua", "Options.lua", "Core.lua" }) do
    local chunk, errorMessage = loadfile(file)
    assert(chunk, errorMessage)
    chunk("RangeFinder", namespace)
end

local count = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        error(name .. ": " .. tostring(err), 0)
    end
    count = count + 1
end

local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function setup(saved)
    local state = {
        target = false,
        value = nil,
        reads = 0,
        textUpdates = 0,
        fontUpdates = 0,
        visible = nil,
        diagnostics = {},
    }
    local view = {}
    function view:SetText(value)
        state.text = value
        state.textUpdates = state.textUpdates + 1
    end
    function view:SetFontSize(value)
        state.fontSize = value
        state.fontUpdates = state.fontUpdates + 1
    end
    function view:SetVisible(value)
        state.visible = value
    end
    local adapter = {
        view = view,
        hasTarget = function() return state.target end,
        getDistance = function()
            state.reads = state.reads + 1
            if state.failure then
                error("distance API failure")
            end
            return state.value, state.reason
        end,
        diagnostic = function(message)
            table.insert(state.diagnostics, message)
        end,
    }
    local storage = saved or {}
    return namespace.Core.New(adapter, storage), state, storage
end

test("whole-yard formatting", function()
    for _, item in ipairs({
        { 0, "0 yd" }, { 0.49, "0 yd" }, { 0.5, "1 yd" },
        { 23.49, "23 yd" }, { 23.5, "24 yd" }, { 1234, "1234 yd" },
    }) do
        equal(namespace.Range.Format(item[1]), item[2])
    end
    equal(namespace.Range.Format(namespace.Range.Approximate(10, 30)), "10-30 yd")
    equal(namespace.Range.Format(namespace.Range.Above(50)), "50+ yd")
end)

test("invalid measurements and unavailable reason", function()
    for _, value in ipairs({ -1, "23", 0 / 0, math.huge, -math.huge }) do
        equal(namespace.Range.Format(value), "N/A")
        local result = namespace.Range.Read(function() return value end)
        equal(result, nil)
    end
    equal(namespace.Range.Format(nil), "N/A")
    local result, reason = namespace.Range.Read(function() return nil, "out of range" end)
    equal(result, nil)
    equal(reason, "out of range")
    local valid = namespace.Range.Read(function() return 0 end)
    equal(valid, 0)
end)

test("initialization without target is idempotent and does not poll", function()
    local controller, state, saved = setup()
    controller:Initialize()
    controller:Initialize()
    for _ = 1, 10 do controller:OnUpdate(1) end
    equal(state.text, "N/A")
    equal(state.visible, false)
    equal(state.reads, 0)
    equal(state.textUpdates, 1)
    equal(state.fontUpdates, 1)
    equal(saved.fontSize, 14)
end)

test("already selected target and world entry refresh", function()
    local controller, state = setup({ fontSize = 18 })
    state.target = true
    state.value = 12.5
    controller:Initialize()
    equal(state.text, "13 yd")
    equal(state.visible, true)
    equal(state.fontSize, 18)
    state.value = 21
    controller:OnWorldEntry()
    equal(state.text, "21 yd")
end)

test("target switching clearing and disappearing replace old values", function()
    local controller, state = setup()
    controller:Initialize()
    state.target = true
    state.value = 20
    controller:OnTargetChanged()
    equal(state.text, "20 yd")
    state.value = nil
    controller:OnTargetChanged()
    equal(state.text, "N/A")
    state.value = 4
    controller:OnTargetChanged()
    equal(state.text, "4 yd")
    state.target = false
    controller:OnTargetChanged()
    equal(state.text, "N/A")
    equal(state.reads, 3)
    state.target = true
    state.value = 7
    controller:OnTargetChanged()
    state.target = false
    controller:OnUpdate(0.1)
    equal(state.text, "N/A")
    equal(state.reads, 4)
    controller:OnUpdate(1)
    equal(state.reads, 4)
end)

test("polling is throttled without catch-up bursts", function()
    local controller, state = setup()
    state.target = true
    state.value = 1
    controller:Initialize()
    controller:OnUpdate(0.04)
    controller:OnUpdate(0.05)
    equal(state.reads, 1)
    controller:OnUpdate(0.02)
    equal(state.reads, 2)
    controller:OnUpdate(10)
    equal(state.reads, 3)
    controller:OnUpdate(0.01)
    equal(state.reads, 3)
    state.value = 2
    controller:OnTargetChanged()
    equal(state.reads, 4)
    equal(state.text, "2 yd")
end)

test("range shapes pass through the controller and replace stale values", function()
    local controller, state = setup()
    state.target = true
    state.value = namespace.Range.Above(50)
    controller:Initialize()
    equal(state.text, "50+ yd")
    state.value = namespace.Range.Approximate(10, 30)
    controller:OnTargetChanged()
    equal(state.text, "10-30 yd")
    state.value = 6
    controller:OnUpdate(0.1)
    equal(state.text, "6 yd")
    state.value = { minimum = 30, maximum = 10 }
    controller:OnUpdate(0.1)
    equal(state.text, "N/A")
    state.value = namespace.Range.Above(0)
    controller:OnUpdate(0.1)
    equal(state.text, "0+ yd")
    state.target = false
    controller:OnTargetChanged()
    equal(state.text, "N/A")
    equal(state.visible, false)
end)

test("settings normalize persist and diagnose repairs", function()
    for _, item in ipairs({
        { 7, 8, 1 }, { 32.6, 32, 1 }, { 14.5, 15, 1 },
        { "18", 14, 1 }, { math.huge, 14, 1 }, { 0 / 0, 14, 1 },
        { 8, 8, 0 }, { 32, 32, 0 },
    }) do
        local controller, state, saved = setup({ fontSize = item[1] })
        controller:Initialize()
        equal(saved.fontSize, item[2])
        equal(state.fontSize, item[2])
        equal(#state.diagnostics, item[3])
        controller:Initialize()
        equal(#state.diagnostics, item[3])
    end
    local controller, state, saved = setup()
    controller:Initialize()
    controller.options:SetFontSize(20)
    controller.options:SetFontSize(20)
    equal(saved.fontSize, 20)
    equal(state.fontSize, 20)
    equal(state.fontUpdates, 2)
end)

test("unchanged text does not redraw", function()
    local controller, state = setup()
    state.target = true
    state.value = 10.1
    controller:Initialize()
    state.value = 10.2
    controller:OnUpdate(0.1)
    equal(state.reads, 2)
    equal(state.textUpdates, 1)
end)

local function checkView(backdrop)
    local metrics = { points = 0, width = 0, height = 0 }
    local text = {}
    function text:SetPoint() end
    function text:SetJustifyH() end
    function text:SetTextColor(r, g, b)
        equal(r, 1); equal(g, 0.82); equal(b, 0)
    end
    function text:SetShadowColor(r, g, b, a)
        equal(r, 0); equal(g, 0); equal(b, 0); equal(a, 1)
    end
    function text:SetShadowOffset(x, y) equal(x, 1); equal(y, -1) end
    function text:SetFont(path, size)
        equal(path, "font")
        metrics.fontSize = size
        return true
    end
    function text:SetText(value) metrics.text = value end
    function text:GetStringWidth() return #(metrics.text or "") * (metrics.fontSize or 0) end
    function text:GetStringHeight() return metrics.fontSize or 0 end
    local texture = {}
    function texture:SetAllPoints() end
    function texture:SetTexture(path)
        equal(path, "Interface\\DialogFrame\\UI-DialogBox-Background")
        metrics.textured = true
    end
    local frame = {}
    if backdrop then
        function frame:SetBackdrop(value)
            equal(value.edgeFile, "Interface\\Tooltips\\UI-Tooltip-Border")
            equal(value.bgFile, "Interface\\DialogFrame\\UI-DialogBox-Background")
            metrics.textured = true
        end
        function frame:SetBackdropBorderColor(r, g, b, a)
            equal(r, 0.65); equal(g, 0.55); equal(b, 0.35); equal(a, 1)
        end
    end
    function frame:SetPoint(...)
        metrics.points = metrics.points + 1
        metrics.point = { ... }
    end
    function frame:EnableMouse(value) equal(value, false) end
    function frame:CreateTexture() return texture end
    function frame:CreateFontString() return text end
    function frame:SetSize(width, height)
        metrics.width, metrics.height = width, height
    end
    local anchor = {}
    local view = namespace.Display.CreateView(function() return frame end, {}, "font", anchor)
    equal(metrics.textured, true)
    equal(metrics.point[1], "BOTTOM")
    equal(metrics.point[2], anchor)
    equal(metrics.point[3], "TOP")
    equal(metrics.point[4], 0)
    equal(metrics.point[5], 0)
    view:SetFontSize(14)
    view:SetText("1234 yd")
    equal(metrics.width, 114)
    equal(metrics.height, 26)
    view:SetFontSize(32)
    equal(metrics.width, 240)
    equal(metrics.height, 44)
    equal(metrics.points, 1)
end

test("view resizes without moving its anchor", function() checkView(true) end)
test("view supports clients without backdrops", function() checkView(false) end)

test("API errors remain visible", function()
    local controller, state = setup()
    state.target = true
    state.failure = true
    local ok, err = pcall(function() controller:Initialize() end)
    equal(ok, false)
    assert(tostring(err):find("distance API failure", 1, true))
    state.failure = false
    state.value = 8
    controller:Initialize()
    equal(state.text, "8 yd")
    state.failure = true
    local changed, changeError = pcall(function() controller:OnTargetChanged() end)
    equal(changed, false)
    assert(tostring(changeError):find("distance API failure", 1, true))
    equal(state.text, "N/A")
end)

test("bootstrap bypasses target-token cache and preserves range shapes", function()
    local scripts = {}
    local displayed
    local minimum, maximum = 50, nil
    local checkedSquared, checked = nil, false
    local rangeReads = 0
    local hasTarget = true
    local playerPosition, targetPosition
    local positionReads = 0
    local unpackValues = unpack or table.unpack
    local secret = {}
    local environment = setmetatable({
        RangeFinderDB = {},
        print = function() end,
        UnitExists = function() return hasTarget end,
        UnitDistanceSquared = function() return checkedSquared, checked end,
        issecretvalue = function(value) return value == secret end,
        UnitPosition = function(unit)
            positionReads = positionReads + 1
            local position
            if unit == "player" then
                position = playerPosition
            else
                position = targetPosition
            end
            if position then
                return unpackValues(position)
            end
        end,
        TargetFrame = { TargetFrameContainer = { Portrait = {} } },
        CreateFrame = function()
            return {
                RegisterEvent = function() end,
                UnregisterEvent = function() end,
                SetScript = function(_, event, fn) scripts[event] = fn end,
            }
        end,
        LibStub = function()
            return {
                GetRange = function(_, unit, checkVisible, noItems, maxCacheAge)
                    equal(unit, "target")
                    equal(checkVisible, nil)
                    equal(noItems, nil)
                    equal(maxCacheAge, 0)
                    rangeReads = rangeReads + 1
                    return minimum, maximum
                end,
            }
        end,
    }, { __index = _G })
    local addon = {
        Range = namespace.Range,
        Core = namespace.Core,
        Display = {
            CreateView = function()
                return {
                    SetText = function(_, value) displayed = value end,
                    SetFontSize = function() end,
                    SetVisible = function() end,
                }
            end,
        },
    }
    local chunk, errorMessage
    if setfenv then
        chunk, errorMessage = loadfile("Bootstrap.lua")
        assert(chunk, errorMessage)
        setfenv(chunk, environment)
    else
        chunk, errorMessage = loadfile("Bootstrap.lua", "t", environment)
        assert(chunk, errorMessage)
    end
    chunk("RangeFinder", addon)
    scripts.OnEvent(nil, "ADDON_LOADED", "RangeFinder")
    scripts.OnEvent(nil, "PLAYER_LOGIN")
    equal(displayed, "50+ yd")
    assert(scripts.OnUpdate)
    minimum, maximum = 10, 30
    scripts.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    equal(displayed, "10-30 yd")
    minimum, maximum = 30, 40
    scripts.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    equal(displayed, "30-40 yd")
    equal(rangeReads, 3)
    checkedSquared, checked = 529, true
    scripts.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    equal(displayed, "23 yd")
    equal(rangeReads, 3)
    local previousPositionReads = positionReads
    scripts.OnUpdate(nil, 0.1)
    equal(positionReads, previousPositionReads)

    checkedSquared, checked = nil, false
    playerPosition = { -10, -20, -30, 1 }
    targetPosition = { -7, -16, -30, 1 }
    scripts.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    equal(displayed, "5 yd")
    equal(rangeReads, 3)
    targetPosition = { -7, -16, -18, 1 }
    scripts.OnUpdate(nil, 0.1)
    equal(displayed, "13 yd")
    targetPosition = { -10, -20, -30, 1 }
    scripts.OnUpdate(nil, 0.1)
    equal(displayed, "0 yd")
    targetPosition = { 6662, -20, -30, 1 }
    scripts.OnUpdate(nil, 0.1)
    equal(displayed, "6672 yd")
    equal(rangeReads, 3)

    for _, position in ipairs({
        { -7, -16, -30, 2 },
        { -7, -16, -30 },
        { secret, -16, -30, 1 },
        { -7, -16, -30, secret },
        { 0 / 0, -16, -30, 1 },
        { math.huge, -16, -30, 1 },
        { "3", -16, -30, 1 },
    }) do
        targetPosition = position
        scripts.OnUpdate(nil, 0.1)
        equal(displayed, "30-40 yd")
    end
    targetPosition = { -7, -16, -30, 1 }
    for _, squared in ipairs({ -1, 0 / 0, math.huge, secret }) do
        checkedSquared, checked = squared, true
        scripts.OnUpdate(nil, 0.1)
        equal(displayed, "5 yd")
    end
    checkedSquared, checked = 529, false
    scripts.OnUpdate(nil, 0.1)
    equal(displayed, "5 yd")
    checked = secret
    scripts.OnUpdate(nil, 0.1)
    equal(displayed, "5 yd")
    checkedSquared, checked = 0, true
    scripts.OnUpdate(nil, 0.1)
    equal(displayed, "0 yd")
    checkedSquared, checked = nil, false
    playerPosition = nil
    scripts.OnUpdate(nil, 0.1)
    equal(displayed, "30-40 yd")
    environment.UnitPosition = false
    scripts.OnUpdate(nil, 0.1)
    equal(displayed, "30-40 yd")
    environment.UnitDistanceSquared = false
    scripts.OnUpdate(nil, 0.1)
    equal(displayed, "30-40 yd")
    hasTarget = false
    scripts.OnUpdate(nil, 0.1)
    equal(displayed, "N/A")
    equal(scripts.OnUpdate, nil)
    hasTarget = true
    scripts.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    assert(scripts.OnUpdate)
    hasTarget = false
    scripts.OnEvent(nil, "PLAYER_TARGET_CHANGED")
    equal(scripts.OnUpdate, nil)
end)

print("Passed " .. count .. " tests")
