----------------------------------------------------------------------------
--  英雄级单位的方法集合
----------------------------------------------------------------------------
local heroUnitUtility = {}

---------------------------------------------------------------------------------------------------
--  Bot 自身状态检测
---------------------------------------------------------------------------------------------------

-- 检测英雄是否卡住（长时间在同一个位置移动但无法前进）
function heroUnitUtility.IsStuck(npcBot)
    if npcBot.stuckLoc ~= nil and npcBot.stuckTime ~= nil then
        local attackTarget = npcBot:GetAttackTarget()
        local EAd = GetUnitToUnitDistance(npcBot, GetAncient(GetOpposingTeam()))
        local TAd = GetUnitToUnitDistance(npcBot, GetAncient(GetTeam()))
        local Et = npcBot:GetNearbyTowers(450, true)
        local At = npcBot:GetNearbyTowers(450, false)
        if npcBot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and attackTarget == nil and EAd > 2200 and TAd >
            2200 and #Et == 0 and #At == 0 and DotaTime() > npcBot.stuckTime + 5.0 and
            GetUnitToLocationDistance(npcBot, npcBot.stuckLoc) < 25 then
            print(npcBot:GetUnitName() .. " is stuck")
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------------------------------
--  环境阻挡检测
---------------------------------------------------------------------------------------------------

-- 检测英雄与目标位置之间是否有树木阻挡
function heroUnitUtility.AreTreesBetween(loc, r)
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
            if d <= r and GetUnitToLocationDistance(npcBot, loc) > heroUnitUtility.GetDistance(x, loc) + 50 then
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
function heroUnitUtility.GetEnemiesNearLocation(loc, dist)
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
function heroUnitUtility.GetAlliesNearLocation(loc, dist)
    if loc == nil then
        return {}
    end

    local Allies = {}

    for _, enID in pairs(GetTeamPlayers(GetTeam())) do
        local allyInfo = GetHeroLastSeenInfo(enID)[1]
        if allyInfo ~= nil and allyInfo["location"] ~= nil then
            if IsHeroAlive(enID) and heroUnitUtility.GetDistance(allyInfo["location"], loc) <= dist and
                (heroUnitUtility.GetDistance(allyInfo["location"], Vector(0, 0)) > 10) and allyInfo["time_since_seen"] <
                10 then
                table.insert(Allies, enID)
            end
        end
    end

    return Allies
end

-- 从单位列表中找出血量最低的单位
function heroUnitUtility.GetWeakestUnit(EnemyUnits)
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
function heroUnitUtility.GetStrongestUnit(EnemyUnits)
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
function heroUnitUtility.enemyDisabled(npcEnemy)
    if npcEnemy:IsRooted() or npcEnemy:IsStunned() or npcEnemy:IsHexed() then
        return true
    end
    return false
end

-- 判断一个单位是否为敌方单位
function heroUnitUtility.IsEnemy(hUnit)
    local ourTeam = GetTeam()
    local Team = GetTeamForPlayer(hUnit:GetPlayerID())
    if ourTeam == Team then
        return false
    else
        return true
    end
end

-- 判断英雄是否为肉山（Roshan）
function heroUnitUtility.IsRoshan(npcTarget)
    return npcTarget ~= nil and npcTarget:IsAlive() and string.find(npcTarget:GetUnitName(), "roshan")
end

-- 检测敌方英雄是否拥有免疫类减益效果
local ModifierImmuneDebuff = require(GetScriptDirectory() .. "/const/enum").ModifierImmuneDebuff
function heroUnitUtility.HasImmuneDebuff(npcEnemy)
    for _, mod in ipairs(ModifierImmuneDebuff) do
        if npcEnemy:HasModifier(mod) then
            return true
        end
    end
    return false
end

-- 判断目标是否为有效的敌方英雄目标
function heroUnitUtility.IsValidTarget(npcTarget)
    return npcTarget ~= nil and npcTarget:IsAlive() and npcTarget:IsHero()
end

-- 判断目标是否为可疑的幻象
function heroUnitUtility.IsSuspiciousIllusion(npcTarget)
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

