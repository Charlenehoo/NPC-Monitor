-- npc_shoot_occluded_cover.lua
local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")
local CONSTANTS = include("npc_monitor/constants.lua")

-- 查找最近玩家（用于没有 owner 的声音）
local function findNearestPlayer(pos, maxDist)
    local nearestPlayer = nil
    local nearestDistSqr = maxDist and maxDist * maxDist or math.huge

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        local distSqr = ply:GetPos():DistToSqr(pos)
        if distSqr < nearestDistSqr then
            nearestDistSqr = distSqr
            nearestPlayer = ply
        end
    end
    return nearestPlayer
end

-- 原因 ID 表（用于引用计数）
local CAUSES = {
    OCCLUDED = {
        TRIGGER = {
            COND.ENEMY_OCCLUDED,
            COND.WEAPON_SIGHT_OCCLUDED,
        },
        INTERRUPT = {
            COND.ENEMY_WENT_NULL,
            COND.ENEMY_DEAD,
            COND.LOST_ENEMY,
            COND.ENEMY_TOO_FAR,
            COND.LOW_PRIMARY_AMMO,
            COND.NO_PRIMARY_AMMO,
            COND.LIGHT_DAMAGE,
            COND.HEAVY_DAMAGE,
            COND.WEAPON_BLOCKED_BY_FRIEND,

            COND.HEAR_DANGER,
        },
        DURATION = 6,
        -- OCCLUDED 无需 ON_ADD，直接添加
    },
    HEAR = {
        TRIGGER = {
            COND.HEAR_PLAYER,
            COND.HEAR_BULLET_IMPACT,
        },
        INTERRUPT = {
            COND.ENEMY_WENT_NULL,
            COND.ENEMY_DEAD,
            COND.LOST_ENEMY,
            COND.LOW_PRIMARY_AMMO,
            COND.NO_PRIMARY_AMMO,
            COND.LIGHT_DAMAGE,
            COND.HEAVY_DAMAGE,
            COND.WEAPON_BLOCKED_BY_FRIEND,
        },
        DURATION = 3,
        ON_ADD = function(npc, reason)
            local hint = npc:GetBestSoundHint()
            if not hint then return false end

            local hintPos = hint.origin
            local owner = hint.owner

            if not hintPos then
                if IsValid(owner) then
                    hintPos = owner:GetPos()
                else
                    return false
                end
            end

            -- 确定敌人：优先有效 owner，否则在范围内找最近玩家
            local enemy = nil
            if IsValid(owner) and owner:IsPlayer() then
                enemy = owner
            else
                enemy = findNearestPlayer(hintPos, 1000)
            end
            if not IsValid(enemy) then return false end

            npc:SetEnemy(enemy)
            npc:UpdateEnemyMemory(enemy, hintPos)
            return true
        end,
    },
}

-- 构建条件 ID -> 原因 ID 的反向映射（自动生成）
local CONDITION_TO_REASON = {}
for reason, data in pairs(CAUSES) do
    for _, condID in ipairs(data.TRIGGER) do
        CONDITION_TO_REASON[condID] = reason
    end
end

-- 通用中断检查：敌人无效或死亡
local function checkCommonInterrupt(npc)
    local enemy = npc:GetEnemy()
    if not IsValid(enemy) or not enemy:Alive() then
        return true
    end
    return false
end

-- 判断指定原因是否应该被移除（即该原因已不再有效）
local function shouldRemoveCause(npc, reason)
    -- 通用敌人有效性检查
    if checkCommonInterrupt(npc) then
        return true
    end

    -- 检查该原因对应的中断条件
    local causeData = CAUSES[reason]
    local interruptConds = causeData.INTERRUPT or {}
    for _, condID in ipairs(interruptConds) do
        if npc:HasCondition(condID) then
            return true
        end
    end

    -- 统一的时间限制检查
    local duration = causeData.DURATION or CONSTANTS.SHOOT_COVER_DURATION
    local start = npc._desiredScheduleCauseStart and npc._desiredScheduleCauseStart[reason]
    if start and duration and duration > 0 and (CurTime() - start) > duration then
        return true
    end

    return false
end

-- 添加一个原因（引用计数加1）
local function addCause(npc, reason)
    -- 初始化字段
    npc._desiredScheduleCauses = npc._desiredScheduleCauses or {}
    npc._desiredScheduleCauseStart = npc._desiredScheduleCauseStart or {}

    -- 幂等：如果该原因已存在，则不做任何操作
    if npc._desiredScheduleCauses[reason] then
        return
    end

    -- 记录该原因
    npc._desiredScheduleCauses[reason] = true
    npc._desiredScheduleCauseStart[reason] = CurTime()

    -- 设置期望 Schedule
    npc._desiredSchedule = SCHED_SHOOT_ENEMY_COVER

    -- 立即尝试切换到目标 Schedule
    if npc:GetCurrentSchedule() ~= SCHED_SHOOT_ENEMY_COVER then
        npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
    end
end

-- 移除一个原因（引用计数减1）
local function removeCause(npc, reason)
    if not npc._desiredScheduleCauses then return end

    if npc._desiredScheduleCauses[reason] then
        npc._desiredScheduleCauses[reason] = nil
        npc._desiredScheduleCauseStart[reason] = nil

        -- 如果没有原因了，清除期望 Schedule
        if table.Count(npc._desiredScheduleCauses) == 0 then
            npc._desiredSchedule = nil
        end
    end
end

-- 统一的 OnCondition 钩子，仅在上升沿添加原因
addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not IsValid(npc) then return end

    -- 只处理上升沿（条件由假变真）
    if not (currentValue and not lastValue) then return end

    -- 从反向映射表中查找该条件属于哪个原因
    local reason = CONDITION_TO_REASON[conditionID]
    if not reason then return end

    -- 如果原因已存在，不做任何处理（包括不执行 ON_ADD）
    if npc._desiredScheduleCauses and npc._desiredScheduleCauses[reason] then
        return
    end

    -- 执行原因特定的前置操作（闭包）
    local causeData = CAUSES[reason]
    if causeData.ON_ADD then
        local canAdd = causeData.ON_ADD(npc, reason)
        if canAdd == false then
            return -- 前置操作失败，不添加该原因
        end
    end

    -- 添加原因并设置期望 Schedule
    addCause(npc, reason)
end, "SHOOT_COVER_CAUSES")

-- 当 NPC 离开目标 Schedule 时，检查并清理失效原因，决定是否重新强制
addHook("OnTranslateSchedule", function(npc, lastSchedule, currentSchedule)
    if not IsValid(npc) then return end

    -- 只关心我们设置的目标 Schedule
    if npc._desiredSchedule ~= SCHED_SHOOT_ENEMY_COVER then return end
    if lastSchedule ~= SCHED_SHOOT_ENEMY_COVER or currentSchedule == SCHED_SHOOT_ENEMY_COVER then return end

    -- 检查所有活跃原因，移除已失效的
    for reason in pairs(npc._desiredScheduleCauses or {}) do
        if shouldRemoveCause(npc, reason) then
            removeCause(npc, reason)
        end
    end

    -- 如果移除后还有原因，重新强制目标 Schedule
    if npc._desiredSchedule == SCHED_SHOOT_ENEMY_COVER then
        npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
    end
end, "SHOOT_COVER_MAINTAIN")
