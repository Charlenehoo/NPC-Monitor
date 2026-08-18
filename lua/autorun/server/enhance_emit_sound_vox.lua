local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")
local CONSTANTS = include("npc_monitor/constants.lua")

addHook("InitPostEntity", function()
    local meta = FindMetaTable("Player")
    if not meta or not meta.EmitSoundVOX then return end

    local originalEmitSoundVOX = meta.EmitSoundVOX

    function meta:EmitSoundVOX(sndid)
        originalEmitSoundVOX(self, sndid)
        sound.EmitHint(SOUND_PLAYER, self:GetPos(), CONSTANTS.SOUND_HINT_RADIUS, CONSTANTS.SOUND_HINT_LAST, self)
    end
end, "EnhanceEmitSoundVOX")
