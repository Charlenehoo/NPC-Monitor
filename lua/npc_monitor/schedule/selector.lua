-- npc_monitor/schedule/selector.lua
-- 根据 NPC 类型选择合适的 schedule

local CONSTANTS = include("npc_monitor/config/constants.lua")
local Enum      = include("npc_monitor/config/enum.lua")
local log       = include("npc_monitor/logging/log.lua")
local helpers   = include("npc_monitor/helpers.lua")

local function selectSchedule(npc, lastSchedule, currentSchedule)
    if lastSchedule == SCHED_FAIL or currentSchedule == SCHED_FAIL then return nil end

    local enemy = npc:GetEnemy()
    if IsValid(enemy) and enemy:GetClass() == CONSTANTS.RAGADOLL_DUMMY_CLASS then return nil end

    local handler = NPCMonitor.ScheduleHandlers[npc:GetClass()]
    if handler then
        return handler(npc, lastSchedule, currentSchedule)
    end
    return nil
end

return selectSchedule
