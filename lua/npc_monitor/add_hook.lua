local PLUGIN_NAME = "NPC_MONITOR"

local function addHook(eventName, func)
    return hook.Add(eventName, PLUGIN_NAME .. "_" .. eventName, func)
end

return addHook
