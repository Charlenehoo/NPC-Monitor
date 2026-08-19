-- npc_monitor/helpers.lua
-- 通用辅助函数，供 NPC Monitor 各模块使用
local CONSTANTS = include("npc_monitor/constants.lua")
local Enum = include("enum.lua")

local M = {}

local function _addHook(eventName, func, appendix)
    appendix = appendix or ""
    local identifier = CONSTANTS.PLUGIN_NAME .. "_" .. appendix .. "_" .. eventName
    hook.Add(eventName, identifier, func)
    return identifier
end

local uniqueCounter = 0

--- Add a unique hook, yet people won't be able to remove it unless they got its return valve
---@param eventName string
---@param func function
---@return string identifier to remove this hook
function M.addUniqueHook(eventName, func)
    uniqueCounter = uniqueCounter + 1
    local appendix = tostring(CurTime()) .. "_" .. tostring(uniqueCounter) .. "_" .. tostring(math.random())
    return _addHook(eventName, func, appendix)
end

--- Add a hook, yet people will be able to remove it by even they didn't got its return valve,
--- yet caller of this function is responsible for the uniqueness of the appendix
---@param eventName string
---@param func function
---@return string identifier to remove this hook
function M.addHook(eventName, func, appendix)
    return _addHook(eventName, func, appendix)
end

function M.getStateName(id)
    if not id then
        return "NPC_STATE_UNKNOWN"
    else
        return Enum.NPC_STATE_ID_TO_NAME[id] or ("NPC_STATE_UNKNOWN_" .. id)
    end
end

-- 生成 schedule 名称
-- @param id  schedule 的整数编号
-- @param npc 可选，NPC 实体（用于区分不同类别的专属 schedule）
-- @return 字符串形式的 schedule 名称
function M.getScheduleName(id, npc)
    if not id then
        return "NIL"
    end

    if IsValid(npc) and npc:GetClass() == "npc_combine_s" then
        local combineName = Enum.COMBINE_SCHEDULE_ID_TO_NAME[id]
        if combineName then
            return combineName
        end
    end

    local sharedName = Enum.SCHEDULE_ID_TO_NAME[id]
    if sharedName then
        return sharedName
    end

    return "SCHED_UNKNOWN_" .. id
end

-- 使用 Box-Muller 变换生成标准正态分布随机数
-- 返回均值为 0，标准差为 1 的随机数
function M.gaussianRandom()
    local u1 = math.random()
    local u2 = math.random()
    -- 避免 u1 为 0 导致 log(0)
    if u1 == 0 then u1 = 1e-10 end
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- 在指定位置附近查找最近的存活玩家
-- @param pos Vector 中心位置
-- @param maxDist number|nil 最大搜索距离（单位），nil 表示无限制
-- @return Player|nil 最近的存活玩家，若没有则返回 nil
function M.findNearestPlayer(pos, maxDist)
    local nearestPlayer = nil
    local nearestDistSqr = maxDist and (maxDist * maxDist) or math.huge

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end

        local distSqr = ply:GetPos():DistToSqr(pos)
        if distSqr < nearestDistSqr then
            nearestDistSqr = distSqr
            nearestPlayer = ply
        end
    end

    return nearestPlayer
end

return M
