local PLUGIN_NAME = "NPC_MONITOR"

local function AddHook(eventName, func)
    return hook.Add(eventName, PLUGIN_NAME .. "_" .. eventName, func)
end

local function RunHook(eventName, ...)
    return hook.Run(eventName, ...) -- 注意：使用原始事件名
end

-- 使用弱表存储 Schedule 和 State，避免污染实体
local activeNPCS = setmetatable({}, { __mode = "k" })
local lastSchedules = setmetatable({}, { __mode = "k" })
local lastStates = setmetatable({}, { __mode = "k" })

local function GetLastSchedule(self)
    return lastSchedules[self] or SCHED_NONE
end

local function SetLastSchedule(self, schedule)
    lastSchedules[self] = schedule
end

AddHook("OnEntityCreated", function(entity)
    if not IsValid(entity) or not entity:IsNPC() then return end

    -- 提供 Schedule 方法
    entity.GetLastSchedule = GetLastSchedule
    entity.SetLastSchedule = SetLastSchedule

    activeNPCS[entity] = true
end)

AddHook("Tick", function()
    for npc in pairs(activeNPCS) do
        if not IsValid(npc) then
            activeNPCS[npc] = nil
            continue
        end

        -- Schedule 变化检测
        local lastSchedule = npc:GetLastSchedule()
        local currentSchedule = npc:GetCurrentSchedule()
        if lastSchedule ~= currentSchedule then
            RunHook("OnTranslateSchedule", npc, lastSchedule, currentSchedule)
            npc:SetLastSchedule(currentSchedule)
        end

        -- State 变化检测
        local lastState = lastStates[npc]
        local currentState = npc:GetNPCState()
        if lastState ~= currentState then
            RunHook("OnStateChange", npc, lastState, currentState)
            lastStates[npc] = currentState
        end
    end
end)