-- 检查目标是否有林肯法球/法术反射状态
function heroUnitUtility.HasSphere(npcTarget)
    local modifier = { "modifier_item_sphere", "modifier_item_sphere_target" }
    for _, mod in pairs(modifier) do
        if npcTarget:HasModifier(mod) then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------------------------------
--  施法判定
---------------------------------------------------------------------------------------------------

-- 常规施法判定：目标可见、非魔免、非无敌、无免疫减益
function heroUnitUtility.NCanCast(npcEnemy)
    return npcEnemy:CanBeSeen() and not npcEnemy:IsMagicImmune() and not npcEnemy:IsInvulnerable() and
        not heroUnitUtility.HasImmuneDebuff(npcEnemy)
end

-- 魔免施法判定：等同于 UCanCast（可对魔免目标施法）
function heroUnitUtility.MiCanCast(npcEnemy)
    return heroUnitUtility.UCanCast(npcEnemy)
end

-- 通用施法判定：目标可见、非无敌、无免疫减益、非幻象
function heroUnitUtility.UCanCast(npcEnemy)
    return npcEnemy:CanBeSeen() and not npcEnemy:IsInvulnerable() and not heroUnitUtility.HasImmuneDebuff(npcEnemy) and
        not npcEnemy:IsIllusion()
end

-- 无目标施法：始终返回 true
function heroUnitUtility.CanCastNoTarget()
    return true
end

-- 被动技能施法：始终返回 true
function heroUnitUtility.CanCastPassive()
    return true
end

-- 常规施法判定（可见、非无敌、非幻象、无禁止效果、非魔免）
function heroUnitUtility.NormalCanCast(npcTarget)
    return npcTarget:CanBeSeen() and not npcTarget:IsInvulnerable() and
        not heroUnitUtility.IsSuspiciousIllusion(npcTarget) and
        not heroUnitUtility.HasImmuneDebuff(npcTarget) and not npcTarget:IsMagicImmune()
end

-- Roshan 施法判定（无视魔免）
function heroUnitUtility.RoshanCanCast(npcTarget)
    return npcTarget:CanBeSeen() and not npcTarget:IsInvulnerable() and
        not heroUnitUtility.IsSuspiciousIllusion(npcTarget) and
        not heroUnitUtility.HasImmuneDebuff(npcTarget)
end

-- 大招施法判定（含林肯检测）
function heroUnitUtility.UltimateCanCast(npcTarget)
    return npcTarget:CanBeSeen() and not npcTarget:IsInvulnerable() and
        not heroUnitUtility.IsSuspiciousIllusion(npcTarget) and
        not heroUnitUtility.HasImmuneDebuff(npcTarget) and not heroUnitUtility.HasSphere(npcTarget)
end

-- AOE 施法判定（不检测幻象和林肯）
function heroUnitUtility.AoeCanCast(npcTarget)
    return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and
        not npcTarget:IsInvulnerable() and
        not heroUnitUtility.HasImmuneDebuff(npcTarget)
end

