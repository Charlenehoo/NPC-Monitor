local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")


addHook("InitPostEntity", function()
    local meta = FindMetaTable("Player")
    if not meta or not meta.EmitSoundVOX then return end

    local originalEmitSoundVOX = meta.EmitSoundVOX

    function meta:EmitSoundVOX(sndid)
        originalEmitSoundVOX(self, sndid)

        -- 获取声音时长，如果无效则默认 1 秒
        local dur = SoundDuration(sndid)
        if dur <= 0 then
            dur = 1
        end

        sound.EmitHint(SOUND_PLAYER, self:GetPos(), 1000, dur, self)
    end
end, "EnhanceEmitSoundVOX")
