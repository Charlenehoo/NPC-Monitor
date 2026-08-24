AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"

if CLIENT then return end

local CONSTANTS                     = include("npc_monitor/config/constants.lua")
local log                           = include("npc_monitor/logging/log.lua")
local helpers                       = include("npc_monitor/helpers.lua")
local findNearestEntity             = helpers.findNearestEntity
local findRandomEntity              = helpers.findRandomEntity
local getEyePos                     = helpers.getEyePos
local getRagdollState               = helpers.getRagdollState

local BONE_FALLBACK_ORDER           = include("npc_monitor/config/bones.lua")

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
-- local REPOSITION_OFFSET_RANGE       = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_OFFSET_RANGE

-- 定期重置回最高优先级策略的时间间隔（秒）
local POSITION_RESET_INTERVAL       = CONSTANTS.RAGDOLL_DUMMY.POSITION_RESET_INTERVAL
local BROAD_CAST_INTERVAL           = 9

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

function ENT:IsPotentialExecutioner(npc)
    if not IsValid(npc) then return false end

    -- 新增：如果 ragdoll 已死或 dummy 自身处于 dead 监控状态，则不作为潜在执行者目标
    if self._LastRagdollState == "dead" then return false end

    local potentials = self._PotentialExecutioners or {}
    for _, p in ipairs(potentials) do
        if p == npc then
            return true
        end
    end
    return false
end

function ENT:_TryReposition(activePos)
    local ragdoll = self._Ragdoll
    local filter = { self }
    if IsValid(ragdoll) then
        table.insert(filter, ragdoll)
    end

    local maxAttempts = 100

    -- 圆环柱参数：优先使用新配置，否则回退到旧的水平偏移范围
    local rMin = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_RADIUS_MIN
    local rMax = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_RADIUS_MAX
    local hMin = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_HEIGHT_MIN
    local hMax = CONSTANTS.RAGDOLL_DUMMY.REPOSITION_HEIGHT_MAX

    for _ = 1, maxAttempts do
        -- 随机角度 0 ~ 2π
        local theta = math.random() * 2 * math.pi
        -- 随机半径 rMin ~ rMax
        local r = rMin + (rMax - rMin) * math.random()
        -- 随机高度 hMin ~ hMax
        local z = hMin + (hMax - hMin) * math.random()

        local offset = Vector(r * math.cos(theta), r * math.sin(theta), z)
        local candidatePos = activePos + offset

        local tr = util.TraceLine({
            start = activePos,
            endpos = candidatePos,
            filter = filter,
            mask = MASK_SOLID
        })

        if not tr.Hit then
            self:SetPos(candidatePos)
            return
        end
    end

    -- 没有找到可通过射线检查的随机点，退回到活动位置
    self:SetPos(activePos)
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
    -- 第一个策略始终是眼睛位置
    self._PositionStrategies = {
        { name = "eye", getPos = function(ragdoll) return getEyePos(ragdoll) end },
    }

    -- 根据准备好的骨骼顺序表构建后续策略
    for _, boneName in ipairs(BONE_FALLBACK_ORDER) do
        local bone = boneName -- 避免闭包捕获循环变量
        table.insert(self._PositionStrategies, {
            name = bone,
            getPos = function(ragdoll)
                local boneID = ragdoll:LookupBone(bone)
                if boneID then
                    local pos = ragdoll:GetBonePosition(boneID)
                    if pos then return pos end
                end
                return nil -- 骨骼不存在或获取失败
            end
        })
    end

    self._PositionStrategyIndex = 1
    self._PositionStrategyFailCount = 0
    self._LastPositionStrategyResetTime = now
    self._LastBroadCastTime = now
    self._LastRagdollState = nil
    self._DeadRemoveTimer = nil
end

function ENT:_GetActivePosition()
    local ragdoll = self._Ragdoll
    if not IsValid(ragdoll) then return nil end

    local strategies = self._PositionStrategies
    local index = self._PositionStrategyIndex or 1
    local maxAttempts = #strategies
    local attempts = 0

    -- 从当前索引开始，依次尝试所有策略，跳过返回 nil 的
    while attempts < maxAttempts do
        local strategy = strategies[index]
        if strategy then
            local pos = strategy.getPos(ragdoll)
            if pos then
                self._PositionStrategyIndex = index
                return pos
            end
        end
        -- 当前策略无效，尝试下一个（循环）
        index = index % maxAttempts + 1
        attempts = attempts + 1
    end

    -- 所有策略都失败，回退到实体坐标
    self._PositionStrategyIndex = 1
    return ragdoll:GetPos()
