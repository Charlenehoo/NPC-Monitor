local CONSTANTS = include("npc_monitor/constants.lua")
local log = include("npc_monitor/log.lua")
local helpers = include("npc_monitor/helpers.lua")
local addUniqueHook = helpers.addUniqueHook

addUniqueHook("InitPostEntity", function()
    local meta = FindMetaTable("Player")
    if not meta or not meta.EmitSoundVOX then return end

    local originalEmitSoundVOX = meta.EmitSoundVOX

    function meta:EmitSoundVOX(sndid)
        originalEmitSoundVOX(self, sndid)
        sound.EmitHint(SOUND_PLAYER, self:GetPos(), CONSTANTS.SOUND_HINT_RADIUS, CONSTANTS.SOUND_HINT_LAST, self)
    end
end)
