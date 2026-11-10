local _, RangeFinder = ...

local Core = {}
RangeFinder.Core = Core

-- The adapter is deliberately injected until the Forever integrations are verified.
function Core.New(adapter, saved)
    assert(type(saved) == "table", "RangeFinder saved settings must be a table")
    local controller = {
        adapter = adapter,
        measurement = nil,
        preview = false,
        hasTarget = false,
        elapsed = 0,
        initialized = false,
    }

    controller.display = RangeFinder.Display.New(adapter.view)
    controller.options = RangeFinder.Options.New(saved, controller.display, adapter.diagnostic)
    controller.editMode = RangeFinder.EditMode.New(controller)

    function controller:Render()
        self.display:SetVisible(self.hasTarget)
        self.display:Render(self.measurement, self.preview)
    end

    function controller:Refresh()
        self.hasTarget = self.adapter.hasTarget()
        self.measurement = nil
        if self.hasTarget then
            self.measurement = RangeFinder.Range.Read(self.adapter.getDistance)
        end
        self:Render()
    end

    function controller:OnTargetChanged()
        self.elapsed = 0
        self.hasTarget = self.adapter.hasTarget()
        self.measurement = nil
        self:Render()
        self:Refresh()
    end

    function controller:OnWorldEntry()
        self:OnTargetChanged()
    end

    function controller:OnUpdate(elapsed)
        if not self.hasTarget then
            return
        end
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 0.1 then
            self.elapsed = 0
            self:Refresh()
        end
    end

    function controller:SetPreview(enabled)
        if self.preview == enabled then
            return
        end
        self.preview = enabled
        if enabled then
            self:Render()
        else
            self:OnTargetChanged()
        end
    end

    function controller:Initialize()
        if self.initialized then
            return
        end
        self.options:Initialize()
        self:Refresh()
        self.initialized = true
    end

    return controller
end
