-- npc_shoot_occluded_cover.lua
local log = include("npc_monitor/log.lua")
local addHook = include("npc_monitor/add_hook.lua")
local Enum = include("npc_monitor/enum.lua")

-- 共享 schedule 保护表（所有 NPC 通用）
local SHARED_PROTECTED_SCHEDULES = {
    -- 死亡与硬直
    [Enum.SCHEDULE_ENUM.SCHED_DIE] = true,
    [Enum.SCHEDULE_ENUM.SCHED_DIE_RAGDOLL] = true,
    [Enum.SCHEDULE_ENUM.SCHED_BIG_FLINCH] = true,
    [Enum.SCHEDULE_ENUM.SCHED_SMALL_FLINCH] = true,
    [Enum.SCHEDULE_ENUM.SCHED_FLINCH_PHYSICS] = true,
    -- 脚本与场景
    [Enum.SCHEDULE_ENUM.SCHED_AISCRIPT] = true,
    [Enum.SCHEDULE_ENUM.SCHED_SCENE_GENERIC] = true,
    [Enum.SCHEDULE_ENUM.SCHED_SCRIPTED_WALK] = true,
    [Enum.SCHEDULE_ENUM.SCHED_SCRIPTED_RUN] = true,
    [Enum.SCHEDULE_ENUM.SCHED_SCRIPTED_CUSTOM_MOVE] = true,
    [Enum.SCHEDULE_ENUM.SCHED_SCRIPTED_WAIT] = true,
    [Enum.SCHEDULE_ENUM.SCHED_SCRIPTED_FACE] = true,
    [Enum.SCHEDULE_ENUM.SCHED_WAIT_FOR_SCRIPT] = true,
    [Enum.SCHEDULE_ENUM.SCHED_WAIT_FOR_SPEAK_FINISH] = true,
    -- 武器操作
    [Enum.SCHEDULE_ENUM.SCHED_ARM_WEAPON] = true,
    [Enum.SCHEDULE_ENUM.SCHED_DISARM_WEAPON] = true,
    [Enum.SCHEDULE_ENUM.SCHED_NEW_WEAPON] = true,
    [Enum.SCHEDULE_ENUM.SCHED_NEW_WEAPON_CHEAT] = true,
    [Enum.SCHEDULE_ENUM.SCHED_SWITCH_TO_PENDING_WEAPON] = true,
    [Enum.SCHEDULE_ENUM.SCHED_RELOAD] = true,
    [Enum.SCHEDULE_ENUM.SCHED_HIDE_AND_RELOAD] = true,
    -- 攻击动作
    [Enum.SCHEDULE_ENUM.SCHED_RANGE_ATTACK1] = true,
    [Enum.SCHEDULE_ENUM.SCHED_RANGE_ATTACK2] = true,
    [Enum.SCHEDULE_ENUM.SCHED_MELEE_ATTACK1] = true,
    [Enum.SCHEDULE_ENUM.SCHED_MELEE_ATTACK2] = true,
    [Enum.SCHEDULE_ENUM.SCHED_SPECIAL_ATTACK1] = true,
    [Enum.SCHEDULE_ENUM.SCHED_SPECIAL_ATTACK2] = true,
    -- 冻结与失败安全
    [Enum.SCHEDULE_ENUM.SCHED_NPC_FREEZE] = true,
    [Enum.SCHEDULE_ENUM.SCHED_FAIL] = true,
    [Enum.SCHEDULE_ENUM.SCHED_FAIL_NOSTOP] = true,
}

-- 类别专属 schedule 保护表
local CLASS_PROTECTED_SCHEDULES = {
    ["npc_combine_s"] = {
        -- 换弹与武器操作
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_HIDE_AND_RELOAD] = true,

        -- 攻击动作
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_RANGE_ATTACK1] = true,
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_RANGE_ATTACK2] = true,
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_AR2_ALTFIRE] = true,
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_MOVE_TO_MELEE] = true,
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_GRENADE_COVER1] = true,
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_TOSS_GRENADE_COVER1] = true,
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_GRENADE_AND_RELOAD] = true,
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_DROP_GRENADE] = true,
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_FORCED_GRENADE_THROW] = true,
        [Enum.COMBINE_SCHEDULE_ENUM.SCHED_COMBINE_MOVE_TO_FORCED_GREN_LOS] = true,
    },
    -- 以后可以加入其他 NPC：
    -- ["npc_citizen"] = {
    --     [Enum.CITIZEN_SCHEDULE_ENUM.SCHED_CITIZEN_XXX] = true,
    -- },
}

local function isProtectedSchedule(npc, schedule)
    local classSchedules = CLASS_PROTECTED_SCHEDULES[npc:GetClass()]
    if classSchedules and classSchedules[schedule] then
        return true
    end

    if SHARED_PROTECTED_SCHEDULES[schedule] then
        return true
    end

    return false
end

addHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not IsValid(npc) then return end
    if conditionID ~= COND.ENEMY_OCCLUDED then return end
    if not currentValue then return end

    local currentSchedule = npc:GetCurrentSchedule()

    if isProtectedSchedule(npc, currentSchedule) then
        return
    end

    npc:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
    npc:ClearCondition(COND.ENEMY_OCCLUDED)
end, "ENEMY_OCCLUDED")
