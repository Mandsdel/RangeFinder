local _, RangeFinder = ...

local Display = {}
RangeFinder.Display = Display

function Display.CreateView(createFrame, parent, fontPath, anchorFrame)
    assert(anchorFrame, "RangeFinder: TargetFrame is unavailable")
    local frame = createFrame("Frame", nil, parent)
    frame:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 0)
    frame:EnableMouse(false)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetColorTexture(0, 0, 0, 0.75)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", frame, "CENTER")
    text:SetJustifyH("CENTER")
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
