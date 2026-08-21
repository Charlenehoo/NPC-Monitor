-- npc_monitor/config/constants.lua
-- 全局常量配置
local M                      = {}

M.PLUGIN_NAME                = "NPC_MONITOR"
M.HOT_FIX_FRIENDLY           = false

M.RAGADOLL_DUMMY_CLASS       = "ragdoll_dummy_target"
M.NPC_MAX_LOOK_DISTANCE      = 6000

M.SOUND_RAGDOLL              = SOUND_PLAYER

-- 默认原因持续时间（秒），当原因未单独配置 DURATION 时使用
M.SHOOT_COVER_DURATION       = 3
-- 声音提示持续时间（秒），用于 HEAR 原因默认持续时间及 EmitHint 的 duration 参数
M.SOUND_HINT_LAST            = 1.5
-- 声音提示半径，用于 EmitHint 的 volume 参数
M.SOUND_HINT_RADIUS          = 500

-- 听觉噪声椭球随机参数
-- 水平方向基础标准差（单位），与距离无关
M.HEAR_NOISE_HORIZONTAL_BASE = 3
-- 垂直方向基础标准差（单位），与距离无关
M.HEAR_NOISE_VERTICAL_BASE   = 1.5
-- 距离因子：标准差随距离线性增长的比例（例如距离 1000 单位时，水平标准差增加 100）
M.HEAR_NOISE_DISTANCE_FACTOR = 0.1

-- 实体：ragdoll_dummy_target 配置
M.RAGDOLL_DUMMY              = {
    PROXY_MODEL                      = "models/editor/cube_small.mdl",
    SCALE                            = 0.03125, -- 1 / 32
    OFFSET                           = 50,
    RELATIONSHIP_MAX_PRIORITY        = 99,

    MAX_INIT_DURATION                = 0.3,
    -- EXECUTIONER_REFRESH_INTERVAL = 6.0,
    EXECUTIONER_SEARCH_INTERVAL      = 0.3,
    EXECUTIONER_VALIDATE_INTERVAL    = 0.3,
    EXECUTIONER_MAX_FAIL_COUNT       = 2,
    EXECUTIONER_TIMEOUT              = 3.0,

    STATE_TO_SEARCH_RADIUS           = {
        init     = nil,
        falling  = 200,
        writhing = 100,
        crawling = 400,
        reviving = M.NPC_MAX_LOOK_DISTANCE,
        dead     = nil,
    },

    REPOSITION_INTERVAL              = 1.0, -- 重新定位的最小间隔（秒）
    REPOSITION_NAV_RADIUS            = 100, -- navmesh 搜索半径
    REPOSITION_NAV_STEP_HEIGHT       = 32,  -- 允许上台阶高度
    REPOSITION_NAV_DROP_HEIGHT       = 64,  -- 允许下落高度
    REPOSITION_FALLBACK_RADIUS       = 80,  -- 后备偏移的基础半径
    REPOSITION_FALLBACK_MAX_ATTEMPTS = 8,   -- 后备偏移最多尝试次数
}

return M
