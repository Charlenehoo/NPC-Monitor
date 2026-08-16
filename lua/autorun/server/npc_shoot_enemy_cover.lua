local CONSTANTS = include("npc_shoot_enemy_cover/constants.lua")
local PLUGIN_NAME = CONSTANTS.PLUGIN_NAME

local NET_WORK_STRINGS = CONSTANTS.NET_WORK_STRINGS
for _, s in pairs(NET_WORK_STRINGS) do
    util.AddNetworkString(s)
end

-- local PLAYER_EMIT_SOUND_TIME
-- local PLAYER_EMIT_SOUND_LEVEL
-- local PLAYER_EMIT_SOUND_POS

local SOUND_PROPAGATION = CONSTANTS.SOUND_PROPAGATION

-- 将 SoundLevel(dB) 转为 Source units
local function SoundLevelToSourceUnits(soundLevel)
    if not soundLevel or soundLevel <= SOUND_PROPAGATION.thresholdLevel then
        return 0
    end

    local distance = SOUND_PROPAGATION.referenceDistance *
        10 ^ ((soundLevel - SOUND_PROPAGATION.thresholdLevel) / 20)

    return math.Clamp(distance, 0, SOUND_PROPAGATION.maxDistance)
end

local function tryEmitSound(ply)
    local time = PLAYER_EMIT_SOUND_TIME[ply]
    local level = PLAYER_EMIT_SOUND_LEVEL[ply]
    local pos = PLAYER_EMIT_SOUND_POS[ply]
    if time and level and pos then
        local radius = SoundLevelToSourceUnits(soundLevel)
        sound.EmitHint(SOUND_PLAYER, pos, radius, time, ply)
        PLAYER_EMIT_SOUND_TIME[ply] = nil
        PLAYER_EMIT_SOUND_LEVEL[ply] = nil
        PLAYER_EMIT_SOUND_POS[ply] = nil
    end
end

-- net.Receive(NET_WORK_STRINGS.PLAYER_EMIT_SOUND_TIME, function(len, ply)
--     PLAYER_EMIT_SOUND_TIME[ply] = net.ReadFloat()
--     tryEmitSound(ply)
-- end)
-- net.Receive(NET_WORK_STRINGS.PLAYER_EMIT_SOUND_LEVEL, function(len, ply)
--     PLAYER_EMIT_SOUND_LEVEL[ply] = net.ReadFloat()
--     tryEmitSound(ply)
-- end)
-- net.Receive(NET_WORK_STRINGS.PLAYER_EMIT_SOUND_POS, function(len, ply)
--     PLAYER_EMIT_SOUND_POS[ply] = net.ReadVector()
--     tryEmitSound(ply)
-- end)

-- hook.Add("PlayerDisconnected", PLUGIN_NAME .. "PlayerDisconnected", function(ply)
--     PLAYER_EMIT_SOUND_TIME[ply] = nil
--     PLAYER_EMIT_SOUND_LEVEL[ply] = nil
--     PLAYER_EMIT_SOUND_POS[ply] = nil
-- end)

hook.Add("EntityEmitSound", PLUGIN_NAME .. "EntityEmitSound", function(data)
    local ent = data.Entity
    if not ent:IsValid() then return end

    if ent:IsPlayer() or ent:GetOwner():IsPlayer() then
        local time = data.SoundTime or 1
        local soundLevel = data.SoundLevel or 75
        local pos = data.Pos or ent:GetPos()
        if time and level and pos then
            local radius = SoundLevelToSourceUnits(soundLevel)
            sound.EmitHint(SOUND_PLAYER, pos, radius, time, ply)
            PLAYER_EMIT_SOUND_TIME[ply] = nil
            PLAYER_EMIT_SOUND_LEVEL[ply] = nil
            PLAYER_EMIT_SOUND_POS[ply] = nil
        end
    end
end)

local NPC_CONFIDENT_TIME = CONSTANTS.NPC_CONFIDENT_TIME

local NOT_SHOOT_CONDITIONS = {
    COND.LOW_PRIMARY_AMMO,
    COND.NO_PRIMARY_AMMO,
    COND.NO_SECONDARY_AMMO,
    COND.NO_WEAPON,
    COND.WEAPON_BLOCKED_BY_FRIEND
}

local SHOOT_AT_ENEMY_CONDITIONS = {
    COND.ENEMY_OCCLUDED,
    COND.WEAPON_SIGHT_OCCLUDED
}

local NOT_SHOOT_AT_ENEMY_CONDITIONS = {
    COND.LOST_ENEMY,
    COND.LOST_PLAYER,
}

local SHOOT_AT_HINT_CONDITIONS = {
    SOUND_BULLET_IMPACT = COND.HEAR_BULLET_IMPACT,
    SOUND_COMBAT = COND.HEAR_COMBAT,
    SOUND_DANGER = COND.HEAR_DANGER,
    SOUND_MOVE_AWAY = COND.HEAR_MOVE_AWAY,
    SOUND_PLAYER = COND.HEAR_PLAYER
}

local STRING_TO_NUMBER = {
    SOUND_BULLET_IMPACT = SOUND_BULLET_IMPACT,
    SOUND_COMBAT = SOUND_COMBAT,
    SOUND_DANGER = SOUND_DANGER,
    SOUND_MOVE_AWAY = SOUND_MOVE_AWAY,
    SOUND_PLAYER = SOUND_PLAYER,
}

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
            if npc:GetEnemy() and npc:GetEnemy():Alive() then continue end

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
