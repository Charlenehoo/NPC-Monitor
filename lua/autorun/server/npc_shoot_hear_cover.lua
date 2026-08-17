local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")

local toAdds = {
    { condition = COND.HEAR_PLAYER,    hintType = SOUND_PLAYER },
    { condition = COND.HEAR_PLAYER,    hintType = SOUND_COMBAT },
    { condition = COND.HEAR_PLAYER,    hintType = SOUND_WORLD },
    { condition = COND.HEAR_PLAYER,    hintType = SOUND_DANGER },
    { condition = COND.HEAR_PLAYER,    hintType = SOUND_BULLET_IMPACT },
    { condition = COND.HEAR_MOVE_AWAY, hintType = SOUND_MOVE_AWAY },

}

for _, toAdd in pairs(toAdds) do
    local condition = toAdd.condition
    local hintType = toAdd.hintType

    addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
        if not currentValue then return end
        if conditionID ~= condition then return end
        if not IsValid(npc) then return end

        local hint = npc:GetBestSoundHint(hintType)
        if not hint then
            log.trace("No hint for type ", hintType)
            return
        end

        local target = hint.owner
        if not IsValid(target) then
            log.trace("Invalid hint owner")
            return
        end
        if target:IsWeapon() then
            target = target:GetOwner()
        end
        if not IsValid(target) then
            log.trace("Invalid weapon owner")
            return
        end

        local enemy = npc:GetEnemy()
        if IsValid(enemy) and enemy ~= target then
            log.trace("Have different enemy, skipping")
            return
        end

        -- 到这里说明真的要设置了
        log.trace("Setting enemy and schedule for target ", target)
        npc:SetEnemy(target)
        npc:UpdateEnemyMemory(target, hint.origin or target:GetPos())
        npc:SetState(NPC_STATE_COMBAT)
        npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
    end, tostring(hintType))
end
