-- npc_shoot_occluded_cover.lua
local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")

addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not IsValid(npc) then return end
    if conditionID ~= COND.ENEMY_OCCLUDED then return end
    if not currentValue then return end

    local currentSchedule = npc:GetCurrentSchedule()

    if npc:GetClass() == "npc_combine_s" then
        if currentSchedule == 92 then
            return
        end
    end

    if currentSchedule == SCHED_HIDE_AND_RELOAD or
        currentSchedule == SCHED_RELOAD then
        return
    end

    npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
    npc:ClearCondition(COND.ENEMY_OCCLUDED)
end, "ENEMY_OCCLUDED")
