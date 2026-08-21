-- npc_monitor/schedule/translator.lua
-- 订阅 TranslateSchedule 事件，执行调度控制逻辑
-- 顺序：防重入识别 -> 失败保护 -> 正常决策

local CONSTANTS      = include("npc_monitor/config/constants.lua")
local Events         = include("npc_monitor/core/events.lua")
local log            = include("npc_monitor/logging/log.lua")
local helpers        = include("npc_monitor/helpers.lua")
local addUniqueHook  = helpers.addUniqueHook

local selectSchedule = include("npc_monitor/schedule/selector.lua")

-- 弱键表：以 NPC 为 key，value 是该 NPC 的控制状态。
local stateByNPC     = setmetatable({}, { __mode = "k" })

local function getState(npc)
    local state = stateByNPC[npc]
    if not state then
        state = {}
        stateByNPC[npc] = state
    end
    return state
end

-- Hook：实体移除时清理缓存
addUniqueHook("EntityRemoved", function(ent, _)
    stateByNPC[ent] = nil
end)

-- 核心调度控制函数（顺序：防重入识别 -> 失败保护 -> 正常决策）
addUniqueHook(Events.TranslateSchedule, function(npc, lastSchedule, currentSchedule)
    if not IsValid(npc) then return end

    local state       = getState(npc)

    -- 1. 防重入识别：检查跳过标记（我们自己设置 schedule 引发的二次事件）
    local skipLast    = state.skipLast
    local skipCurrent = state.skipCurrent

    if skipLast ~= nil and skipCurrent ~= nil then
        if lastSchedule == skipLast and currentSchedule == skipCurrent then
            -- 匹配，是我们自己设置的 schedule 生效，消费标记并返回
            state.skipLast    = nil
            state.skipCurrent = nil
            return
        else
            -- 不匹配，我们设置的 schedule 被其他因素覆盖
            state.skipLast    = nil
            state.skipCurrent = nil
            state.lastDesired = nil    -- 清除控制状态，后续失败保护将失效
        end
    end

    -- 2. 失败保护：如果存在上次设置的 schedule，且它刚刚失败（COND_TASK_FAILED），则阻止重复设置
    local lastDesired = state.lastDesired
    local blockedSchedule = nil
    if lastDesired and lastSchedule == lastDesired and npc:HasCondition(COND.TASK_FAILED) then
        blockedSchedule = lastDesired
        state.lastDesired = nil -- 清除，表示不再控制
    end

    -- 3. 正常处理
    local desiredSchedule = selectSchedule(npc, lastSchedule, currentSchedule)

    if desiredSchedule then
        -- 如果刚刚失败的 schedule 正好又是期望的，则本次放弃设置，避免循环
        if blockedSchedule and desiredSchedule == blockedSchedule then
            return
        end

        -- 更新最后期望 schedule
        state.lastDesired = desiredSchedule

        -- 如果当前 schedule 与期望不同，强制设置并记录跳过标记
        if currentSchedule ~= desiredSchedule then
            state.skipLast    = currentSchedule
            state.skipCurrent = desiredSchedule
            npc:SetSchedule(desiredSchedule)
        end
    else
        -- 不需要控制，清除最后期望记录
        state.lastDesired = nil
    end
end)
