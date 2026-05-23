----------------------------------------------------------------------------
--	Ranked Matchmaking AI
--	技能辅助模块 —— 提供通用的技能使用辅助函数
----------------------------------------------------------------------------
local BotsInit = require("game/botsinit")

local M = BotsInit.CreateGeneric()

-- 常量定义
M.const = {
    MAX_SEARCH_DISTANCE = 1600,           -- 最大搜索距离
    MAX_ALLY_SEARCH_DISTANCE = 1200,      -- 最大友方搜索距离
    EXTRA_SEARCH_DISTANCE = 300,          -- 额外搜索距离
    WARNING_DISTANCE = 600                -- 警戒距离
}

-- 检查技能加点表是否需要裁剪（当等级较低时移除多余的加点项）
function M.checkAbilityBuild(abilityTree)
    local npcBot = GetBot()
    if #abilityTree > 26 - npcBot:GetLevel() then
        local level = npcBot:GetLevel()
        for _ = 1, level do
            table.remove(abilityTree, 1)
        end
    end
end

-- 判断目标是否为肉山（Roshan）
function M.isRoshan(npcTarget)
    return npcTarget ~= nil and npcTarget:IsAlive() and string.find(npcTarget:GetUnitName(), "roshan")
end

-- 判断目标是否处于被控制状态
function M.isDisabled(npcTarget)
    if npcTarget:IsRooted() or npcTarget:IsStunned() or npcTarget:IsHexed() then
        return true
    else
        return false
    end
end

-- 判断目标是否为有效的敌方英雄目标
function M.isValidTarget(npcTarget)
    return npcTarget ~= nil and npcTarget:IsAlive() and npcTarget:IsHero()
end

-- 检查目标是否有禁止施法的减益效果（如寒冬诅咒、回光返照等）
function M.hasForbiddenModifier(npcTarget)
    local modifier = {
        "modifier_winter_wyvern_winters_curse",           -- 寒冬诅咒
        "modifier_winter_wyvern_winters_curse_aura",      -- 寒冬诅咒光环
        "modifier_abaddon_borrowed_time",                 -- 回光返照
        "modifier_obsidian_destroyer_astral_imprisonment_prison" -- 星体禁锢
    }
    for _, mod in pairs(modifier) do
        if npcTarget:HasModifier(mod) then
            return true
        end
    end
    return false
end

-- 检查目标是否有林肯法球/法术反射状态
function M.hasSphere(npcTarget)
    local modifier = {"modifier_item_sphere", "modifier_item_sphere_target"}
    for _, mod in pairs(modifier) do
        if npcTarget:HasModifier(mod) then
            return true
        end
    end
    return false
end

-- 判断目标是否为可疑的幻象
function M.isSuspiciousIllusion(npcTarget)
    local bot = GetBot()
    -- 检测已知的幻象 modifier
    if
        npcTarget:IsIllusion() or npcTarget:HasModifier("modifier_illusion") or
            npcTarget:HasModifier("modifier_phantom_lancer_doppelwalk_illusion") or
            npcTarget:HasModifier("modifier_phantom_lancer_juxtapose_illusion") or
            npcTarget:HasModifier("modifier_darkseer_wallofreplica_illusion") or
            npcTarget:HasModifier("modifier_terrorblade_conjureimage")
     then
        return true
    else
        -- 检测复制体和倒影
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

-- 常规施法判定（可见、非无敌、非幻象、无禁止效果、非魔免）
function M.normalCanCast(npcTarget)
    return npcTarget:CanBeSeen() and not npcTarget:IsInvulnerable() and not M.isSuspiciousIllusion(npcTarget) and
        not M.hasForbiddenModifier(npcTarget) and
        not npcTarget:IsMagicImmune()
end

function M.roshanCanCast(npcTarget)
    return npcTarget:CanBeSeen() and not npcTarget:IsInvulnerable() and not M.isSuspiciousIllusion(npcTarget) and
        not M.hasForbiddenModifier(npcTarget)
end

function M.ultimateCanCast(npcTarget)
    return npcTarget:CanBeSeen() and not npcTarget:IsInvulnerable() and not M.isSuspiciousIllusion(npcTarget) and
        not M.hasForbiddenModifier(npcTarget) and
        not M.hasSphere(npcTarget)
end

function M.aoeCanCast(npcTarget)
    return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and not npcTarget:IsInvulnerable() and
        not M.hasForbiddenModifier(npcTarget)
end

function M.getComboMana(AbilitiesReal)
    local tempComboMana = 0
    for _, ability in pairs(AbilitiesReal) do
        if ability:IsPassive() == false then
            if ability:IsUltimate() == false or ability:GetCooldownTimeRemaining() <= 30 then
                tempComboMana = tempComboMana + ability:GetManaCost()
            end
        end
    end
    return math.max(tempComboMana, 300)
end

function M.getComboDamage(AbilitiesReal)
    local tempComboDamage = 0
    for _, ability in pairs(AbilitiesReal) do
        if ability:IsPassive() == false then
            tempComboDamage = tempComboDamage + ability:GetAbilityDamage()
        end
    end
    return math.max(tempComboDamage, GetBot():GetOffensivePower())
end

function M.getWeakestUnit(EnemyUnits)
    if EnemyUnits == nil or #EnemyUnits == 0 then
        return nil, 10000
    end

    local WeakestUnit = nil
    local LowestHealth = 10000
    for _, unit in pairs(EnemyUnits) do
        if unit ~= nil and unit:IsAlive() then
            if unit:GetHealth() < LowestHealth then
                LowestHealth = unit:GetHealth()
                WeakestUnit = unit
            end
        end
    end

    return WeakestUnit, LowestHealth
end

function M.getStrongestUnit(EnemyUnits)
    if EnemyUnits == nil or #EnemyUnits == 0 then
        return nil, 0
    end

    local StrongestUnit = nil
    local HighestHealth = 0
    for _, unit in pairs(EnemyUnits) do
        if unit ~= nil and unit:IsAlive() then
            if unit:GetHealth() > HighestHealth then
                HighestHealth = unit:GetHealth()
                StrongestUnit = unit
            end
        end
    end

    return StrongestUnit, HighestHealth
end

return M
