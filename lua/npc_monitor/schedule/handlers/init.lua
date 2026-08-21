-- npc_monitor/schedule/handlers/init.lua
-- 调度处理器注册中心：加载并注册所有 NPC 类型的 handler

-- 初始化注册表（挂到全局 NPCMonitor 上）
NPCMonitor.ScheduleHandlers = NPCMonitor.ScheduleHandlers or {}

-- 逐个 include 具体 handler，这些文件内部会调用 RegisterScheduleHandler 注册自己
include("npc_monitor/schedule/handlers/npc_combine_s.lua")

-- 如果未来新增其他 NPC 类型，在这里继续 include
-- include("npc_monitor/schedule/handlers/npc_metropolice_s.lua")
