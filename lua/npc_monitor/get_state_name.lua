-- ./lua/npc_monitor/get_state_name.lua

local Enum = include("enum.lua")
local NPC_STATE_ID_TO_NAME = Enum.NPC_STATE_ID_TO_NAME

local function getStateName(id)
    if not id then
        return "NPC_STATE_UNKNOWN"
    else
        return NPC_STATE_ID_TO_NAME[id] or ("NPC_STATE_UNKNOWN_" .. id)
    end
end

return getStateName
