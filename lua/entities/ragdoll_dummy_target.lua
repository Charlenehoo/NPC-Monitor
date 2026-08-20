-- AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"

if SERVER then
    local CONSTANTS = include("npc_monitor/constants.lua")
    local helpers = include("npc_monitor/helpers.lua")
    local findNearestEntity = helpers.findNearestEntity

    local PROXY_MODEL = "models/editor/cube_small.mdl"
    local SCALE_1 = 0.03125 -- 1 / 32
    local OFFSET = 50
    local MAX = 99

    local MAX_INIT_DURATION = 0.15
    local REFRESH_INTERVAL = 3

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
        if not IsValid(owner) then return end

        local newPotentialExecutioners = {}
        NPCMonitor.ForEachActiveNPC(function(npc)
            if not IsValid(npc) then return end

            local d, _ = npc:Disposition(owner)
            if d == D_HT or d == D_FR then
                table.insert(newPotentialExecutioners, npc)
            end
        end)

        if newPotentialExecutioners and #newPotentialExecutioners ~= 0 then
            self._PotentialExecutioners = newPotentialExecutioners
        end
    end

    function ENT:Init(owner, ragdoll)
        if not IsValid(owner) then return end
        if not IsValid(ragdoll) then return end

        self._Owner = owner
        self._Ragdoll = ragdoll
        self._CreateTime = CurTime()
        self._LastRefreshTime = CurTime()
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
        if table.IsEmpty(self._PotentialExecutioners) then
            if CurTime() - self._CreateTime > MAX_INIT_DURATION then
                self:Remove()
                return
            else
                self:_TryRefreshPotentialExecutioners()
            end
        end

        if CurTime() - self._LastRefreshTime > REFRESH_INTERVAL then
            self._LastRefreshTime = CurTime()
            self:_TryRefreshPotentialExecutioners()
        end

        local ragdoll = self._Ragdoll
        if not IsValid(ragdoll) then
            self:Remove()
            return
        end

        local ragdollState = getRagdollState(ragdoll)
        local ragdollEyePos = helpers.getEyePos(ragdoll)

        if not self._Executioner then
            local searchRadius
            if ragdollState == "init" then
                if CurTime() - self._CreateTime > MAX_INIT_DURATION then
                    self:Remove()
                    return
                end
            elseif ragdollState == "dead" then
                self:Remove()
                return
            elseif ragdollState == "falling" then
            elseif ragdollState == "writhing" then
                searchRadius = 500
            elseif ragdollState == "crawling" then
                searchRadius = 1000
            elseif ragdollState == "reviving" then
                searchRadius = CONSTANTS.NPC_MAX_LOOK_DISTANCE
            end

            if searchRadius then
                self._Executioner = findNearestEntity(ragdollEyePos, searchRadius, self._PotentialExecutioners,
                    function(npc)
                        if not IsValid(npc) then return false end
                        if not npc:TestPVS(ragdollEyePos) then return false end
                        if not npc:IsInViewCone(ragdollEyePos) then return false end
                        if not npc:IsLineOfSightClear(ragdollEyePos) then return false end
                        return true
                    end)
            end
        end

        if self._Executioner then
            local shootPos = self._Executioner:GetShootPos() or self._Executioner:GetPos()
            local dir = (shootPos - ragdollEyePos):Normalize() -- from ragdollEyePos point to shootPos

            self:SetPos(ragdollEyePos + dir * OFFSET)
            self:SetAngles(dir:Angle())
        else
            self:SetPos(ragdollEyePos)
        end
    end
end
