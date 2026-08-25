-- npc_monitor/config/constants.lua
-- 全局常量配置
local M                 = {}

M.PLUGIN_NAME           = "NPC_MONITOR"
M.HOT_FIX_FRIENDLY      = false
M.PLAYER_ONLY           = true

M.RAGADOLL_DUMMY_CLASS  = "ragdoll_dummy_target"
M.NPC_MAX_LOOK_DISTANCE = 6000

-- 声音提示持续时间（秒），用于 HEAR 原因默认持续时间及 EmitHint 的 duration 参数
M.SOUND_HINT_LAST       = 1.5
-- 声音提示半径，用于 EmitHint 的 volume 参数
M.SOUND_HINT_RADIUS     = 500

-- 实体：ragdoll_dummy_target 配置
M.RAGDOLL_DUMMY         = {
    PROXY_MODEL                   = "models/editor/cube_small.mdl",
    SCALE                         = 0.03125, -- 1 / 32
    OFFSET                        = 5,
    RELATIONSHIP_MAX_PRIORITY     = 99,
    MAX_INIT_DURATION             = 0.3,
    EXECUTIONER_SEARCH_INTERVAL   = 0.3,
    EXECUTIONER_VALIDATE_INTERVAL = 0.6,
    EXECUTIONER_MAX_FAIL_COUNT    = 2,
    EXECUTIONER_TIMEOUT           = 3.0,
    STATE_TO_SEARCH_RADIUS        = {
        init     = nil,
        falling  = 315,
        writhing = 160,
        crawling = 630,
        reviving = M.NPC_MAX_LOOK_DISTANCE,
        dead     = nil,
    },
    REPOSITION_INTERVAL           = 1.5,
    REPOSITION_RADIUS_MIN         = 63,
    REPOSITION_RADIUS_MAX         = 80,

    POSITION_RESET_INTERVAL       = 15.0,
    DEAD_REMOVE_DELAY             = 9.0,

    -- 静止检查间隔（秒）
    STATIC_CHECK_INTERVAL         = 1,
    -- 连续静止检查次数达到该值则判定为死亡
    STATIC_CONSECUTIVE_COUNT      = 2,
    -- 角速度平方阈值（约 30°/s 对应 0.25，约 57°/s 对应 1.0）
    STATIC_ANG_VEL_SQR_THRESHOLD  = 1,
    -- 线速度平方阈值（约 5 unit/s 对应 25）
    STATIC_LIN_VEL_SQR_THRESHOLD  = 25,
}

return M
