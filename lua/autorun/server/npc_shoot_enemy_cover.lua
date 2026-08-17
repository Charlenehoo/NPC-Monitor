local CONSTANTS = include("npc_shoot_enemy_cover/constants.lua")
local PLUGIN_NAME = CONSTANTS.PLUGIN_NAME
local SOUND_PROPAGATION = CONSTANTS.SOUND_PROPAGATION

local function soundLevelToSourceUnits(soundLevel)
    if not soundLevel or soundLevel <= SOUND_PROPAGATION.thresholdLevel then
        return 0
    end

    local distance = SOUND_PROPAGATION.referenceDistance *
        10 ^ ((soundLevel - SOUND_PROPAGATION.thresholdLevel) / 20)

    return math.Clamp(distance, 0, SOUND_PROPAGATION.maxDistance)
end

local NET_WORK_STRINGS = CONSTANTS.NET_WORK_STRINGS
for _, s in pairs(NET_WORK_STRINGS) do
    util.AddNetworkString(s)
end

net.Receive(NET_WORK_STRINGS.PLAYER_EMIT_SOUND, function(len, ply)
    local time = net.ReadFloat()
    local level = net.ReadFloat()
    local pos = net.ReadVector()
    if time and level and pos then
        local radius = soundLevelToSourceUnits(level)
        print(string.format("Emit Hint Client Side, Radius: %f", radius))
        sound.EmitHint(SOUND_PLAYER, pos, radius, time, ply)
    end
end)

hook.Add("EntityEmitSound", PLUGIN_NAME .. "EntityEmitSound", function(data)
    local ent = data.Entity
    if not ent:IsValid() then return end

    local time = data.SoundTime
    local level = data.SoundLevel
    local pos = data.Pos or ent:GetPos()
    if time and level and pos then
        local radius = soundLevelToSourceUnits(level)
        sound.EmitHint(SOUND_PLAYER, pos, radius, time, ent)

        local name = data.SoundName
        print(string.format("Emit Hint Server Side, Name: %s; Radius: %f", tostring(name), radius))
    end
end)

local NPC_CONFIDENT_TIME = CONSTANTS.NPC_CONFIDENT_TIME
local NOT_SHOOT_CONDITIONS = CONSTANTS.NOT_SHOOT_CONDITIONS
local SHOOT_AT_ENEMY_CONDITIONS = CONSTANTS.SHOOT_AT_ENEMY_CONDITIONS
local NOT_SHOOT_AT_ENEMY_CONDITIONS = CONSTANTS.NOT_SHOOT_AT_ENEMY_CONDITIONS
local SHOOT_AT_HINT_CONDITIONS = CONSTANTS.SHOOT_AT_HINT_CONDITIONS
local STRING_TO_NUMBER = CONSTANTS.STRING_TO_NUMBER

local activeNPCS = {}

local function ensureShootEnemyCoverEvery(seconds, npc)
    local key = PLUGIN_NAME .. "lastSetSchedule"
    npc[key] = npc[key] or 0
    if CurTime() - npc[key] > seconds then
        npc[key] = CurTime()
        npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
    end
end

hook.Add("OnEntityCreated", PLUGIN_NAME .. "OnEntityCreated", function(entity)
    if not IsValid(entity) then return end
    if not entity:IsNPC() then return end
    activeNPCS[entity] = true
end)

hook.Add("EntityRemoved", PLUGIN_NAME .. "EntityRemoved", function(ent, fullUpdate)
    activeNPCS[ent] = nil
end)

hook.Add("Tick", PLUGIN_NAME .. "Tick", function()
    for npc, _ in pairs(activeNPCS) do
        if not npc:IsValid() then
            activeNPCS[npc] = nil
            continue
        end

        local notShoot = false
        for _, condition in ipairs(NOT_SHOOT_CONDITIONS) do
            if npc:HasCondition(condition) then
                notShoot = true
                break
            end
        end
        if notShoot then continue end

        local shouldShootAtEnemy = false
        for _, condition in ipairs(SHOOT_AT_ENEMY_CONDITIONS) do
            if npc:HasCondition(condition) then
                shouldShootAtEnemy = true
                break
            end
        end
        for _, condition in ipairs(NOT_SHOOT_AT_ENEMY_CONDITIONS) do
            if npc:HasCondition(condition) then
                shouldShootAtEnemy = false
                break
            end
        end

        local shouldShootAtHint = false
        local hintType
        for type, condition in pairs(SHOOT_AT_HINT_CONDITIONS) do
            if npc:HasCondition(condition) then
                shouldShootAtHint = true
                hintType = type
                break
            end
        end

        if shouldShootAtEnemy then
            if npc:GetEnemy() and npc:GetEnemy():Alive() and npc:GetEnemyLastTimeSeen() + NPC_CONFIDENT_TIME > CurTime() then
                ensureShootEnemyCoverEvery(1.5, npc)
            end
        elseif shouldShootAtHint then
            local hint = npc:GetBestSoundHint(STRING_TO_NUMBER[hintType])
            if not hint then continue end

            local owner = hint.owner
            if owner:IsValid() then
                npc:FoundEnemySound()
                npc:SetEnemy(owner)
                npc:UpdateEnemyMemory(owner, owner:GetPos())
                ensureShootEnemyCoverEvery(1.5, npc)
            end
        end
    end
end)
