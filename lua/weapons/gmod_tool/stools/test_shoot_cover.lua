TOOL.Category = "Test"
TOOL.Name = "Test Shoot Cover"

local SCHEDULE_ENUM = {
    --- The schedule enum limit
    LAST_SHARED_SCHEDULE = 88,
    --- Begins AI script based on NPC's `m_hCine` save value.
    SCHED_AISCRIPT = 56,
    --- Idle stance and face ideal yaw angles.
    SCHED_ALERT_FACE = 5,
    SCHED_ALERT_FACE_BESTSOUND = 6,
    SCHED_ALERT_REACT_TO_COMBAT_SOUND = 7,
    --- Rotate 180 degrees and back to check for enemies.
    SCHED_ALERT_SCAN = 8,
    --- Remain idle until an enemy is heard or found.
    SCHED_ALERT_STAND = 9,
    --- Walk until an enemy is heard or found.
    SCHED_ALERT_WALK = 10,
    --- Remain idle until provoked or an enemy is found.
    SCHED_AMBUSH = 52,
    --- Performs ACT_ARM.
    SCHED_ARM_WEAPON = 48,
    --- Back away from enemy. If not possible to back away then go behind enemy.
    SCHED_BACK_AWAY_FROM_ENEMY = 24,
    --- Requires valid enemy, backs away from SaveValue: m_vSavePosition
    SCHED_BACK_AWAY_FROM_SAVE_POSITION = 26,
    --- Heavy damage was taken for the first time in a while.
    SCHED_BIG_FLINCH = 23,
    --- Begin chasing an enemy.
    SCHED_CHASE_ENEMY = 17,
    --- Failed to chase enemy.
    SCHED_CHASE_ENEMY_FAILED = 18,
    --- Face current enemy.
    SCHED_COMBAT_FACE = 12,
    --- Will walk around patrolling an area until an enemy is found.
    SCHED_COMBAT_PATROL = 75,
    SCHED_COMBAT_STAND = 15,
    SCHED_COMBAT_SWEEP = 13,
    SCHED_COMBAT_WALK = 16,
    --- When not moving, will perform ACT_COWER.
    SCHED_COWER = 40,
    --- Regular NPC death.
    SCHED_DIE = 53,
    --- Plays NPC death sound (doesn't kill NPC).
    SCHED_DIE_RAGDOLL = 54,
    --- Holsters active weapon. (Only works with NPC's that can holster weapons)
    SCHED_DISARM_WEAPON = 49,
    SCHED_DROPSHIP_DUSTOFF = 79,
    --- Preform Ducking animation. (Only works with npc_alyx)
    SCHED_DUCK_DODGE = 84,
    --- Search for a place to shoot current enemy.
    SCHED_ESTABLISH_LINE_OF_FIRE = 35,
    --- Fallback from an established line of fire.
    SCHED_ESTABLISH_LINE_OF_FIRE_FALLBACK = 36,
    --- Failed doing current schedule.
    SCHED_FAIL = 81,
    --- Failed to establish a line of fire.
    SCHED_FAIL_ESTABLISH_LINE_OF_FIRE = 38,
    SCHED_FAIL_NOSTOP = 82,
    --- Failed to take cover.
    SCHED_FAIL_TAKE_COVER = 31,
    --- Fall to ground when in the air.
    SCHED_FALL_TO_GROUND = 78,
    --- Will express fear face. (Only works on NPCs with expressions)
    SCHED_FEAR_FACE = 14,
    SCHED_FLEE_FROM_BEST_SOUND = 29,
    --- Plays ACT_FLINCH_PHYSICS.
    SCHED_FLINCH_PHYSICS = 80,
    --- Force walk to SaveValue: m_vecLastPosition (debug).
    SCHED_FORCED_GO = 71,
    --- Force run to SaveValue: m_vecLastPosition (debug).
    SCHED_FORCED_GO_RUN = 72,
    --- Pick up item if within a radius of 5 units.
    SCHED_GET_HEALTHKIT = 66,
    --- Take cover and reload weapon.
    SCHED_HIDE_AND_RELOAD = 50,
    --- Idle stance
    SCHED_IDLE_STAND = 1,
    --- Walk to position.
    SCHED_IDLE_WALK = 2,
    --- Walk to random position within a radius of 200 units.
    SCHED_IDLE_WANDER = 3,
    SCHED_INTERACTION_MOVE_TO_PARTNER = 85,
    SCHED_INTERACTION_WAIT_FOR_PARTNER = 86,
    SCHED_INVESTIGATE_SOUND = 11,
    SCHED_MELEE_ATTACK1 = 41,
    SCHED_MELEE_ATTACK2 = 42,
    --- Move away from player.
    SCHED_MOVE_AWAY = 68,
    --- Stop moving and continue enemy scan.
    SCHED_MOVE_AWAY_END = 70,
    --- Failed to move away; stop moving.
    SCHED_MOVE_AWAY_FAIL = 69,
    --- Move away from enemy while facing it and checking for new enemies.
    SCHED_MOVE_AWAY_FROM_ENEMY = 25,
    --- Move to the range the weapon is preferably used at.
    SCHED_MOVE_TO_WEAPON_RANGE = 34,
    --- Pick up a new weapon if within a radius of 5 units.
    SCHED_NEW_WEAPON = 63,
    --- Fail safe: Create the weapon that the NPC went to pick up if it was removed during pick up schedule.
    SCHED_NEW_WEAPON_CHEAT = 64,
    --- No schedule is being performed.
    SCHED_NONE = 0,
    --- Prevents movement until COND.NPC_UNFREEZE(68) is set.
    SCHED_NPC_FREEZE = 73,
    --- Run to random position and stop if enemy is heard or found.
    SCHED_PATROL_RUN = 76,
    --- Walk to random position and stop if enemy is heard or found.
    SCHED_PATROL_WALK = 74,
    SCHED_PRE_FAIL_ESTABLISH_LINE_OF_FIRE = 37,
    SCHED_RANGE_ATTACK1 = 43,
    SCHED_RANGE_ATTACK2 = 44,
    --- Stop moving and reload until danger is heard.
    SCHED_RELOAD = 51,
    --- Retreat from the established enemy.
    SCHED_RUN_FROM_ENEMY = 32,
    SCHED_RUN_FROM_ENEMY_FALLBACK = 33,
    SCHED_RUN_FROM_ENEMY_MOB = 83,
    --- Run to random position within a radius of 500 units.
    SCHED_RUN_RANDOM = 77,
    SCHED_SCENE_GENERIC = 62,
    SCHED_SCRIPTED_CUSTOM_MOVE = 59,
    SCHED_SCRIPTED_FACE = 61,
    SCHED_SCRIPTED_RUN = 58,
    SCHED_SCRIPTED_WAIT = 60,
    SCHED_SCRIPTED_WALK = 57,
    --- Shoot cover that the enemy is behind.
    SCHED_SHOOT_ENEMY_COVER = 39,
    --- Sets the NPC to a sleep-like state.
    SCHED_SLEEP = 87,
    SCHED_SMALL_FLINCH = 22,
    SCHED_SPECIAL_ATTACK1 = 45,
    SCHED_SPECIAL_ATTACK2 = 46,
    SCHED_STANDOFF = 47,
    SCHED_SWITCH_TO_PENDING_WEAPON = 65,
    SCHED_TAKE_COVER_FROM_BEST_SOUND = 28,
    --- Take cover from current enemy.
    SCHED_TAKE_COVER_FROM_ENEMY = 27,
    --- Flee from SaveValue: vLastKnownLocation
    SCHED_TAKE_COVER_FROM_ORIGIN = 30,
    --- Chase set NPC target.
    SCHED_TARGET_CHASE = 21,
    --- Face NPC target.
    SCHED_TARGET_FACE = 20,
    --- Human victory dance.
    SCHED_VICTORY_DANCE = 19,
    SCHED_WAIT_FOR_SCRIPT = 55,
    SCHED_WAIT_FOR_SPEAK_FINISH = 67,
    --- Spot an enemy and go from an idle state to combat state.
    SCHED_WAKE_ANGRY = 4,
}
local SCHEDULE_ID_TO_NAME = {}
for name, id in pairs(SCHEDULE_ENUM) do
    SCHEDULE_ID_TO_NAME[id] = name
end
local function getScheduleName(id)
    return SCHEDULE_ID_TO_NAME[id] or ("SCHED_UNKNOWN_" .. id)
end

function TOOL:LeftClick(tr)
    local clickEnt = tr.Entity
    if not IsValid(clickEnt) or not clickEnt:IsNPC() then return false end
    local clickNPC = clickEnt

    local ply = self:GetOwner()
    ply._clickNPC = clickNPC

    return true
end

function TOOL:RightClick(tr)
    local ply = self:GetOwner()
    local clickNPC = ply._clickNPC
    if not IsValid(clickNPC) then return false end

    local clickPos = tr.HitPos

    local cube = ents.Create("npc_combine_s")
    cube:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    cube:SetPos(clickPos)
    cube:Spawn()

    clickNPC:AddEntityRelationship(clickEnt, D_HT, 99)
    clickNPC:SetEnemy(clickEnt)
    clickNPC:UpdateEnemyMemory(clickEnt, clickEnt:GetPos())
    clickNPC:SetSchedule(SCHED_SHOOT_ENEMY_COVER)

    return true
end

local lastScheduleID = nil
local lastEnemy = nil
function TOOL:Think()
    local ply = self:GetOwner()
    local clickNPC = ply._clickNPC
    if not IsValid(clickNPC) then return false end

    local thisScheduleID = clickNPC:GetCurrentSchedule()
    if thisScheduleID then
        if not lastScheduleID then
            lastScheduleID = thisScheduleID
        end
        if thisScheduleID ~= lastScheduleID then
            print(getScheduleName(lastScheduleID) .. " -> " .. getScheduleName(thisScheduleID))
        end
        lastScheduleID = thisScheduleID
    end

    local thisEnemy = clickNPC:GetEnemy()
    if thisEnemy then
        if not lastEnemy then
            lastEnemy = thisEnemy
        end
        if thisEnemy ~= lastEnemy then
            print(tostring(lastEnemy) .. " -> " .. tostring(thisEnemy))
        end
        lastEnemy = thisEnemy
    end
end
