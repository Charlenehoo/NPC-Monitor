local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")

local SOUND_PROPAGATION = {
    referenceDistance = 1,    -- 参考距离，Source units
    thresholdLevel    = 10,   -- 最小可闻 dB，低于此值直接返回 0
    maxDistance       = 3000, -- 最大听觉半径，防止枪声等过大导致全图听到
}

local function soundLevelToSourceUnits(soundLevel)
    if not soundLevel or soundLevel <= SOUND_PROPAGATION.thresholdLevel then
        return 0
    end

    local distance = SOUND_PROPAGATION.referenceDistance *
        10 ^ ((soundLevel - SOUND_PROPAGATION.thresholdLevel) / 20)

    return math.Clamp(distance, 0, SOUND_PROPAGATION.maxDistance)
end

addHook("EntityEmitSound", function(data)
    local ent = data.Entity
    if not ent:IsValid() then return end

    local time = data.SoundTime
    local level = data.SoundLevel
    local pos = data.Pos or ent:GetPos()
    if time and level and pos then
        local radius = soundLevelToSourceUnits(level)
        sound.EmitHint(SOUND_COMBAT + SOUND_WORLD + SOUND_PLAYER + SOUND_DANGER + SOUND_BULLET_IMPACT + SOUND_MOVE_AWAY,
            pos, radius, time,
            ent)
    end
end)
