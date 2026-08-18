local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")
local getScheduleName = include("npc_monitor/get_schedule_name.lua")
local getStateName = include("npc_monitor/get_state_name.lua")

local activeNPCS = setmetatable({}, { __mode = "k" })
local lastSchedules = setmetatable({}, { __mode = "k" }) -- { npc -> schedule }
local lastStates = setmetatable({}, { __mode = "k" })    -- { npc -> state }
local lastEnemies = setmetatable({}, { __mode = "k" })   -- { npc -> enemy }

local allLastConditions = {}                             -- { condition -> { npc -> has } }
for name, id in pairs(COND) do
    allLastConditions[name] = setmetatable({}, { __mode = "k" })
end

local function enhanceNPC(npc)
    npc:SetMaxLookDistance(6000)
end

local function initNpc(npc)
    activeNPCS[npc] = true
    for name, id in pairs(COND) do
        allLastConditions[name][npc] = npc:HasCondition(id)
    end
    lastSchedules[npc] = npc:GetCurrentSchedule()
    lastStates[npc] = npc:GetNPCState()
    lastEnemies[npc] = npc:GetEnemy()

    enhanceNPC(npc)
end

addHook("InitPostEntity", function()
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) or not ent:IsNPC() then continue end
        initNpc(ent)
    end
end)

addHook("OnEntityCreated", function(entity)
    if not IsValid(entity) or not entity:IsNPC() then return end
    initNpc(entity)
end)

addHook("Tick", function()
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

        local lastEnemy    = lastEnemies[npc]
        local currentEnemy = npc:GetEnemy()
        if lastEnemy ~= currentEnemy then
            hook.Run("OnEnemyChange", npc, lastEnemy, currentEnemy)
            lastEnemies[npc] = currentEnemy
        end
    end
end)

local function shouldLog(npc)
    if not IsValid(npc) then return false end
    if npc:GetClass() == "cdg_info_target" then return false end
    return true
end

addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not shouldLog(npc) then return end

    local status = currentValue and "SET" or "CLEAR"
    log.trace(
        npc, "ConditionChange: ",
        conditionName,
        " [", status, "]"
    )
end, "LOG")

addHook("OnTranslateSchedule", function(npc, last, current)
    if shouldLog(npc) then
        log.debug(npc, "TranslateSchedule: ", getScheduleName(last, npc), " -> ", getScheduleName(current, npc))
    end
end, "LOG")

addHook("OnStateChange", function(npc, last, current)
    if shouldLog(npc) then
        log.debug(npc, "StateChange: ", getStateName(last), " -> ", getStateName(current))
    end
end, "LOG")

addHook("OnEnemyChange", function(npc, last, current)
    if shouldLog(npc) then
        last = last or "No Enemy"
        current = current or "No Enemy"
        log.debug(npc, "EnemyChange: ", tostring(last), " -> ", tostring(current))
    end
end, "LOG")
