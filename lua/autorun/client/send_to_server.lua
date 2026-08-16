local CONSTANTS = include("npc_shoot_enemy_cover/constants.lua")
local PLUGIN_NAME = CONSTANTS.PLUGIN_NAME
local PLAYER_EMIT_SOUND = CONSTANTS.NET_WORK_STRINGS.PLAYER_EMIT_SOUND
-- local PLAYER_EMIT_SOUND_TIME = CONSTANTS.NET_WORK_STRINGS.PLAYER_EMIT_SOUND_TIME
-- local PLAYER_EMIT_SOUND_LEVEL = CONSTANTS.NET_WORK_STRINGS.PLAYER_EMIT_SOUND_LEVEL
-- local PLAYER_EMIT_SOUND_POS = CONSTANTS.NET_WORK_STRINGS.PLAYER_EMIT_SOUND_POS

hook.Add("EntityEmitSound", PLUGIN_NAME .. "EntityEmitSound", function(data)
    local ent = data.Entity
    if not ent:IsValid() then return end

    if ent:IsPlayer() or ent:GetOwner():IsPlayer() then
        local time = data.SoundTime
        local level = data.SoundLevel
        local pos = data.Pos
        if time and level and IsValid(pos) then
            net.Start(PLAYER_EMIT_SOUND)
            net.WriteFloat(time)
            net.WriteFloat(level)
            net.WriteVector(pos)
            net.SendToServer()
        end
    end
end)
