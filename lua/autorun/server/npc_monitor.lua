local CONSTANTS = include("npc_monitor/constants.lua")
local log = include("npc_monitor/log.lua")
local helpers = include("npc_monitor/helpers.lua")
local addUniqueHook = helpers.addUniqueHook
local getScheduleName = helpers.getScheduleName
local getStateName = helpers.getStateName

local activeNPCS = setmetatable({}, { __mode = "k" })
local activeDummies = setmetatable({}, { __mode = "k" })
local lastSchedules = setmetatable({}, { __mode = "k" }) -- { npc -> schedule }
local lastStates = setmetatable({}, { __mode = "k" })    -- { npc -> state }
local lastEnemies = setmetatable({}, { __mode = "k" })   -- { npc -> enemy }

local allLastConditions = {}                             -- { condition -> { npc -> has } }
for name, id in pairs(COND) do
    allLastConditions[name] = setmetatable({}, { __mode = "k" })
end

local function enhanceNPC(npc)
    npc:SetMaxLookDistance(CONSTANTS.NPC_MAX_LOOK_DISTANCE)
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

addUniqueHook("InitPostEntity", function()
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) or not ent:IsNPC() then continue end
        if ent:GetClass() == CONSTANTS.RAGADOLL_DUMMY_CLASS then
            activeDummies[ent] = true
        else
            initNpc(ent)
        end
    end
end)

addUniqueHook("CreateEntityRagdoll", function(owner, ragdoll)
    if not IsValid(owner) or not IsValid(ragdoll) then return end
    local dummy = ents.Create(CONSTANTS.RAGADOLL_DUMMY_CLASS)
    dummy:Spawn()
    dummy:Init(owner, ragdoll)
end)

addUniqueHook("OnEntityCreated", function(entity)
    if not IsValid(entity) or not entity:IsNPC() then return end
    if entity:GetClass() == CONSTANTS.RAGADOLL_DUMMY_CLASS then
        activeDummies[entity] = true
    else
        initNpc(entity)
    end
end)

addUniqueHook("EntityRemoved", function(ent, _)
    activeNPCS[ent] = nil
    activeDummies[ent] = nil
end)

addUniqueHook("Tick", function()
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
            hook.Run("TranslateSchedule", npc, lastSchedule, currentSchedule)
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

addUniqueHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not shouldLog(npc) then return end

    local status = currentValue and "SET" or "CLEAR"
    log.trace(
        npc, "ConditionChange: ",
        conditionName,
        " [", status, "]"
    )
end)

addUniqueHook("TranslateSchedule", function(npc, last, current)
    if shouldLog(npc) then
        log.debug(npc, "TranslateSchedule: ", getScheduleName(last, npc), " -> ", getScheduleName(current, npc))
    end
end)

addUniqueHook("OnStateChange", function(npc, last, current)
    if shouldLog(npc) then
        log.debug(npc, "StateChange: ", getStateName(last), " -> ", getStateName(current))
    end
end)

addUniqueHook("OnEnemyChange", function(npc, last, current)
    if shouldLog(npc) then
        last = last or "No Enemy"
        current = current or "No Enemy"
        log.debug(npc, "EnemyChange: ", tostring(last), " -> ", tostring(current))
    end
end)

NPCMonitor = NPCMonitor or {}

function NPCMonitor.ForEachActiveNPC(callback)
    for npc in pairs(activeNPCS) do
        callback(npc)
    end
end

function NPCMonitor.ForEachActiveDummy(callback)
    for dummy in pairs(activeDummies) do
        callback(dummy)
    end
end
