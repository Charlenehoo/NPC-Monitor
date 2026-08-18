-- npc_monitor/causes_config.lua
-- 原因/意图配置表
-- 为后续扩展预留了优先级和入口类型等字段
local helpers = include("npc_monitor/helpers.lua")
local CONSTANTS = include("npc_monitor/constants.lua")

local CAUSES = {
    OCCLUDED = {
        -- 目标 Schedule ID
        SCHEDULE = SCHED_SHOOT_ENEMY_COVER,

        -- 入口类型：REALTIME（实时，条件上升沿触发）或 LAZY（惰性，调度点触发）
        ENTRY = "REALTIME",

        -- 入口优先级：决定该原因能否抢占当前活跃的最高维持优先级意图
        ENTRY_PRIORITY = 50,

        -- 维持优先级：一旦激活，该意图将持续压制其他意图，直到被更高优先级抢占或自身中断
        HOLD_PRIORITY = 70,

        -- 优先级比较是否严格：
        -- true  = 必须严格大于（>）当前最高维持优先级才能抢占
        -- false = 大于等于（>=）即可抢占同优先级意图
        -- 默认建议 true，防止同优先级意图相互打断（例如条件抖动导致自身重复触发）
        STRICT_PRIORITY = true,

        -- 可选：激活期间强制使用的武器熟练度（若不需要，删除此字段）
        WEAPON_PROFICIENCY = WEAPON_PROFICIENCY_POOR,

        -- 触发条件：这些条件的上升沿会尝试激活该原因
        TRIGGER = {
            COND.ENEMY_OCCLUDED,
            COND.WEAPON_SIGHT_OCCLUDED,
        },

        -- 中断条件：当任意条件为真时，该原因应被移除
        INTERRUPT = {
            COND.ENEMY_WENT_NULL,
            COND.ENEMY_DEAD,
            COND.LOST_ENEMY,
            COND.ENEMY_TOO_FAR,
            COND.LOW_PRIMARY_AMMO,
            COND.NO_PRIMARY_AMMO,
            COND.LIGHT_DAMAGE,
            COND.HEAVY_DAMAGE,
            COND.WEAPON_BLOCKED_BY_FRIEND,
            COND.HEAR_DANGER,
        },

        -- 持续时间（秒），超时后原因失效
        DURATION = 3,

        -- 可选：原因激活时的回调，返回 false 可阻止添加
        ON_ADD = nil, -- OCCLUDED 无需额外逻辑

        -- 可选：原因移除时的回调（用于恢复状态等）
        ON_REMOVE = nil,
    },

    HEAR = {
        SCHEDULE = SCHED_SHOOT_ENEMY_COVER,
        ENTRY = "REALTIME",
        ENTRY_PRIORITY = 40,
        HOLD_PRIORITY = 60,
        STRICT_PRIORITY = true,

        -- 可选：激活期间强制使用的武器熟练度
        WEAPON_PROFICIENCY = WEAPON_PROFICIENCY_POOR,

        TRIGGER = {
            COND.HEAR_PLAYER,
            COND.HEAR_BULLET_IMPACT,
        },
        INTERRUPT = {
            COND.ENEMY_WENT_NULL,
            COND.ENEMY_DEAD,
            COND.LOST_ENEMY,
            COND.LOW_PRIMARY_AMMO,
            COND.NO_PRIMARY_AMMO,
            COND.LIGHT_DAMAGE,
            COND.HEAVY_DAMAGE,
            COND.WEAPON_BLOCKED_BY_FRIEND,
        },
        DURATION = CONSTANTS.SOUND_HINT_LAST,
        ON_ADD = function(npc, reason)
            local hint = npc:GetBestSoundHint()
            if not hint then return false end

            local hintPos = hint.origin
            local owner = hint.owner

            if not hintPos then
                if IsValid(owner) then
                    hintPos = owner:GetPos()
                else
                    return false
                end
            end

            -- 添加高斯椭球随机偏移，模拟听觉定位误差
            local dist = npc:GetPos():Distance(hintPos)
            local sigmaH = CONSTANTS.HEAR_NOISE_HORIZONTAL_BASE + dist * CONSTANTS.HEAR_NOISE_DISTANCE_FACTOR
            local sigmaV = CONSTANTS.HEAR_NOISE_VERTICAL_BASE + dist * CONSTANTS.HEAR_NOISE_DISTANCE_FACTOR * 0.5

            hintPos = hintPos + Vector(
                helpers.gaussianRandom() * sigmaH,
                helpers.gaussianRandom() * sigmaH,
                helpers.gaussianRandom() * sigmaV
            )

            -- 确定敌人：优先有效 owner，否则在范围内找最近玩家
            local enemy = nil
            if IsValid(owner) and owner:IsPlayer() then
                enemy = owner
            else
                enemy = helpers.findNearestPlayer(hintPos, 1000)
            end
            if not IsValid(enemy) then return false end

            npc:SetEnemy(enemy)
            npc:UpdateEnemyMemory(enemy, hintPos)
            return true
        end,
        ON_REMOVE = nil,
    },
}

-- 构建条件 ID -> 原因 ID 的反向映射（自动生成）
local CONDITION_TO_REASON = {}
for reason, data in pairs(CAUSES) do
    for _, condID in ipairs(data.TRIGGER) do
        CONDITION_TO_REASON[condID] = reason
    end
end

return {
    CAUSES = CAUSES,
    CONDITION_TO_REASON = CONDITION_TO_REASON,
}
