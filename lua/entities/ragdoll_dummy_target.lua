AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"

if CLIENT then return end

local CONSTANTS                     = include("npc_monitor/config/constants.lua")
local log                           = include("npc_monitor/logging/log.lua")
local helpers                       = include("npc_monitor/helpers.lua")
local findNearestEntity             = helpers.findNearestEntity
local getEyePos                     = helpers.getEyePos
local getPelvisPos                  = helpers.getPelvisPos -- 新增引入

local PROXY_MODEL                   = CONSTANTS.RAGDOLL_DUMMY.PROXY_MODEL
local SCALE_1                       = CONSTANTS.RAGDOLL_DUMMY.SCALE
local OFFSET                        = CONSTANTS.RAGDOLL_DUMMY.OFFSET
local MAX                           = CONSTANTS.RAGDOLL_DUMMY.RELATIONSHIP_MAX_PRIORITY

local MAX_INIT_DURATION             = CONSTANTS.RAGDOLL_DUMMY.MAX_INIT_DURATION
local EXECUTIONER_SEARCH_INTERVAL   = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_SEARCH_INTERVAL
local EXECUTIONER_VALIDATE_INTERVAL = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_VALIDATE_INTERVAL
local EXECUTIONER_MAX_FAIL_COUNT    = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_MAX_FAIL_COUNT
local EXECUTIONER_TIMEOUT           = CONSTANTS.RAGDOLL_DUMMY.EXECUTIONER_TIMEOUT

local STATE_TO_SEARCH_RADIUS        = CONSTANTS.RAGDOLL_DUMMY.STATE_TO_SEARCH_RADIUS

local REPOSITION_INTERVAL           = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_INTERVAL
local REPOSITION_OFFSET_RANGE       = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_OFFSET_RANGE

-- 定期重置回最高优先级策略的时间间隔（秒）
local POSITION_RESET_INTERVAL       = CONSTANTS.RAGDOLL_DUMMY.POSITION_RESET_INTERVAL

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

function ENT:_TryReposition(activePos)
    local offset = Vector(
        math.random(-REPOSITION_OFFSET_RANGE.x, REPOSITION_OFFSET_RANGE.x),
        math.random(-REPOSITION_OFFSET_RANGE.y, REPOSITION_OFFSET_RANGE.y),
        math.random(-REPOSITION_OFFSET_RANGE.z, REPOSITION_OFFSET_RANGE.z)
    )
    self:SetPos(activePos + offset)
end

function ENT:Init(owner, ragdoll)
    if not IsValid(owner) then return end
    if not IsValid(ragdoll) then return end

    local now = CurTime()

    self._Owner = owner
    self._Ragdoll = ragdoll
    self._LastSearchTime = now + MAX_INIT_DURATION
    self._LastExecutionerCheckTime = now - 1
    self._ExecutionerFailCount = 0
    self._Executioner = nil
    self._ExecutionerAssignedTime = nil

    self._PotentialExecutioners = {}
    self:_TryRefreshPotentialExecutioners()

    self._LastRepositionTime = 0
    self._RepositionAttempt = 0

    -- 位置提取策略初始化
    self._PositionStrategies = {
        { name = "eye",    getPos = function(ragdoll) return getEyePos(ragdoll) end },
        { name = "pelvis", getPos = function(ragdoll) return getPelvisPos(ragdoll) end },
    }
    self._PositionStrategyIndex = 1
    self._PositionStrategyFailCount = 0
    self._LastPositionStrategyResetTime = now
end

function ENT:_GetActivePosition()
    local ragdoll = self._Ragdoll
    if not IsValid(ragdoll) then return nil end

    local strategy = self._PositionStrategies[self._PositionStrategyIndex]
    if strategy then
        return strategy.getPos(ragdoll)
    else
        return ragdoll:GetPos()
    end
end

function ENT:_AdvancePositionStrategy()
    if self._PositionStrategyIndex < #self._PositionStrategies then
        self._PositionStrategyIndex = self._PositionStrategyIndex + 1
        log.debug(self, "Position strategy degraded to: ", self._PositionStrategies[self._PositionStrategyIndex].name)
    else
        log.debug(self, "All position strategies exhausted, staying at: ",
            self._PositionStrategies[self._PositionStrategyIndex].name)
    end
    self._PositionStrategyFailCount = 0
end

