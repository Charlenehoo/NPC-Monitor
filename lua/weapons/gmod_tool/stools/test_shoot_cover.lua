TOOL.Category = "Debug"

local _testNPC = nil

function TOOL:LeftClick(tr)
    local clickEnt = tr.Entity
    if not IsValid(clickEnt) or not clickEnt:IsNPC() then return false end

    if IsValid(_testNPC) and _testNPC ~= clickEnt then
        _testNPC:Remove()
    end

    _testNPC = clickEnt

    return true
end

function TOOL:RightClick(tr)
    if not IsValid(_testNPC) then
        return false
    end

    _testNPC:SetEnemy(self:GetOwner())
    _testNPC:UpdateEnemyMemory(self:GetOwner(), self:GetOwner():GetPos())
    _testNPC:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
end
