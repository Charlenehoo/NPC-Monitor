local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")

addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not conditionID == COND.HEAR_PLAYER then return end
    if not IsValid(npc) then return end

    local hint = npc:GetBestSoundHint(SOUND_PLAYER)
    if not hint then return end

    local owner = hint.owner
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local enemy = npc:GetEnemy()
    if not IsValid(enemy) or enemy == owner then
        npc:SetEnemy(owner)
        npc:UpdateEnemyMemory(owner, hint.origin or owner:GetPos())
        npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
    end
end)
