local PLUGIN_NAME = "NPC_MONITOR"
local log = include("npc_monitor/log.lua")
local getScheduleName = include("npc_monitor/get_schedule_name.lua")

local function AddHook(eventName, func)
    return hook.Add(eventName, PLUGIN_NAME .. "_" .. eventName, func)
end

local activeNPCS = setmetatable({}, { __mode = "k" })
local lastSchedules = setmetatable({}, { __mode = "k" })
local lastStates = setmetatable({}, { __mode = "k" })

AddHook("InitPostEntity", function()
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) or not ent:IsNPC() then continue end

        activeNPCS[ent] = true
    end
end)

AddHook("OnEntityCreated", function(entity)
    if not IsValid(entity) or not entity:IsNPC() then return end
    activeNPCS[entity] = true
end)

AddHook("Tick", function()
    for npc in pairs(activeNPCS) do
        if not IsValid(npc) then continue end

        local lastSchedule = lastSchedules[npc]
        local currentSchedule = npc:GetCurrentSchedule()
        if lastSchedule ~= currentSchedule then
            hook.Run("OnTranslateSchedule", npc, lastSchedule, currentSchedule)
            lastSchedules[npc] = currentSchedule
        end

        local lastState = lastStates[npc]
        local currentState = npc:GetNPCState()
        if lastState ~= currentState then
            hook.Run("OnStateChange", npc, lastState, currentState)
            lastStates[npc] = currentState
        end
    end
end)

AddHook("OnTranslateSchedule", function(npc, lastSchedule, currentSchedule)
    log.trace(
        npc, "TranslateSchedule: ",
        getScheduleName(lastSchedule), " -> ",
        getScheduleName(currentSchedule)
    )
end)

AddHook("OnStateChange", function(npc, lastState, currentState)
    log.trace(npc, "StateChange: ", lastState, " -> ", currentState)
end)
