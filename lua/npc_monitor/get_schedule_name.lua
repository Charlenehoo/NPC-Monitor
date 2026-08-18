local Enum = include("enum.lua")
local COMBINE_SCHEDULE_ID_TO_NAME = Enum.COMBINE_SCHEDULE_ID_TO_NAME
local SCHEDULE_ID_TO_NAME = Enum.SCHEDULE_ID_TO_NAME

-- 生成 schedule 名称
-- @param id  schedule 的整数编号
-- @param npc 可选，NPC 实体（用于区分不同类别的专属 schedule）
-- @return 字符串形式的 schedule 名称
local function getScheduleName(id, npc)
    if not id then
        return "NIL"
    end

    if IsValid(npc) and npc:GetClass() == "npc_combine_s" then
        local combineName = COMBINE_SCHEDULE_ID_TO_NAME[id]
        if combineName then
            return combineName
        end
    end

    local sharedName = SCHEDULE_ID_TO_NAME[id]
    if sharedName then
        return sharedName
    end

    return "SCHED_UNKNOWN_" .. id
end

return getScheduleName
