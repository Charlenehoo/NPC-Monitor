-- npc_shoot_occluded_cover.lua
local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")

addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not IsValid(npc) then return end

    if conditionID ~= COND.ENEMY_OCCLUDED then return end

    if not currentValue then return end

    npc._DesiredSchedule = SCHED_SHOOT_ENEMY_COVER
    npc._DesiredCount = 2
    npc._DesiredExpired = CurTime() + 3

    npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
end, "ENEMY_OCCLUDED")
