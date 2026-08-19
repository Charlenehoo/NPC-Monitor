-- AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"

if SERVER then
    local PROXY_MODEL = "models/editor/cube_small.mdl"
    local SCALE_1 = 0.03125 -- 1 / 32
    local OFFSET = 48
    local MAX = 99

    local MAX_INIT_DURATION = 0.15

    function ENT:Initialize()
        self:SetModel(PROXY_MODEL)
        self:SetModelScale(SCALE_1)
        self:SetNPCClass(CLASS_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetCollisionGroup(COLLISION_GROUP_NONE)
        self:SetNoDraw(true)
    end

    function ENT:Init(owner, ragdoll)
        if not IsValid(owner) then return end

        self._PotentialExecutioners = {}
        NPCMonitor.ForEachActiveNPC(function(npc)
            if not IsValid(npc) then return end

            local d, _ = npc:Disposition(owner)
            if d == D_HT or d == D_FR then
                self._PotentialExecutioners[npc] = true
            end
        end)

        self._Ragdoll = ragdoll
        self._CreateTime = CurTime()
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
        if CurTime() - self._CreateTime > MAX_INIT_DURATION and table.IsEmpty(self._PotentialExecutioners) then
            self:Remove()
            return
        end

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
        elseif ragdollState == "falling" then
        end
    end
end
