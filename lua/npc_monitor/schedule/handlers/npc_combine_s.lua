local CONSTANTS = include("npc_monitor/config/constants.lua")
local Enum      = include("npc_monitor/config/enum.lua")
local log       = include("npc_monitor/logging/log.lua")
local helpers   = include("npc_monitor/helpers.lua")

local function idleHandler(npc, lastSchedule, currentSchedule)
    return nil
end

local function alertHandler(npc, lastSchedule, currentSchedule)
    if currentSchedule == SCHED_ALERT_STAND or
        currentSchedule == SCHED_ALERT_FACE_BESTSOUND or
        currentSchedule == Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_PATROL then
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

local SHOOT_COVER_MAX_DURATION = 3.0 -- 可移到 constants.lua 中

local function combatHandler(npc, lastSchedule, currentSchedule)
    if currentSchedule == SCHED_RELOAD or
        currentSchedule == SCHED_HIDE_AND_RELOAD or
        currentSchedule == Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_HIDE_AND_RELOAD then
        return nil
    end

    -- 保持掩体压制，但限制最大持续时间
    if lastSchedule == SCHED_SHOOT_ENEMY_COVER then
        local startTime = npc._shootCoverStartTime
        if startTime and (CurTime() - startTime) < SHOOT_COVER_MAX_DURATION then
            return SCHED_SHOOT_ENEMY_COVER
        else
            npc._shootCoverStartTime = nil -- 超时，清理状态
            return nil
        end
    end

    -- 触发进入掩体压制
    if npc:HasCondition(COND.ENEMY_OCCLUDED) then
        if lastSchedule ~= SCHED_SHOOT_ENEMY_COVER then
            npc._shootCoverStartTime = CurTime() -- 直接挂载在 NPC 实体上
        end
        return SCHED_SHOOT_ENEMY_COVER
    end

    -- 其他情况（离开掩体压制且无遮挡）清理状态
    npc._shootCoverStartTime = nil
    return nil
end

local function handler(npc, lastSchedule, currentSchedule)
    if lastSchedule == SCHED_FAIL or currentSchedule == SCHED_FAIL then return nil end

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
