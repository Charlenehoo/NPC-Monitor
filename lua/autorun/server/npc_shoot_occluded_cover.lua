-- npc_shoot_occluded_cover.lua
local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")
local Enum = include("npc_monitor/enum.lua")
local SCHED_COMBINE_COMBAT_FACE = Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_COMBAT_FACE

addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not IsValid(npc) then return end
    if conditionID ~= COND.ENEMY_OCCLUDED then return end
    if not currentValue then return end

    local currentSchedule = npc:GetCurrentSchedule()

    if npc:GetClass() == "npc_combine_s" then
        if currentSchedule == SCHED_COMBINE_COMBAT_FACE then
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
