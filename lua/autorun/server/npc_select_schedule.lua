local CONSTANTS = include("npc_monitor/constants.lua")
local log = include("npc_monitor/log.lua")
local helpers = include("npc_monitor/helpers.lua")
local addUniqueHook = helpers.addUniqueHook

local npc_combine_s = include("npc_schedule_handler/npc_combine_s.lua")

local function selectSchedule(npc, lastSchedule, currentSchedule)
    local npcClass = npc:GetClass()
    if not npcClass then return nil end

    if npcClass == "npc_combine_s" then
        return npc_combine_s(npc, lastSchedule, currentSchedule)
        -- elseif npcClass == "some_other_cool_shit" then
        --     return
    else
        return nil
    end
end

addUniqueHook("TranslateSchedule", function(npc, lastSchedule, currentSchedule)
    if not IsValid(npc) then return end

    local desiredSchedule = selectSchedule(npc, lastSchedule, currentSchedule)

    if desiredSchedule then
        npc:SetSchedule(desiredSchedule)
    end
end)
