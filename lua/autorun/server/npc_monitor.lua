local PLUGIN_NAME = "NPC_MONITOR"
local log = include("npc_monitor/log.lua")
local getScheduleName = include("npc_monitor/get_schedule_name.lua")
local getStateName = include("npc_monitor/get_state_name.lua")

local function AddHook(eventName, func)
    return hook.Add(eventName, PLUGIN_NAME .. "_" .. eventName, func)
end

local activeNPCS = setmetatable({}, { __mode = "k" })
local lastSchedules = setmetatable({}, { __mode = "k" }) -- { npc -> schedule }
local lastStates = setmetatable({}, { __mode = "k" })    -- { npc -> state }

local allLastConditions = {}                             -- { condition -> { npc -> has } }
for name, id in pairs(COND) do
    allLastConditions[name] = setmetatable({}, { __mode = "k" })
end

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
    for name, id in pairs(COND) do
        local lastConditions = allLastConditions[name] -- { npc -> has }
        for npc in pairs(activeNPCS) do
            if not IsValid(npc) then continue end

            local lastCondition = lastConditions[npc]
            local currentCondition = npc:HasCondition(id)
            if lastCondition ~= currentCondition then
                hook.Run("OnCondition", npc, name, id, lastCondition, currentCondition)
                lastConditions[npc] = currentCondition
            end
        end
    end

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

local function shouldLog(npc)
    if not IsValid(npc) then return false end
    if npc:GetClass() == "cdg_info_target" then return false end
    return true
end

AddHook("OnConditionChange", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not shouldLog(npc) then return end
    log.trace(
        npc, "ConditionChange: ",
        conditionName, " (ID:", conditionID, "): ",
        tostring(lastValue), " -> ", tostring(currentValue)
    )
end)

AddHook("OnTranslateSchedule", function(npc, lastSchedule, currentSchedule)
    if not shouldLog(npc) then return end
    log.debug(
        npc, "TranslateSchedule: ",
        getScheduleName(lastSchedule), " -> ",
        getScheduleName(currentSchedule)
    )
end)

AddHook("OnStateChange", function(npc, lastState, currentState)
    if not shouldLog(npc) then return end
    log.info(
        npc, "StateChange: ",
        getStateName(lastState), " -> ",
        getStateName(currentState)
    )
end)
