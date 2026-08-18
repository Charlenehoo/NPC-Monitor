-- npc_monitor/helpers.lua
-- 通用辅助函数，供 NPC Monitor 各模块使用
local M = {}

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
