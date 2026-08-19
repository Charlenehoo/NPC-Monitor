-- npc_shoot_occluded_cover.lua
-- 意图调度核心：负责根据原因配置，强制 NPC 执行特定的 Schedule
local CONSTANTS = include("npc_monitor/constants.lua")
local log = include("npc_monitor/log.lua")
local helpers = include("npc_monitor/helpers.lua")
local addUniqueHook = include("npc_monitor/add_hook.lua")

local config = include("npc_monitor/causes_config.lua")


local CAUSES = config.CAUSES
local CONDITION_TO_REASON = config.CONDITION_TO_REASON
local findNearestPlayer = helpers.findNearestPlayer
local gaussianRandom = helpers.gaussianRandom

-- 通用中断检查：敌人无效或死亡
local function checkCommonInterrupt(npc)
    local enemy = npc:GetEnemy()
    if not IsValid(enemy) or not enemy:Alive() then
        return true
    end
    return false
end

-- 判断指定原因是否应该被移除（即该原因已不再有效）
local function shouldRemoveCause(npc, reason)
    -- 通用敌人有效性检查
    if checkCommonInterrupt(npc) then
        return true
    end

    local causeData = CAUSES[reason]
    if not causeData then return true end

    -- 检查该原因对应的中断条件
    local interruptConds = causeData.INTERRUPT or {}
    for _, condID in ipairs(interruptConds) do
        if npc:HasCondition(condID) then
            return true
        end
    end

    -- 统一的时间限制检查
    local duration = causeData.DURATION or CONSTANTS.SHOOT_COVER_DURATION
    local start = npc._desiredScheduleCauseStart and npc._desiredScheduleCauseStart[reason]
    if start and duration and duration > 0 and (CurTime() - start) > duration then
        return true
    end

    return false
end

-- 获取当前所有活跃原因中最高的维持优先级
local function getHighestHoldPriority(npc)
    local highest = 0
    if not npc._desiredScheduleCauses then return highest end

    for reason in pairs(npc._desiredScheduleCauses) do
        local causeData = CAUSES[reason]
        if causeData then
            local hold = causeData.HOLD_PRIORITY or 0
            if hold > highest then
                highest = hold
            end
        end
    end
    return highest
end

-- 重新计算当前应执行的目标 Schedule
-- 返回目标 Schedule ID，若无活跃原因则返回 nil
local function recalcDesiredSchedule(npc)
    if not npc._desiredScheduleCauses or table.Count(npc._desiredScheduleCauses) == 0 then
        return nil
    end

    local bestReason = nil
    local bestHold = -math.huge

    for reason in pairs(npc._desiredScheduleCauses) do
        local causeData = CAUSES[reason]
        if causeData then
            local hold = causeData.HOLD_PRIORITY or 0
            if hold > bestHold then
                bestHold = hold
                bestReason = reason
            end
        end
    end

    if bestReason then
        return CAUSES[bestReason].SCHEDULE or SCHED_SHOOT_ENEMY_COVER
    end
    return nil
end

-- 根据当前活跃原因更新武器熟练度
local function updateWeaponProficiency(npc)
    local shouldLower = false
    local targetProficiency = nil

    -- 检查是否有活跃原因配置了 WEAPON_PROFICIENCY
    if npc._desiredScheduleCauses then
        for reason in pairs(npc._desiredScheduleCauses) do
            local causeData = CAUSES[reason]
            if causeData and causeData.WEAPON_PROFICIENCY then
                shouldLower = true
                targetProficiency = causeData.WEAPON_PROFICIENCY
                break -- 取第一个找到的，可根据需要改为取最高优先级原因的值
            end
        end
    end

    if shouldLower then
        -- 如果有原因要求降低熟练度，且尚未保存原始熟练度，则保存并降低
        if not npc._originalWeaponProficiency then
            npc._originalWeaponProficiency = npc:GetCurrentWeaponProficiency()
        end
        if targetProficiency then
            npc:SetCurrentWeaponProficiency(targetProficiency)
        end
    else
        -- 没有原因要求降低熟练度，恢复原始（如果保存过）
        if npc._originalWeaponProficiency then
            npc:SetCurrentWeaponProficiency(npc._originalWeaponProficiency)
            npc._originalWeaponProficiency = nil
        end
    end
end

