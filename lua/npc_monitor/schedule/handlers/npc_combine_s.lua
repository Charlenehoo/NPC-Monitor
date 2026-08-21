local CONSTANTS = include("npc_monitor/config/constants.lua")
local Enum      = include("npc_monitor/config/enum.lua")
local log       = include("npc_monitor/logging/log.lua")
local helpers   = include("npc_monitor/helpers.lua")

local function idleHandler(npc, lastSchedule, currentSchedule)
    if lastSchedule == SCHED_ALERT_STAND then
        local dummyOfChoice

        NPCMonitor.ForEachActiveDummy(function(dummy)
            if IsValid(dummy) then
                dummyOfChoice = dummy
                return true
            end
        end)

        if dummyOfChoice then
            npc:SetTarget(dummyOfChoice)
            return SCHED_TARGET_CHASE
        end
    end

    return nil
end

local function alertHandler(npc, lastSchedule, currentSchedule)
    if lastSchedule == SCHED_ALERT_STAND then
        local dummyOfChoice

        NPCMonitor.ForEachActiveDummy(function(dummy)
            if IsValid(dummy) then
                dummyOfChoice = dummy
                return true
            end
        end)

        if dummyOfChoice then
            npc:SetTarget(dummyOfChoice)
            return SCHED_TARGET_CHASE
        end
    end

    return nil
end

local function combatHandler(npc, lastSchedule, currentSchedule)
    if currentSchedule ~= SCHED_RELOAD and
        currentSchedule ~= Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_HIDE_AND_RELOAD then
        if (lastSchedule == SCHED_RANGE_ATTACK1 or
                lastSchedule == Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_ASSAULT or
                lastSchedule == Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_ESTABLISH_LINE_OF_FIRE or
                lastSchedule == Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_RANGE_ATTACK1
            )
            and
            npc:HasCondition(COND.ENEMY_OCCLUDED) then
            return SCHED_SHOOT_ENEMY_COVER
        end

        if lastSchedule == SCHED_SHOOT_ENEMY_COVER and
            not npc:HasCondition(COND.LOST_ENEMY) then
            return SCHED_SHOOT_ENEMY_COVER
        end
    end

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
