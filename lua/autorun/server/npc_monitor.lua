local PLUGIN_NAME = "NPC_MONITOR"

local function AddHook(eventName, func)
    return hook.Add(eventName, PLUGIN_NAME .. "_" .. eventName, func)
end

local activeNPCS = setmetatable({}, { __mode = "k" })
local lastSchedules = setmetatable({}, { __mode = "k" })
local lastStates = setmetatable({}, { __mode = "k" })

AddHook("OnEntityCreated", function(entity)
    if not IsValid(entity) or not entity:IsNPC() then return end
    activeNPCS[entity] = true
end)

AddHook("Tick", function()
    for npc in pairs(activeNPCS) do
        if not IsValid(npc) then
            continue
        end

        -- 检测 Schedule 变化（直接查表，首次为 nil 会触发一次）
        local lastSchedule = lastSchedules[npc]
        local currentSchedule = npc:GetCurrentSchedule()
        if lastSchedule ~= currentSchedule then
            hook.Run("OnTranslateSchedule", npc, lastSchedule, currentSchedule)
            lastSchedules[npc] = currentSchedule
        end

        -- 检测 NPC 状态变化（直接查表，首次为 nil 会触发一次）
        local lastState = lastStates[npc]
        local currentState = npc:GetNPCState()
        if lastState ~= currentState then
            hook.Run("OnStateChange", npc, lastState, currentState)
            lastStates[npc] = currentState
        end
    end
end)
