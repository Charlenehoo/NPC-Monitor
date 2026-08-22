local CONSTANTS = include("npc_monitor/config/constants.lua")
local Enum      = include("npc_monitor/config/enum.lua")
local log       = include("npc_monitor/logging/log.lua")
local helpers   = include("npc_monitor/helpers.lua")

local function idleHandler(npc, lastSchedule, currentSchedule)
    local candidates = {}
    NPCMonitor.ForEachActiveDummy(function(dummy)
        if IsValid(dummy) and dummy:IsPotentialExecutioner(npc) then
            table.insert(candidates, dummy)
        end
    end)
    if #candidates > 0 then
        local dummyOfChoice = candidates[math.random(#candidates)]
        npc:SetTarget(dummyOfChoice)
        return SCHED_TARGET_CHASE
    end

    return nil
end

local function alertHandler(npc, lastSchedule, currentSchedule)
    if currentSchedule == SCHED_ALERT_STAND then
        local candidates = {}
        NPCMonitor.ForEachActiveDummy(function(dummy)
            if IsValid(dummy) and dummy:IsPotentialExecutioner(npc) then
                table.insert(candidates, dummy)
            end
        end)
        if #candidates > 0 then
            local dummyOfChoice = candidates[math.random(#candidates)]
            npc:SetTarget(dummyOfChoice)
            return SCHED_TARGET_CHASE
        end
    end

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

NPCMonitor.RegisterScheduleHandler("npc_combine_s", handler)
