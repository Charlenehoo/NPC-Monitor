-- npc_monitor/schedule/translator.lua
-- 订阅 TranslateSchedule 事件，执行调度控制逻辑

local CONSTANTS             = include("npc_monitor/config/constants.lua")
local Events                = include("npc_monitor/core/events.lua")
local log                   = include("npc_monitor/logging/log.lua")
local helpers               = include("npc_monitor/helpers.lua")
local addUniqueHook         = helpers.addUniqueHook

-- 如果需要直接调用 handler，可以 include 或通过选择器模块
local selectSchedule        = include("npc_monitor/schedule/selector.lua")

-- 字段名定义
local SKIP_LAST_FLAG        = CONSTANTS.PLUGIN_NAME .. "_SkipNextLast"
local SKIP_CURRENT_FLAG     = CONSTANTS.PLUGIN_NAME .. "_SkipNextCurrent"
local LAST_DESIRED_SCHEDULE = CONSTANTS.PLUGIN_NAME .. "_LastDesiredSchedule"

local function isFailureSchedule(sched)
    return sched == SCHED_FAIL
        or sched == SCHED_FAIL_NOSTOP
    -- 根据需要添加其他失败类 schedule
end

-- 核心调度控制函数（原逻辑基本不变）
addUniqueHook(Events.TranslateSchedule, function(npc, lastSchedule, currentSchedule)
    if not IsValid(npc) then return end

    local lastDesired = npc[LAST_DESIRED_SCHEDULE]

    -- 1. 如果存在上次设置的 schedule，且它刚刚失败（COND_TASK_FAILED），则阻止重复设置
    local blockedSchedule = nil
    if lastDesired and lastSchedule == lastDesired and npc:HasCondition(COND.TASK_FAILED) then
        blockedSchedule = lastDesired
        npc[LAST_DESIRED_SCHEDULE] = nil -- 清除，表示不再控制
    end

    -- 2. 检查跳过标记（我们自己设置 schedule 引发的二次事件）
    local skipLast    = npc[SKIP_LAST_FLAG]
    local skipCurrent = npc[SKIP_CURRENT_FLAG]

    if skipLast ~= nil and skipCurrent ~= nil then
        if lastSchedule == skipLast and currentSchedule == skipCurrent then
            -- 匹配，是我们自己设置的 schedule 生效，消费标记并返回
            npc[SKIP_LAST_FLAG]    = nil
            npc[SKIP_CURRENT_FLAG] = nil
            return
        else
            -- 不匹配，我们设置的 schedule 被其他因素覆盖
            npc[SKIP_LAST_FLAG]        = nil
            npc[SKIP_CURRENT_FLAG]     = nil
            npc[LAST_DESIRED_SCHEDULE] = nil -- 清除控制状态
        end
    end

    -- 3. 正常处理
    local desiredSchedule = selectSchedule(npc, lastSchedule, currentSchedule)

    if desiredSchedule then
        -- 如果刚刚失败的 schedule 正好又是期望的，则本次放弃设置，避免循环
        if blockedSchedule and desiredSchedule == blockedSchedule then
            return
        end

        -- 更新最后期望 schedule
        npc[LAST_DESIRED_SCHEDULE] = desiredSchedule

        -- 如果当前 schedule 与期望不同，强制设置并记录跳过标记
        if currentSchedule ~= desiredSchedule then
            npc[SKIP_LAST_FLAG]    = currentSchedule
            npc[SKIP_CURRENT_FLAG] = desiredSchedule
            npc:SetSchedule(desiredSchedule)
        end
    else
        -- 不需要控制，清除最后期望记录
        npc[LAST_DESIRED_SCHEDULE] = nil
    end
end)
