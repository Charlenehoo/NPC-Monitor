local function idleHandler(npc, lastSchedule, currentSchedule)
    return nil
end

local function alertHandler(npc, lastSchedule, currentSchedule)
    return nil
end

local function combatHandler(npc, lastSchedule, currentSchedule)
    return nil
end

local function handler(npc, lastSchedule, currentSchedule)
    local state = npc:GetNPCState()
    if not state then return nil end

    if state == NPC_STATE_IDLE then
        return idleHandler(npc, lastSchedule, currentSchedule)
    elseif state == NPC_STATE_ALERT then
        return alertHandler(npc, lastSchedule, currentSchedule)
    elseif state == NPC_STATE_COMBAT then
        return combatHandler(npc, lastSchedule, currentSchedule)
    end
end

return handler
