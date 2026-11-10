local _, RangeFinder = ...

local EditMode = {}
RangeFinder.EditMode = EditMode

function EditMode.New(controller)
    local editMode = {}

    function editMode:Enter()
        controller:SetPreview(true)
    end

    function editMode:Exit()
        controller:SetPreview(false)
    end

    return editMode
end
