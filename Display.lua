local _, RangeFinder = ...

local Display = {}
RangeFinder.Display = Display

function Display.CreateView(createFrame, parent, fontPath, anchorFrame)
    assert(anchorFrame, "RangeFinder: TargetFrame is unavailable")
    local frame = createFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 0)
    frame:EnableMouse(false)

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropBorderColor(0.65, 0.55, 0.35, 1)
    else
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(frame)
        background:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    end

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", frame, "CENTER")
    text:SetJustifyH("CENTER")
    text:SetTextColor(1, 0.82, 0)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    local view = { frame = frame }

    local function resize()
        frame:SetSize(math.max(40, text:GetStringWidth() + 16), text:GetStringHeight() + 12)
    end

    function view:SetText(value)
        text:SetText(value)
        resize()
    end

    function view:SetFontSize(size)
        if not text:SetFont(fontPath, size) then
            error("RangeFinder: unable to set display font")
        end
        resize()
    end

    function view:SetVisible(visible)
        if visible then
            frame:Show()
        else
            frame:Hide()
        end
    end

    return view
end

function Display.New(view)
    local display = { view = view }

    function display:Render(measurement)
        local text = RangeFinder.Range.Format(measurement)
        if text ~= self.text then
            self.view:SetText(text)
            self.text = text
        end
    end

    function display:SetVisible(visible)
        if visible ~= self.visible then
            self.view:SetVisible(visible)
            self.visible = visible
        end
    end

    function display:SetFontSize(size)
        if size ~= self.fontSize then
            self.view:SetFontSize(size)
            self.fontSize = size
        end
    end

    return display
end
