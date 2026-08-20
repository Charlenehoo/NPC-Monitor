-- AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"

if CLIENT then return end

local CONSTANTS = include("npc_monitor/constants.lua")
local log = include("npc_monitor/log.lua")
local helpers = include("npc_monitor/helpers.lua")
local findNearestEntity = helpers.findNearestEntity
local getEyePos = helpers.getEyePos

local PROXY_MODEL = "models/editor/cube_small.mdl"
local SCALE_1 = 0.03125 -- 1 / 32
local OFFSET = 50
local MAX = 99

local MAX_INIT_DURATION = 0.3
-- local EXECUTIONER_REFRESH_INTERVAL = 6.0
local EXECUTIONER_SEARCH_INTERVAL = 3.0
local EXECUTIONER_VALIDATE_INTERVAL = 1.0
local EXECUTIONER_MAX_FAIL_COUNT = 2

local STATE_TO_SEARCH_RADIUS = {
    init = nil,
    falling = 500,
    writhing = 1000,
    crawling = 2000,
    reviving = CONSTANTS.NPC_MAX_LOOK_DISTANCE,
    dead = nil,
}

function ENT:Initialize()
    self:SetModel(PROXY_MODEL)
    self:SetModelScale(SCALE_1)
    self:SetNPCClass(CLASS_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:SetNoDraw(true)
end

function ENT:_TryRefreshPotentialExecutioners()
    local owner = self._Owner
    local ragdoll = self._Ragdoll

    if not IsValid(ragdoll) then
        self._PotentialExecutioners = {}
        return
    end

    if IsValid(owner) then
        local newList = {}
        NPCMonitor.ForEachActiveNPC(function(npc)
            if not IsValid(npc) then return end
            local d = npc:Disposition(owner)
            if d == D_HT or d == D_FR then
                table.insert(newList, npc)
            end
        end)
        self._PotentialExecutioners = newList
    else
        local oldList = self._PotentialExecutioners or {}
        local cleaned = {}
        for _, npc in ipairs(oldList) do
            if IsValid(npc) then
                table.insert(cleaned, npc)
            end
        end
        self._PotentialExecutioners = cleaned
    end
end

function ENT:Init(owner, ragdoll)
    if not IsValid(owner) then return end
    if not IsValid(ragdoll) then return end

    local now = CurTime()

    self._Owner = owner
    self._Ragdoll = ragdoll
    -- self._CreateTime = now
    -- self._LastRefreshTime = 0
    self._LastSearchTime = now + MAX_INIT_DURATION
    self._LastExecutionerCheckTime = now - 1
    self._ExecutionerFailCount = 0
    self._Executioner = nil

    self._PotentialExecutioners = {}
    self:_TryRefreshPotentialExecutioners()
end

function ENT:_GetRagdollState(ragdoll)
    local thirdPartyMODState = ragdoll:GetNW2Int("Animation_State", -1)
    local stateName

    if thirdPartyMODState == 0 then
        stateName = "dead"
    elseif thirdPartyMODState == 1 then
        stateName = "falling"
    elseif thirdPartyMODState == 2 then
        stateName = "writhing"
    elseif thirdPartyMODState == 3 then
        stateName = "crawling"
    elseif thirdPartyMODState == 4 then
        stateName = "reviving"
    else
        stateName = "init"
    end

    local lastState = self._LastRagdollState
    if lastState ~= stateName then
        log.debug(ragdoll, "RagdollState: ", lastState or "(none)", " -> ", stateName)
        self._LastRagdollState = stateName
    end

    return stateName
end

function ENT:Think()
    local now = CurTime()

    local ragdoll = self._Ragdoll
    if not IsValid(ragdoll) then
        self:Remove()
        return
    end

    local ragdollState = self:_GetRagdollState(ragdoll)
    if ragdollState == "dead" then
        self:Remove()
        return
    end

    local ragdollEyePos = getEyePos(ragdoll)

    local function canBeExecutedBy(npc)
        if not IsValid(npc) then return false end
        if not npc:TestPVS(ragdollEyePos) then return false end
        if not npc:IsInViewCone(ragdollEyePos) then return false end
        if not npc:IsLineOfSightClear(ragdollEyePos) then return false end
        return true
    end

    if IsValid(self._Executioner) then
        if now - self._LastExecutionerCheckTime > EXECUTIONER_VALIDATE_INTERVAL then
            self._LastExecutionerCheckTime = now

            if canBeExecutedBy(self._Executioner) then
                self._ExecutionerFailCount = 0
            else
                self._ExecutionerFailCount = (self._ExecutionerFailCount or 0) + 1
                if self._ExecutionerFailCount >= EXECUTIONER_MAX_FAIL_COUNT then
                    if IsValid(self._Executioner) then
                        self._Executioner:AddEntityRelationship(self, D_NU, MAX)
                        if self._Executioner:GetEnemy() == self then
                            self._Executioner:ClearEnemyMemory()
                            self._Executioner:SetEnemy(NULL)
                        end
                    end
                    self._Executioner = nil
                    self._ExecutionerFailCount = 0
                    self._LastSearchTime = 0
                end
            end
        end

        if IsValid(self._Executioner) then
            local shootPos = self._Executioner:GetShootPos() or self._Executioner:GetPos()
            local dir = (shootPos - ragdollEyePos):GetNormalized()
            self:SetPos(ragdollEyePos + dir * OFFSET)
            self:SetAngles(dir:Angle())
            return
        end
    end

    if now - self._LastSearchTime > EXECUTIONER_SEARCH_INTERVAL then
        self._LastSearchTime = now

        if ragdollState == "init" then
            self:Remove()
            return
        end

        self:_TryRefreshPotentialExecutioners()
        if table.IsEmpty(self._PotentialExecutioners) then
            self:Remove()
            return
        end

        local searchRadius = STATE_TO_SEARCH_RADIUS[ragdollState]
        if searchRadius then
            sound.EmitHint(CONSTANTS.SOUND_RAGDOLL, ragdollEyePos, searchRadius, EXECUTIONER_SEARCH_INTERVAL,
                self)

            local nearest = findNearestEntity(ragdollEyePos, searchRadius, self._PotentialExecutioners,
                canBeExecutedBy)
            if IsValid(nearest) then
                self._Executioner = nearest
                self._Executioner:AddEntityRelationship(self, D_HT, MAX) -- init new executioner
            end
        end
    end
end
