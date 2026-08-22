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
    local enemy = npc:GetEnemy()
    if not IsValid(enemy) then return nil end

    -- 如果已经能近战攻击，让 NPC 自己处理（或直接返回 SCHED_MELEE_ATTACK1）
    if npc:HasCondition(COND.CAN_MELEE_ATTACK1) then
        return nil -- 或 return SCHED_MELEE_ATTACK1
    end

    -- 如果敌人还活着且不在近战范围，强制跑向敌人
    if not npc:HasCondition(COND.ENEMY_DEAD) then
        -- 关键：设置 SavePosition 为敌人当前位置
        npc:SetSaveValue("m_vecLastPosition", enemy:GetPos())
        return SCHED_FORCED_GO_RUN
    end

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
