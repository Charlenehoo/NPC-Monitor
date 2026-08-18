-- npc_shoot_occluded_cover.lua
local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")

local INTERRUPT_CONDITIONS = {
    COND.ENEMY_DEAD,

    COND.LOW_PRIMARY_AMMO,
    COND.NO_PRIMARY_AMMO,

    COND.LIGHT_DAMAGE,
    COND.HEAVY_DAMAGE,

    COND.HEAR_DANGER,

    COND.WEAPON_BLOCKED_BY_FRIEND,
}

local function shouldInterrupt(npc)
    local enemy = npc:GetEnemy()
    if not IsValid(enemy) or not enemy:Alive() then
        return true
    end

    for _, condID in ipairs(INTERRUPT_CONDITIONS) do
        if npc:HasCondition(condID) then
            return true
        end
    end
    return false
end

addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not IsValid(npc) then return end
    if not currentValue then return end -- 只关心置位
    if conditionID == COND.ENEMY_OCCLUDED or conditionID == COND.WEAPON_SIGHT_OCCLUDED then
        local currentSchedule = npc:GetCurrentSchedule()
        local desiredSchedule = SCHED_SHOOT_ENEMY_COVER
        if currentSchedule == desiredSchedule then return end

        npc._desiredSchedule = desiredSchedule

        if shouldInterrupt(npc) then
            npc._desiredSchedule = nil
            return
        end

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
