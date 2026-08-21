-- npc_monitor/schedule/selector.lua
-- 根据 NPC 类型选择合适的 schedule

local function selectSchedule(npc, lastSchedule, currentSchedule)
    local handler = NPCMonitor.ScheduleHandlers[npc:GetClass()]
    if handler then
        return handler(npc, lastSchedule, currentSchedule)
    end
    return nil
end

return selectSchedule
