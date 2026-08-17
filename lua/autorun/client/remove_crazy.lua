local PLUGIN_NAME = "NPC_MONITOR"

local function AddHook(eventName, func)
    return hook.Add(eventName, PLUGIN_NAME .. "_" .. eventName, func)
end

AddHook("OnCrazyPhysics", function(ent, physobj)
    if IsValid(ent) then
        SafeRemoveEntity(ent)
    end
end)
