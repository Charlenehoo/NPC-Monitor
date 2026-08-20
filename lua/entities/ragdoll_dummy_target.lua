-- AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"

if SERVER then
    local CONSTANTS = include("npc_monitor/constants.lua")
    local helpers = include("npc_monitor/helpers.lua")
    local findNearestEntity = helpers.findNearestEntity
    local getEyePos = helpers.getEyePos

    local PROXY_MODEL = "models/editor/cube_small.mdl"
    local SCALE_1 = 0.03125 -- 1 / 32
    local OFFSET = 50
    local MAX = 99

    local MAX_INIT_DURATION = 0.15
    local EXECUTIONER_REFRESH_INTERVAL = 15
    local EXECUTIONER_SEARCH_INTERVAL = 1.5

    local STATE_TO_SEARCH_RADIUS = {
        falling = 250,
        writhing = 500,
        crawling = 1000,
        reviving = CONSTANTS.NPC_MAX_LOOK_DISTANCE

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

        self._Owner = owner
        self._Ragdoll = ragdoll
        self._CreateTime = CurTime()
        self._LastRefreshTime = CurTime()
        self._LastSearchTime = CurTime()
        self._Executioner = nil

        self._PotentialExecutioners = {}
        self:_TryRefreshPotentialExecutioners()
    end

    local function getRagdollState(ragdoll)
        local thirdPartyMODState = ragdoll:GetNW2Int("Animation_State", -1)
        if thirdPartyMODState == 0 then
            return "dead"
        elseif thirdPartyMODState == 1 then
            return "falling"
        elseif thirdPartyMODState == 2 then
            return "writhing"
        elseif thirdPartyMODState == 3 then
            return "crawling"
        elseif thirdPartyMODState == 4 then
            return "reviving"
        else
            return "init"
        end
    end

    function ENT:Think()
        local now = CurTime()

        local ragdoll = self._Ragdoll
        if not IsValid(ragdoll) then
            self:Remove()
            return
        end

        local ragdollState = getRagdollState(ragdoll)
        if ragdollState == "init" then
            if CurTime() - self._CreateTime > MAX_INIT_DURATION then
                self:Remove()
                return
            end
        elseif ragdollState == "dead" then
            self:Remove()
            return
        end

        local ragdollEyePos = helpers.getEyePos(ragdoll)

        local function canBeExecutedBy(npc)
            if not IsValid(npc) then return false end
            if not npc:TestPVS(ragdollEyePos) then return false end
            if not npc:IsInViewCone(ragdollEyePos) then return false end
            if not npc:IsLineOfSightClear(ragdollEyePos) then return false end
            return true
        end

        if self._Executioner then
            if canBeExecutedBy(self._Executioner) then
                local shootPos = self._Executioner:GetShootPos() or self._Executioner:GetPos()
                local dir = (shootPos - ragdollEyePos):Normalize() -- from ragdollEyePos point to shootPos

                self:SetPos(ragdollEyePos + dir * OFFSET)
                self:SetAngles(dir:Angle())

                return -- happy path early return
            else
                if IsValid(self._Executioner) then
                    self._Executioner:AddEntityRelationship(self, D_NU, MAX)
                end
                self._Executioner = nil
            end
        end

        -- not self._Executioner
        if now - self._LastRefreshTime > EXECUTIONER_REFRESH_INTERVAL then
            self._LastRefreshTime = now

            self:_TryRefreshPotentialExecutioners()
            if table.IsEmpty(self._PotentialExecutioners) then
                self:Remove()
                return
            end
        end

        if now - self._LastSearchTime > EXECUTIONER_SEARCH_INTERVAL then
            self._LastSearchTime = now

            local searchRadius = STATE_TO_SEARCH_RADIUS[ragdollState]
            if searchRadius then
                self._Executioner = findNearestEntity(ragdollEyePos, searchRadius, self._PotentialExecutioners,
                    canBeExecutedBy)
                self._Executioner:AddEntityRelationship(self, D_HT, MAX) -- init new executioner
            end
        end
    end
end
