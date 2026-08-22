-- npc_monitor/schedule/translator.lua
-- 订阅 TranslateSchedule 事件，执行调度控制逻辑
-- 顺序：防重入识别 -> 失败保护 -> 正常决策

local CONSTANTS            = include("npc_monitor/config/constants.lua")
local Events               = include("npc_monitor/core/events.lua")
local log                  = include("npc_monitor/logging/log.lua")
local helpers              = include("npc_monitor/helpers.lua")
local addUniqueHook        = helpers.addUniqueHook

local selectSchedule       = include("npc_monitor/schedule/selector.lua")

-- 弱键表：以 NPC 实体为键，分别存储调度控制的各字段
local skipLastSchedules    = setmetatable({}, { __mode = "k" })
local skipCurrentSchedules = setmetatable({}, { __mode = "k" })
local lastDesiredSchedules = setmetatable({}, { __mode = "k" })

-- 弱键表：缓存每个 NPC 上一次的 schedule，供 TryControlNPC 主动调用时提供 lastSchedule
local lastSchedules        = setmetatable({}, { __mode = "k" })

-- Hook：实体移除时清理缓存
addUniqueHook("EntityRemoved", function(ent, _)
    skipLastSchedules[ent]    = nil
    skipCurrentSchedules[ent] = nil
    lastDesiredSchedules[ent] = nil
    lastSchedules[ent]        = nil
end)

-- 核心调度控制逻辑（供事件钩子和主动调用共用）
-- @return desiredSchedule 如果执行了 SetSchedule 则返回目标 schedule，否则返回 nil
local function executeControl(npc, lastSchedule, currentSchedule)
    if not IsValid(npc) then return nil end

    -- 1. 防重入识别：检查跳过标记（我们自己设置 schedule 引发的二次事件）
    local skipLast    = skipLastSchedules[npc]
    local skipCurrent = skipCurrentSchedules[npc]

    if skipLast ~= nil and skipCurrent ~= nil then
        if lastSchedule == skipLast and currentSchedule == skipCurrent then
            -- 匹配，是我们自己设置的 schedule 生效，消费标记并返回
            skipLastSchedules[npc]    = nil
            skipCurrentSchedules[npc] = nil
            return nil
        else
            -- 不匹配，我们设置的 schedule 被其他因素覆盖
            skipLastSchedules[npc]    = nil
            skipCurrentSchedules[npc] = nil
            lastDesiredSchedules[npc] = nil -- 清除控制状态，后续失败保护将失效
        end
    end

    -- 2. 失败保护：如果存在上次设置的 schedule，且它刚刚失败（COND_TASK_FAILED），则阻止重复设置
    local lastDesired = lastDesiredSchedules[npc]
    local blockedSchedule = nil
    if lastDesired and lastSchedule == lastDesired and npc:HasCondition(COND.TASK_FAILED) then
        blockedSchedule = lastDesired
        lastDesiredSchedules[npc] = nil -- 清除，表示不再控制
    end

    -- 3. 正常处理
    local desiredSchedule = selectSchedule(npc, lastSchedule, currentSchedule)

    if desiredSchedule then
        -- 如果刚刚失败的 schedule 正好又是期望的，则本次放弃设置，避免循环
        if blockedSchedule and desiredSchedule == blockedSchedule then
            return nil
        end

        -- 更新最后期望 schedule
        lastDesiredSchedules[npc] = desiredSchedule

        -- 如果当前 schedule 与期望不同，强制设置并记录跳过标记
        if currentSchedule ~= desiredSchedule then
            skipLastSchedules[npc]    = currentSchedule
            skipCurrentSchedules[npc] = desiredSchedule
            npc:SetSchedule(desiredSchedule)
            return desiredSchedule
        end
    else
        -- 不需要控制，清除最后期望记录
        lastDesiredSchedules[npc] = nil
    end

    return nil
end

-- 订阅事件：正常 schedule 变化时触发
addUniqueHook(Events.TranslateSchedule, function(npc, lastSchedule, currentSchedule)
    local result = executeControl(npc, lastSchedule, currentSchedule)

    -- 更新自己的 lastSchedules 缓存，便于主动调用时提供 lastSchedule
    if IsValid(npc) then
        lastSchedules[npc] = currentSchedule
    end

    return result
end)

-- 暴露主动控制接口：其他模块（如 dummy）可以调用此函数强制 NPC 重新评估调度
-- 使用场景：当 NPC 停留在某个 schedule（如 SCHED_ALERT_STAND）且 dummy 稍后才准备好时，
--          可以直接调用此函数让 NPC 重新决策，而不必等待自然的 schedule 变化事件。
function NPCMonitor.TryControlNPC(npc)
    if not IsValid(npc) then return false end

    local currentSchedule = npc:GetCurrentSchedule()
    local lastSchedule    = lastSchedules[npc] or currentSchedule

    return executeControl(npc, lastSchedule, currentSchedule)
end
