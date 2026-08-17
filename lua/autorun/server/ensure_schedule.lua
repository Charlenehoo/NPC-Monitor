-- ensure_schedule.lua
local addHook = include("npc_monitor/add_hook.lua")

addHook("OnTranslateSchedule", function(npc, lastSchedule, currentSchedule)
    if not IsValid(npc) then return end
    if not npc._DesiredSchedule or not npc._DesiredCount then return end

    if currentSchedule == npc._DesiredSchedule then return end
    npc:SetSchedule(npc._DesiredSchedule)

    npc._DesiredCount = npc._DesiredCount - 1
    if npc._DesiredCount <= 0 then
        npc._DesiredCount = nil
    end
end, "ENSURE_SCHEDULE")