end

function ENT:_AdvancePositionStrategy()
    if self._PositionStrategyIndex < #self._PositionStrategies then
        self._PositionStrategyIndex = self._PositionStrategyIndex + 1
        log.trace(self, "Position strategy degraded to: ", self._PositionStrategies[self._PositionStrategyIndex].name)
    else
        log.trace(self, "All position strategies exhausted, staying at: ",
            self._PositionStrategies[self._PositionStrategyIndex].name)
    end
    self._PositionStrategyFailCount = 0
end

function ENT:_ResetPositionStrategy()
    if self._PositionStrategyIndex ~= 1 then
        self._PositionStrategyIndex = 1
        self._PositionStrategyFailCount = 0
        self._LastPositionStrategyResetTime = CurTime()
        log.trace(self, "Position strategy reset to eye")
    end
end

function ENT:_GetRagdollState(ragdoll)
    local stateName = getRagdollState(ragdoll)

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

-- 维持检查：执行者已选定，验证其是否仍能有效攻击 dummy
function ENT:_CanSustainExecution(npc)
    if not IsValid(npc) then return false end
    if npc:GetEnemy() ~= self then return false end               -- 已失去目标
    if npc:HasCondition(COND.WEAPON_BLOCKED_BY_FRIEND) then return false end
    if not npc:HasCondition(COND.SEE_ENEMY) then return false end -- 看不到 enemy
    return true
end

function ENT:Think()
    local now = CurTime()

    local ragdoll = self._Ragdoll
    if not IsValid(ragdoll) then
        if self._DeadRemoveTimer then
            timer.Remove(self._DeadRemoveTimer)
            self._DeadRemoveTimer = nil
        end
        self:Remove()
        return
    end

    local previousRagdollState = self._LastRagdollState
    local ragdollState = self:_GetRagdollState(ragdoll)

    if ragdollState == "dead" then
        if previousRagdollState ~= "dead" then
            -- 刚进入 dead 状态：取消当前执行者，并启动延迟移除定时器
            log.info(self, "Ragdoll entered dead state, starting remove timer")
            self:_CancelExecutioner()

            local timerName = CONSTANTS.PLUGIN_NAME .. self:EntIndex() .. "_" .. CurTime() .. "_" .. math.random()
            self._DeadRemoveTimer = timerName
            timer.Create(timerName, CONSTANTS.RAGDOLL_DUMMY.DEAD_REMOVE_DELAY, 1, function()
                if IsValid(self) then
                    self:Remove()
                end
            end)
        end
        return
    end

    -- ragdoll 非 dead：如果之前有 dead 定时器，则取消它（复活）
    if self._DeadRemoveTimer then
        timer.Remove(self._DeadRemoveTimer)
        self._DeadRemoveTimer = nil
        log.info(self, "Ragdoll revived, cancelled dead remove timer")
    end

    -- 获取当前策略下的活动位置
    local activePos = self:_GetActivePosition()
    if not activePos then
        -- 无法获取有效位置（理论上不会发生，但防止 nil）
        return
    end

    -- 执行者存在时的验证与定位
    if IsValid(self._Executioner) then
        if now - self._LastExecutionerCheckTime > EXECUTIONER_VALIDATE_INTERVAL then
            self._LastExecutionerCheckTime = now

            local exec = self._Executioner
            if self:_CanSustainExecution(exec) then
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
            local dir = (shootPos - activePos):GetNormalized()
            self:SetPos(activePos + dir * OFFSET)
            self:SetAngles(dir:Angle())
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
            -- 进入检查：手动计算可见性
            local function canEnterExecution(npc)
                if not IsValid(npc) then return false end
                if not npc:TestPVS(activePos) then return false end
                if not npc:IsInViewCone(activePos) then return false end
                if not npc:IsLineOfSightClear(activePos) then return false end
                return true
            end

            local chosen = findRandomEntity(activePos, searchRadius, self._PotentialExecutioners, canEnterExecution)
            if IsValid(chosen) then
                self._Executioner = chosen
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

    if now - self._LastBroadCastTime > BROAD_CAST_INTERVAL then
        self._LastBroadCastTime = now
        for _, exec in ipairs(self._PotentialExecutioners) do
            NPCMonitor.TryControlNPC(exec)
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
