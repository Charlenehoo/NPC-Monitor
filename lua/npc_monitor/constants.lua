-- npc_monitor/constants.lua
-- 全局常量配置
local M = {}

-- 默认原因持续时间（秒），当原因未单独配置 DURATION 时使用
M.SHOOT_COVER_DURATION = 3

-- 声音提示持续时间（秒），用于 HEAR 原因默认持续时间及 EmitHint 的 duration 参数
M.SOUND_HINT_LAST = 1.5

-- 声音提示半径，用于 EmitHint 的 volume 参数
M.SOUND_HINT_RADIUS = 500

-- 听觉噪声椭球随机参数
-- 水平方向基础标准差（单位），与距离无关
M.HEAR_NOISE_HORIZONTAL_BASE = 30
-- 垂直方向基础标准差（单位），与距离无关
M.HEAR_NOISE_VERTICAL_BASE = 15
-- 距离因子：标准差随距离线性增长的比例（例如距离 1000 单位时，水平标准差增加 100）
M.HEAR_NOISE_DISTANCE_FACTOR = 0.1

return M
