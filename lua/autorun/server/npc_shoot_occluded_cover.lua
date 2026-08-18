-- npc_shoot_occluded_cover.lua
local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")

local CONSTANTS = include("npc_monitor/constants.lua")

local INTERRUPT_CONDITIONS = {
    COND.ENEMY_WENT_NULL,
    COND.ENEMY_DEAD,
    COND.LOST_ENEMY,
    COND.ENEMY_TOO_FAR,

    COND.LOW_PRIMARY_AMMO,
    COND.NO_PRIMARY_AMMO,

    COND.LIGHT_DAMAGE,
    COND.HEAVY_DAMAGE,

    COND.HEAR_DANGER,

    COND.WEAPON_BLOCKED_BY_FRIEND,
}

local function shouldInterrupt(npc)
    for _, condID in ipairs(INTERRUPT_CONDITIONS) do
        if npc:HasCondition(condID) then
            return true
        end
    end

    local enemy = npc:GetEnemy()
    if not IsValid(enemy) or not enemy:Alive() then
        return true
    end

    local lastSeen = npc:GetEnemyLastTimeSeen()
    return CurTime() - lastSeen > CONSTANTS.SHOOT_COVER_DURATION
end

addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not IsValid(npc) then return end
    if not currentValue then return end -- 只关心置位
    if conditionID == COND.ENEMY_OCCLUDED or conditionID == COND.WEAPON_SIGHT_OCCLUDED then
        local currentSchedule = npc:GetCurrentSchedule()
        local desiredSchedule = SCHED_SHOOT_ENEMY_COVER
        if currentSchedule == desiredSchedule then return end

        if shouldInterrupt(npc) then
            npc._desiredSchedule = nil
            return
        end

        npc._desiredSchedule = desiredSchedule
        npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
    end
end, "ENEMY_OCCLUDED")

addHook("OnTranslateSchedule", function(npc, lastSchedule, currentSchedule)
    if not IsValid(npc) then return end

    local desiredSchedule = npc._desiredSchedule
    if lastSchedule ~= desiredSchedule then return end
    if currentSchedule == desiredSchedule then return end

    if shouldInterrupt(npc) then
        npc._desiredSchedule = nil
        return
    end

    npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
end, "ENEMY_OCCLUDED")

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

addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not IsValid(npc) then return end
    if not currentValue then return end

    if conditionID ~= COND.HEAR_PLAYER and conditionID ~= COND.HEAR_BULLET_IMPACT then return end

    local hint = npc:GetBestSoundHint()
    if not hint then return end

    local hintPos = hint.origin
    local owner = hint.owner

    -- 获取声音来源位置
    if not hintPos then
        if IsValid(owner) then
            hintPos = owner:GetPos()
        else
            return
        end
    end

    -- 确定敌人：优先有效 owner，否则在 1000 单位内找最近玩家
    local enemy = nil
    if IsValid(owner) and owner:IsPlayer() then
        enemy = owner
    else
        enemy = findNearestPlayer(hintPos, 1000)
    end
    if not IsValid(enemy) then return end

    -- 如果当前敌人已经是这个玩家，且已经在射击计划中，避免重复设置
    local currentEnemy = npc:GetEnemy()
    local currentSchedule = npc:GetCurrentSchedule()
    if IsValid(currentEnemy) and currentEnemy == enemy and currentSchedule == SCHED_SHOOT_ENEMY_COVER then
        return
    end

    -- 设置敌人并更新记忆
    npc:SetEnemy(enemy)
    npc:UpdateEnemyMemory(enemy, hintPos)

    npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
end, "HEAR_PLAYER")
