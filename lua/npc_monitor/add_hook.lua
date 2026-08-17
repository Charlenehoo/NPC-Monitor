local PLUGIN_NAME = "NPC_MONITOR"

local function addHook(eventName, func, appendix)
    appendix = appendix or ""
    return hook.Add(eventName, PLUGIN_NAME .. "_" .. appendix .. "_" .. eventName, func)
end

return addHook
