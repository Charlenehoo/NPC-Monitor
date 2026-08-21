-- npc_monitor/schedule/selector.lua
-- 根据 NPC 类型选择合适的 schedule

local npc_combine_s = include("npc_monitor/schedule/handlers/npc_combine_s.lua")

local function selectSchedule(npc, lastSchedule, currentSchedule)
    local npcClass = npc:GetClass()
    if not npcClass then return nil end

    if npcClass == "npc_combine_s" then
        return npc_combine_s(npc, lastSchedule, currentSchedule)
    end
    return nil
end

return selectSchedule