-- 添加一个原因（引用计数加1）
local function addCause(npc, reason)
    -- 初始化字段
    npc._desiredScheduleCauses = npc._desiredScheduleCauses or {}
    npc._desiredScheduleCauseStart = npc._desiredScheduleCauseStart or {}

    -- 幂等：如果该原因已存在，则不做任何操作
    if npc._desiredScheduleCauses[reason] then
        return
    end

    -- 记录该原因
    npc._desiredScheduleCauses[reason] = true
    npc._desiredScheduleCauseStart[reason] = CurTime()

    -- 更新武器熟练度
    updateWeaponProficiency(npc)

    -- 重新计算目标 Schedule 并尝试切换
    local desiredSchedule = recalcDesiredSchedule(npc)
    if desiredSchedule then
        npc._desiredSchedule = desiredSchedule
        if npc:GetCurrentSchedule() ~= desiredSchedule then
            npc:SetSchedule(desiredSchedule)
        end
    end
end

-- 移除一个原因（引用计数减1）
local function removeCause(npc, reason)
    if not npc._desiredScheduleCauses then return end
    if not npc._desiredScheduleCauses[reason] then return end

    npc._desiredScheduleCauses[reason] = nil
    npc._desiredScheduleCauseStart[reason] = nil

    -- 调用该原因的自定义移除回调
    local causeData = CAUSES[reason]
    if causeData and causeData.ON_REMOVE then
        causeData.ON_REMOVE(npc, reason)
    end

    -- 更新武器熟练度
    updateWeaponProficiency(npc)

    -- 如果没有活跃原因了，清除目标
    if table.Count(npc._desiredScheduleCauses) == 0 then
        npc._desiredSchedule = nil
        return
    end

    -- 重新计算目标 Schedule 并尝试切换
    local desiredSchedule = recalcDesiredSchedule(npc)
    if desiredSchedule then
        npc._desiredSchedule = desiredSchedule
        if npc:GetCurrentSchedule() ~= desiredSchedule then
            npc:SetSchedule(desiredSchedule)
        end
    end
end

-- 统一的 OnCondition 钩子：仅在触发条件的上升沿尝试激活原因
addUniqueHook("OnCondition", function(npc, conditionName, conditionID, lastValue, currentValue)
    if not IsValid(npc) then return end
    if not (currentValue and not lastValue) then return end

    local reason = CONDITION_TO_REASON[conditionID]
    if not reason then return end

    -- 原因已存在则忽略（幂等）
    if npc._desiredScheduleCauses and npc._desiredScheduleCauses[reason] then
        return
    end

    -- 预检查：如果该原因当前应被中断，则不允许添加
    if shouldRemoveCause(npc, reason) then
        return
    end

    local causeData = CAUSES[reason]
    if not causeData then return end

    -- 入口优先级检查：判断新原因能否抢占当前活跃意图
    local entryPriority = causeData.ENTRY_PRIORITY or 0
    local strict = causeData.STRICT_PRIORITY ~= false -- 默认严格大于
    local currentHighestHold = getHighestHoldPriority(npc)

    local allow = false
    if currentHighestHold == 0 then
        allow = true -- 无活跃意图，直接允许
    else
        if strict then
            allow = entryPriority > currentHighestHold
        else
            allow = entryPriority >= currentHighestHold
        end
    end

    if not allow then
        return
    end

    -- 执行自定义添加回调
    if causeData.ON_ADD then
        local canAdd = causeData.ON_ADD(npc, reason)
        if canAdd == false then
            return
        end
    end

    -- 正式添加原因
    addCause(npc, reason)
end, "SHOOT_COVER_CAUSES")

-- 当 NPC 离开目标 Schedule 时，清理失效原因并重新计算强制目标
addUniqueHook("OnTranslateSchedule", function(npc, lastSchedule, currentSchedule)
    if not IsValid(npc) then return end

    -- 如果没有我们设置的目标 Schedule，则忽略
    if not npc._desiredSchedule then return end
    -- 只关心 NPC 从我们的目标 Schedule 离开的情况
    if lastSchedule ~= npc._desiredSchedule or currentSchedule == npc._desiredSchedule then return end

    -- 遍历所有活跃原因，移除已失效的
    for reason in pairs(npc._desiredScheduleCauses or {}) do
        if shouldRemoveCause(npc, reason) then
            removeCause(npc, reason)
        end
    end

    -- 如果移除后仍有活跃原因，重新计算并强制设置目标 Schedule
    if npc._desiredScheduleCauses and table.Count(npc._desiredScheduleCauses) > 0 then
        local desiredSchedule = recalcDesiredSchedule(npc)
        if desiredSchedule then
            npc._desiredSchedule = desiredSchedule
            if npc:GetCurrentSchedule() ~= desiredSchedule then
                npc:SetSchedule(desiredSchedule)
            end
        end
    end
end, "SHOOT_COVER_MAINTAIN")
