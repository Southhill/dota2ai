----------------------------------------------------------------------------
--	CDOTA_Bot_Script 扩展方法
--	通过扩展 CDOTA_Bot_Script 原型，为所有 bot 单位对象添加便捷方法
--	每个 Lua 状态需加载一次（通过 Utility.lua 自动引入）
--
--	来源：从 Utility.lua 重构提取
----------------------------------------------------------------------------

-- 计算英雄的综合状态因子（血量百分比 + 蓝量百分比）
function CDOTA_Bot_Script:GetFactor()
    return self:GetHealth() / self:GetMaxHealth() + self:GetMana() / self:GetMaxMana()
end

----------------------------------------------------------------------------------------------------
-- 向量相关函数
-- BOT EXPERIMENT 的代码，来自 http://steamcommunity.com/sharedfiles/filedetails/?id=837040016
----------------------------------------------------------------------------------------------------

function CDOTA_Bot_Script:GetForwardVector()
    local radians = self:GetFacing() * math.pi / 180
    local forward_vector = Vector(math.cos(radians), math.sin(radians))
    return forward_vector
end

-- 判断英雄是否面向某个目标
function CDOTA_Bot_Script:IsFacingUnit(hTarget, degAccuracy)
    local direction = (hTarget:GetLocation() - self:GetLocation()):Normalized()
    local dot = direction:Dot(self:GetForwardVector())
    local radians = degAccuracy * math.pi / 180
    return dot > math.cos(radians)
end

function CDOTA_Bot_Script:GetXUnitsTowardsLocation(vLocation, nUnits)
    local direction = (vLocation - self:GetLocation()):Normalized()
    return self:GetLocation() + direction * nUnits
end

-- 获取英雄前方 nUnits 距离的坐标
function CDOTA_Bot_Script:GetXUnitsInFront(nUnits)
    return self:GetLocation() + self:GetForwardVector() * nUnits
end

-- 获取英雄后方 nUnits 距离的坐标
function CDOTA_Bot_Script:GetXUnitsInBehind(nUnits)
    return self:GetLocation() - self:GetForwardVector() * nUnits
end

-- 判断英雄是否为肉山（Roshan）
function CDOTA_Bot_Script:IsRoshan()
    return string.find(self:GetUnitName(), "roshan")
end
