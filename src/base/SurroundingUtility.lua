----------------------------------------------------------------------------
--  Bot 周围状态信息模块
--  功能：集中处理 Bot 自身状态、附近单位、环境阻挡等周边信息
--  来源：从 Utility.lua 重构提取
----------------------------------------------------------------------------
local surroundingModule = {}

---------------------------------------------------------------------------------------------------
--  Bot 自身状态检测
---------------------------------------------------------------------------------------------------

-- 检测英雄与目标位置之间是否有树木阻挡
function surroundingModule.AreTreesBetween(loc, r)
    local npcBot = GetBot()

    local trees = npcBot:GetNearbyTrees(GetUnitToLocationDistance(npcBot, loc))
    for _, tree in pairs(trees) do
        local x = GetTreeLocation(tree)
        local y = npcBot:GetLocation()
        local z = loc

        if x ~= y then
            local a = 1
            local b = 1
            local c

            if x.x - y.x == 0 then
                b = 0
                c = -x.x
            else
                a = -(x.y - y.y) / (x.x - y.x)
                c = -(x.y + x.x * a)
            end

            local d = math.abs((a * z.x + b * z.y + c) / math.sqrt(a * a + b * b))
            if d <= r and GetUnitToLocationDistance(npcBot, loc) > surroundingModule.GetDistance(x, loc) + 50 then
                return true
            end
        end
    end
    return false
end

---------------------------------------------------------------------------------------------------
--  附近单位列表
---------------------------------------------------------------------------------------------------

-- 获取某个位置附近的敌方英雄列表
function surroundingModule.GetEnemiesNearLocation(loc, dist)
    if loc == nil then
        return {}
    end

    local Enemies = {}

    for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if (GetUnitToLocationDistance(enemy, loc) < dist) then
            table.insert(Enemies, enemy)
        end
    end

    return Enemies
end

-- 获取某个位置附近的友方英雄列表（基于最后一次看到的信息）
function surroundingModule.GetAlliesNearLocation(loc, dist)
    if loc == nil then
        return {}
    end

    local Allies = {}

    for _, enID in pairs(GetTeamPlayers(GetTeam())) do
        local allyInfo = GetHeroLastSeenInfo(enID)[1]
        if allyInfo ~= nil and allyInfo["location"] ~= nil then
            if IsHeroAlive(enID) and surroundingModule.GetDistance(allyInfo["location"], loc) <= dist and
                (surroundingModule.GetDistance(allyInfo["location"], Vector(0, 0)) > 10) and allyInfo["time_since_seen"] <
                10 then
                table.insert(Allies, enID)
            end
        end
    end

    return Allies
end

-- 从单位列表中找出血量最低的单位
function surroundingModule.GetWeakestUnit(EnemyUnits)
    if EnemyUnits == nil or #EnemyUnits == 0 then
        return nil, 10000
    end

    local WeakestUnit = nil
    local LowestHealth = 10000
    for _, unit in pairs(EnemyUnits) do
        if unit ~= nil and unit:IsAlive() and unit:CanBeSeen() then
            if unit:GetHealth() < LowestHealth then
                LowestHealth = unit:GetHealth()
                WeakestUnit = unit
            end
        end
    end

    return WeakestUnit, LowestHealth
end

-- 从单位列表中找出血量最高的单位
function surroundingModule.GetStrongestUnit(EnemyUnits)
    if EnemyUnits == nil or #EnemyUnits == 0 then
        return nil, 0
    end

    local StrongestUnit = nil
    local HighestHealth = 0
    for _, unit in pairs(EnemyUnits) do
        if unit ~= nil and unit:IsAlive() and unit:CanBeSeen() then
            if unit:GetHealth() > HighestHealth then
                HighestHealth = unit:GetHealth()
                StrongestUnit = unit
            end
        end
    end

    return StrongestUnit, HighestHealth
end

---------------------------------------------------------------------------------------------------
--  敌方状态判定
---------------------------------------------------------------------------------------------------

-- 判断敌方英雄是否处于被控制状态（缠绕、眩晕、妖术）
function surroundingModule.enemyDisabled(npcEnemy)
    if npcEnemy:IsRooted() or npcEnemy:IsStunned() or npcEnemy:IsHexed() then
        return true
    end
    return false
end

-- 判断一个单位是否为敌方单位
function surroundingModule.IsEnemy(hUnit)
    local ourTeam = GetTeam()
    local Team = GetTeamForPlayer(hUnit:GetPlayerID())
    if ourTeam == Team then
        return false
    else
        return true
    end
end

-- 判断英雄是否为肉山（Roshan）
function surroundingModule.IsRoshan(npcTarget)
    return npcTarget ~= nil and npcTarget:IsAlive() and string.find(npcTarget:GetUnitName(), "roshan")
end

-- 检测敌方英雄是否拥有免疫类减益效果
function surroundingModule.HasImmuneDebuff(npcEnemy)
    return npcBot:HasModifier("modifier_abaddon_borrowed_time") or
        npcEnemy:HasModifier("modifier_winter_wyvern_winters_curse") or
        npcEnemy:HasModifier("modifier_obsidian_destroyer_astral_imprisonment_prison") or
        npcEnemy:HasModifier("modifier_winter_wyvern_winters_curse_aura")
end

-- 判断目标是否为有效的敌方英雄目标
function surroundingModule.IsValidTarget(npcTarget)
    return npcTarget ~= nil and npcTarget:IsAlive() and npcTarget:IsHero()
end

-- 判断目标是否为可疑的幻象
function surroundingModule.IsSuspiciousIllusion(npcTarget)
    local bot = GetBot()
    if npcTarget:IsIllusion() or npcTarget:HasModifier("modifier_illusion") or
        npcTarget:HasModifier("modifier_phantom_lancer_doppelwalk_illusion") or
        npcTarget:HasModifier("modifier_phantom_lancer_juxtapose_illusion") or
        npcTarget:HasModifier("modifier_darkseer_wallofreplica_illusion") or
        npcTarget:HasModifier("modifier_terrorblade_conjureimage") then
        return true
    else
        if GetGameMode() ~= GAMEMODE_MO then
            if npcTarget:GetTeam() ~= bot:GetTeam() then
                local TeamMember = GetTeamPlayers(GetTeam())
                for i = 1, #TeamMember do
                    local ally = GetTeamMember(i)
                    if ally ~= nil and ally:GetUnitName() == npcTarget:GetUnitName() then
                        return true
                    end
                end
            end
        end
        return false
    end
end

---------------------------------------------------------------------------------------------------
--  内部辅助函数
---------------------------------------------------------------------------------------------------

function surroundingModule.GetDistance(a, b)
    local x1 = a.x
    local x2 = b.x
    local y1 = a.y
    local y2 = b.y
    return math.sqrt(math.pow((y2 - y1), 2) + math.pow((x2 - x1), 2))
end

return surroundingModule
