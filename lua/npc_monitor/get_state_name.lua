-- ./lua/npc_monitor/get_state_name.lua

local NPC_STATE_ENUM = {
    NPC_STATE_INVALID  = -1, -- Invalid state
    NPC_STATE_NONE     = 0,  -- NPC default state
    NPC_STATE_IDLE     = 1,  -- NPC is idle
    NPC_STATE_ALERT    = 2,  -- NPC is alert and searching for enemies
    NPC_STATE_COMBAT   = 3,  -- NPC is in combat
    NPC_STATE_SCRIPT   = 4,  -- NPC is executing scripted sequence
    NPC_STATE_PLAYDEAD = 5,  -- NPC is playing dead (used for expressions)
    NPC_STATE_PRONE    = 6,  -- NPC is prone to death
    NPC_STATE_DEAD     = 7,  -- NPC is dead
}

local NPC_STATE_ID_TO_NAME = {}
for name, id in pairs(NPC_STATE_ENUM) do
    NPC_STATE_ID_TO_NAME[id] = name
end

local function getStateName(id)
    if not id then
        return "NPC_STATE_UNKNOWN"
    else
        return NPC_STATE_ID_TO_NAME[id] or ("NPC_STATE_UNKNOWN_" .. id)
    end
end

return getStateName