-- 是否应该使用tp
function heroUnitUtility.ShouldTP(npcTarget)
    local tpLoc = nil
    local mode = npcTarget:GetActiveMode()
    local modDesire = npcTarget:GetActiveModeDesire()
    local botLoc = npcTarget:GetLocation()
    local enemies = utility.GetNearbyVisibleHeroes(npcTarget, 1600, true, BOT_MODE_NONE)
    if mode == BOT_MODE_LANING and #enemies == 0 then
        local assignedLane = npcTarget:GetAssignedLane()
        if assignedLane == LANE_TOP then
            local botAmount = GetAmountAlongLane(LANE_TOP, botLoc)
            local laneFront = GetLaneFrontAmount(myTeam, LANE_TOP, false)
            if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then
                tpLoc = GetLaningTPLocation(LANE_TOP)
            end
        elseif assignedLane == LANE_MID then
            local botAmount = GetAmountAlongLane(LANE_MID, botLoc)
            local laneFront = GetLaneFrontAmount(myTeam, LANE_MID, false)
            if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then
                tpLoc = GetLaningTPLocation(LANE_MID)
            end
        elseif assignedLane == LANE_BOT then
            local botAmount = GetAmountAlongLane(LANE_BOT, botLoc)
            local laneFront = GetLaneFrontAmount(myTeam, LANE_BOT, false)
            if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then
                tpLoc = GetLaningTPLocation(LANE_BOT)
            end
        end
    elseif mode == BOT_MODE_DEFEND_TOWER_TOP and modDesire >= BOT_MODE_DESIRE_MODERATE and #enemies == 0 then
        local botAmount = GetAmountAlongLane(LANE_TOP, botLoc)
        local laneFront = GetLaneFrontAmount(myTeam, LANE_TOP, false)
        if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then
            tpLoc = GetDefendTPLocation(LANE_TOP)
        end
    elseif mode == BOT_MODE_DEFEND_TOWER_MID and modDesire >= BOT_MODE_DESIRE_MODERATE and #enemies == 0 then
        local botAmount = GetAmountAlongLane(LANE_MID, botLoc)
        local laneFront = GetLaneFrontAmount(myTeam, LANE_MID, false)
        if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then
            tpLoc = GetDefendTPLocation(LANE_MID)
        end
    elseif mode == BOT_MODE_DEFEND_TOWER_BOT and modDesire >= BOT_MODE_DESIRE_MODERATE and #enemies == 0 then
        local botAmount = GetAmountAlongLane(LANE_BOT, botLoc)
        local laneFront = GetLaneFrontAmount(myTeam, LANE_BOT, false)
        if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then
            tpLoc = GetDefendTPLocation(LANE_BOT)
        end
    elseif mode == BOT_MODE_PUSH_TOWER_TOP and modDesire >= BOT_MODE_DESIRE_MODERATE and #enemies == 0 then
        local botAmount = GetAmountAlongLane(LANE_TOP, botLoc)
        local laneFront = GetLaneFrontAmount(myTeam, LANE_TOP, false)
        if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then
            tpLoc = GetPushTPLocation(LANE_TOP)
        end
    elseif mode == BOT_MODE_PUSH_TOWER_MID and modDesire >= BOT_MODE_DESIRE_MODERATE and #enemies == 0 then
        local botAmount = GetAmountAlongLane(LANE_MID, botLoc)
        local laneFront = GetLaneFrontAmount(myTeam, LANE_MID, false)
        if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then
            tpLoc = GetPushTPLocation(LANE_MID)
        end
    elseif mode == BOT_MODE_PUSH_TOWER_BOT and modDesire >= BOT_MODE_DESIRE_MODERATE and #enemies == 0 then
        local botAmount = GetAmountAlongLane(LANE_BOT, botLoc)
        local laneFront = GetLaneFrontAmount(myTeam, LANE_BOT, false)
        if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then
            tpLoc = GetPushTPLocation(LANE_BOT)
        end
    elseif mode == BOT_MODE_DEFEND_ALLY and modDesire >= BOT_MODE_DESIRE_MODERATE and
        role.CanBeSupport(npcTarget:GetUnitName()) == true and #enemies == 0 then
        local target = npcTarget:GetTarget()
        if target ~= nil and target:IsHero() then
            local nearbyTower = target:GetNearbyTowers(1300, true)
            if nearbyTower ~= nil and #nearbyTower > 0 and npcTarget:GetMana() > 0.25 * npcTarget:GetMaxMana() then
                tpLoc = nearbyTower[1]:GetLocation()
            end
        end
    elseif mode == BOT_MODE_RETREAT then
        tpLoc = nil
    elseif IsStuck(npcTarget) and #enemies == 0 then
        npcTarget:ActionImmediate_Chat("I'm using tp while stuck.", true)
        tpLoc = GetAncient(GetTeam()):GetLocation()
    end
    if tpLoc ~= nil then
        return true, tpLoc
    end
    return false, nil
end

---------------------------------------------------------------------------------------------------
--  内部辅助函数
---------------------------------------------------------------------------------------------------

function heroUnitUtility.GetDistance(a, b)
    local x1 = a.x
    local x2 = b.x
    local y1 = a.y
    local y2 = b.y
    return math.sqrt(math.pow((y2 - y1), 2) + math.pow((x2 - x1), 2))
end

return heroUnitUtility