function ENT:_ResetPositionStrategy()
    if self._PositionStrategyIndex ~= 1 then
        self._PositionStrategyIndex = 1
        self._PositionStrategyFailCount = 0
        self._LastPositionStrategyResetTime = CurTime()
        log.debug(self, "Position strategy reset to eye")
    end
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

    -- thirdPartyMODState is not that accurate, so fix it with raw data
    local hp_c = ragdoll.Hp_c
    local hp_d = ragdoll.Hp_d
    if stateName == "falling" then
        if hp_c ~= nil and hp_c > 0 and (hp_d == nil or hp_d > 0) then
            if ragdoll.IsWrithing or ragdoll.IsTwitching then
                stateName = "writhing"
            elseif ragdoll.IsReviving then
                stateName = "reviving"
            else
                stateName = "crawling"
            end
        end
    end

    -- 按照语义是 dead, 但是由于这个第三方 MOD 实在是太不靠谱, 我还是用血量判断好了
    local JUST_FOR_SURE_OFFSET = -100
    if stateName == "dead" then
        if not ((hp_c ~= nil and hp_c <= JUST_FOR_SURE_OFFSET) or (hp_d ~= nil and hp_d <= JUST_FOR_SURE_OFFSET)) then
            stateName = "writhing"
        end
    end

    local lastState = self._LastRagdollState
    if lastState ~= stateName then
        log.trace(ragdoll, "RagdollState: ", lastState or "(none)", " -> ", stateName)
        self._LastRagdollState = stateName
        -- ragdoll 状态变化时，重置位置策略到最高优先级
        self:_ResetPositionStrategy()
    end

    return stateName
end

function ENT:_CancelExecutioner()
    local exec = self._Executioner
    if IsValid(exec) then
        exec:AddEntityRelationship(self, D_NU, MAX)
        if exec:GetEnemy() == self then
            exec:ClearEnemyMemory()
            exec:SetEnemy(NULL)
        end
    end
    self._Executioner = nil
    self._ExecutionerFailCount = 0
    self._ExecutionerAssignedTime = nil
    self._LastSearchTime = 0
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

    -- 获取当前策略下的活动位置
    local activePos = self:_GetActivePosition()
    if not activePos then
        -- 无法获取有效位置（理论上不会发生，但防止 nil）
        return
    end

    local function canBeExecutedBy(npc)
        if not IsValid(npc) then return false end
        if not npc:TestPVS(activePos) then return false end
        if not npc:IsInViewCone(activePos) then return false end
        if not npc:IsLineOfSightClear(activePos) then return false end
        return true
    end

    -- 执行者存在时的验证与定位
    if IsValid(self._Executioner) then
        if now - self._LastExecutionerCheckTime > EXECUTIONER_VALIDATE_INTERVAL then
            self._LastExecutionerCheckTime = now

            local exec = self._Executioner
            if canBeExecutedBy(exec) then
                self._ExecutionerFailCount = 0

                if now - self._ExecutionerAssignedTime > EXECUTIONER_TIMEOUT then
                    self:_CancelExecutioner()
                    -- 超时也考虑降级，可能是当前位置无法持续维持
                    self:_AdvancePositionStrategy()
                end
            else
                self._ExecutionerFailCount = self._ExecutionerFailCount + 1
                if self._ExecutionerFailCount >= EXECUTIONER_MAX_FAIL_COUNT then
                    self:_CancelExecutioner()
                    -- 验证连续失败，很可能当前参考点失效，降级
                    self:_AdvancePositionStrategy()
                end
            end
        end

        if IsValid(self._Executioner) then
            local shootPos = self._Executioner:GetShootPos() or self._Executioner:GetPos()
            local dir = (activePos - shootPos):GetNormalized()
            self:SetPos(shootPos + dir * OFFSET)
            self:SetAngles(dir:GetNegated():Angle())
            return
        end
    end

    -- 搜索阶段
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
            local nearest = findNearestEntity(activePos, searchRadius, self._PotentialExecutioners, canBeExecutedBy)
            if IsValid(nearest) then
                self._Executioner = nearest
                self._ExecutionerAssignedTime = CurTime()
                self._Executioner:AddEntityRelationship(self, D_HT, MAX)
                -- 搜索成功，重置当前策略失败计数
                self._PositionStrategyFailCount = 0
            else
                -- 搜索失败，累计当前策略失败
                self._PositionStrategyFailCount = self._PositionStrategyFailCount + 1
                if self._PositionStrategyFailCount >= EXECUTIONER_MAX_FAIL_COUNT then
                    self:_AdvancePositionStrategy()
                    -- 降级后等待下一搜索周期再尝试，避免同帧重复搜索
                end
            end
        end
    end

    -- 重定位（使用当前活动位置）
    if now - self._LastRepositionTime > REPOSITION_INTERVAL then
        self._LastRepositionTime = now
        self:_TryReposition(activePos)
    end

    -- 定期重置策略到最高优先级（给眼睛位置重新尝试的机会）
    if now - self._LastPositionStrategyResetTime > POSITION_RESET_INTERVAL then
        self:_ResetPositionStrategy()
    end
end
