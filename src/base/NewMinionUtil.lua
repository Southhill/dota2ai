----------------------------------------------------------------------------
--	召唤物工具（新）—管理幻象/守卫/通用召唤物
----------------------------------------------------------------------------
local MyModule = {}
local Units = require(GetScriptDirectory() .. "/const/units")

local bot = GetBot()
local TeamAncient = GetAncient(GetTeam())
local TeamAncientLoc = TeamAncient:GetLocation()
local EnemyAncient = GetAncient(GetOpposingTeam())
local EnemyAncientLoc = EnemyAncient:GetLocation()
local centre = Vector(0, 0, 0)

local attackDesire = 0
local moveDesire = 0
local retreatDesire = 0

local castQDesire = 0
local castWDesire = 0
local castEDesire = 0

function MyModule.IsFrozeSigil(unit_name)
    return Units.frozeSigilSet[unit_name] ~= nil
end

------------BEASTMASTER'S HAWK
function MyModule.IsHawk(unit_name)
    return Units.hawkSet[unit_name] ~= nil
end

function MyModule.IsTornado(unit_name)
    return Units.tornadoSet[unit_name] ~= nil
end

function MyModule.IsHealingWard(unit_name)
    return Units.healingWardSet[unit_name] ~= nil
end

function MyModule.IsBear(unit_name)
    return Units.bearSet[unit_name] ~= nil
end

function MyModule.IsFamiliar(unit_name)
    return Units.familiarSet[unit_name] ~= nil
end

function MyModule.IsMinionWithNoSkill(unit_name)
    return Units.minionWithNoSkillSet[unit_name] ~= nil
end

local remnant = Units.remnant
local trap = Units.trap
local independent = Units.independent

function MyModule.IsValidUnit(unit)
    return unit ~= nil and unit:IsNull() == false and unit:IsAlive()
end

function MyModule.IsValidTarget(target)
    return target ~= nil and target:IsNull() == false and target:CanBeSeen() and target:IsInvulnerable() == false and
        target:IsAlive()
end

function MyModule.IsInRange(unit, target, range)
    return GetUnitToUnitDistance(unit, target) <= range
end

function MyModule.CanCastOnTarget(target, ability)
    if CheckFlag(ability:GetTargetFlags(), ABILITY_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES) then
        return target:IsHero() and target:IsIllusion() == false
    else
        return target:IsHero() and target:IsIllusion() == false and target:IsMagicImmune() == false
    end
end

local globRadius = 1200

-- 局部别名（内部全局函数通过此处引用 MyModule 方法）
local IsValidTarget = MyModule.IsValidTarget
local IsInRange = MyModule.IsInRange
local CanCastOnTarget = MyModule.CanCastOnTarget

function GetWeakest(units)
    local target = nil
    local minHP = 10000
    if #units > 0 then
        for i = 1, #units do
            if IsValidTarget(units[i]) then
                local hp = units[i]:GetHealth()
                if hp <= minHP then
                    target = units[i]
                    minHP = hp
                end
            end
        end
    end
    return target
end

function GetWeakestHero(radius, minion)
    local enemies = minion:GetNearbyHeroes(radius, true, BOT_MODE_NONE)
    return GetWeakest(enemies)
end

function GetWeakestCreep(radius, minion)
    local creeps = minion:GetNearbyLaneCreeps(radius, true)
    return GetWeakest(creeps)
end

function GetWeakestTower(radius, minion)
    local towers = minion:GetNearbyTowers(radius, true)
    return GetWeakest(towers)
end

function GetWeakestBarracks(radius, minion)
    local barracks = minion:GetNearbyBarracks(radius, true)
    return GetWeakest(barracks)
end

function GetIllusionAttackTarget(minion)
    local target = bot:GetAttackTarget()
    if target == nil and bot:GetActiveMode() == BOT_MODE_RETREAT then
        target = GetWeakestHero(globRadius, minion)
        if target == nil then
            target = GetWeakestCreep(globRadius, minion)
        end
        if target == nil then
            target = GetWeakestTower(globRadius, minion)
        end
        if target == nil then
            target = GetWeakestBarracks(globRadius, minion)
        end
    end
    return target
end

function IsBusy(unit)
    return unit:IsUsingAbility() or unit:IsCastingAbility() or unit:IsChanneling()
end

function CantMove(unit)
    return unit:IsStunned() or unit:IsRooted() or unit:IsNightmared() or unit:IsInvulnerable()
end

function CantAttack(unit)
    return unit:IsStunned() or unit:IsRooted() or unit:IsNightmared() or unit:IsDisarmed() or unit:IsInvulnerable()
end

------------ILLUSION ACT
function ConsiderIllusionAttack(minion)
    if CantAttack(minion) then
        return BOT_MODE_DESIRE_NONE, nil
    end
    local target = GetIllusionAttackTarget(minion)
    if target ~= nil then
        return BOT_MODE_DESIRE_HIGH, target
    end
    return BOT_MODE_DESIRE_NONE, nil
end

function ConsiderIllusionMove(minion)
    if CantMove(minion) then
        return BOT_MODE_DESIRE_NONE, nil
    end
    if bot:GetActiveMode() ~= BOT_MODE_RETREAT then
        return BOT_MODE_DESIRE_HIGH, bot:GetXUnitsTowardsLocation(TeamAncientLoc, 300)
    end
    return BOT_MODE_DESIRE_NONE, nil
end

function IllusionThink(minion)
    minion.attackDesire, minion.target = ConsiderIllusionAttack(minion)
    minion.moveDesire, minion.loc = ConsiderIllusionMove(minion)
    if minion.attackDesire > 0 then
        minion:Action_AttackUnit(minion.target, true)
        return
    end
    if minion.moveDesire > 0 then
        minion:Action_MoveToLocation(minion.loc)
        return
    end
end

-----------ATTACKING WARD LIKE UNIT
function MyModule.IsAttackingWard(unit_name)
    return Units.attackingWardSet[unit_name] ~= nil
end

function GetWardAttackTarget(minion)
    local range = minion:GetAttackRange()
    local target = bot:GetAttackTarget()
    if IsValidTarget(target) == false or (IsValidTarget(target) and GetUnitToUnitDistance(minion, target) > range) then
        target = GetWeakestHero(range, minion)
        if target == nil then
            target = GetWeakestCreep(range, minion)
        end
        if target == nil then
            target = GetWeakestTower(range, minion)
        end
        if target == nil then
            target = GetWeakestBarracks(range, minion)
        end
    end
    return target
end

function ConsiderWardAttack(minion)
    local target = GetWardAttackTarget(minion)
    if target ~= nil then
        return BOT_MODE_DESIRE_HIGH, target
    end
    return BOT_MODE_DESIRE_NONE, nil
end

function AttackingWardThink(minion)
    minion.attackDesire, minion.target = ConsiderWardAttack(minion)
    if minion.attackDesire > 0 then
        minion:Action_AttackUnit(minion.target, true)
        return
    end
end

----------CAN'T BE CONTROLLED UNIT
function MyModule.CantBeControlled(unit_name)
    return Units.cantBeControlledSet[unit_name] ~= nil
end

function CantBeControlledThink(minion)
    return
end

-----------MINION WITH SKILLS
function MyModule.IsMinionWithSkill(unit_name)
    return Units.minionWithSkillSet[unit_name] ~= nil
end

function InitiateAbility(minion)
    minion.abilities = {}
    for i = 0, 3 do
        minion.abilities[i + 1] = minion:GetAbilityInSlot(i)
    end
end

function CheckFlag(bitfield, flag)
    return ((bitfield / flag) % 2) >= 1
end

function CanCastAbility(ability)
    return ability ~= nil and ability:IsFullyCastable() and ability:IsPassive() == false
end

function ConsiderUnitTarget(minion, ability)
    local castRange = ability:GetCastRange() + 200
    if bot:GetActiveMode() == BOT_MODE_RETREAT and bot:WasRecentlyDamagedByAnyHero(2.0) then
        local enemies = minion:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
        if #enemies > 0 then
            for i = 1, #enemies do
                if IsValidTarget(enemies[i]) and CanCastOnTarget(enemies[i], ability) then
                    return BOT_ACTION_DESIRE_HIGH, enemies[i]
                end
            end
        end
    else
        local target = bot:GetAttackTarget()
        if IsValidTarget(target) and CanCastOnTarget(target, ability) and IsInRange(minion, target, castRange) then
            return BOT_ACTION_DESIRE_HIGH, target
        end
    end
    return BOT_ACTION_DESIRE_NONE, nil
end

function ConsiderPointTarget(minion, ability)
    local castRange = ability:GetCastRange() + 200
    if bot:GetActiveMode() == BOT_MODE_RETREAT and bot:WasRecentlyDamagedByAnyHero(2.0) then
        local enemies = minion:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
        if #enemies > 0 then
            for i = 1, #enemies do
                if IsValidTarget(enemies[i]) and CanCastOnTarget(enemies[i], ability) then
                    return BOT_ACTION_DESIRE_HIGH, enemies[i]:GetLocation()
                end
            end
        end
    elseif bot:GetActiveMode() == BOT_MODE_ATTACK or bot:GetActiveMode() == BOT_MODE_DEFEND_ALLY then
        local target = bot:GetAttackTarget()
        if IsValidTarget(target) and CanCastOnTarget(target, ability) and IsInRange(minion, target, castRange) then
            return BOT_ACTION_DESIRE_HIGH, target:GetLocation()
        end
    end
    return BOT_ACTION_DESIRE_NONE, nil
end

function ConsiderNoTarget(minion, ability)
    local nRadius = ability:GetSpecialValueInt("radius")
    if bot:GetActiveMode() == BOT_MODE_RETREAT and bot:WasRecentlyDamagedByAnyHero(2.0) then
        local enemies = minion:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE)
        if #enemies > 0 then
            for i = 1, #enemies do
                if IsValidTarget(enemies[i]) and CanCastOnTarget(enemies[i], ability) then
                    return BOT_ACTION_DESIRE_HIGH
                end
            end
        end
    elseif bot:GetActiveMode() == BOT_MODE_ATTACK or bot:GetActiveMode() == BOT_MODE_DEFEND_ALLY then
        local target = bot:GetAttackTarget()
        -- print(tostring(target))
        if IsValidTarget(target) and CanCastOnTarget(target, ability) and IsInRange(minion, target, nRadius) then
            return BOT_ACTION_DESIRE_HIGH
        end
    end
    return BOT_ACTION_DESIRE_HIGH
end

function CastThink(minion, ability)
    if CheckFlag(ability:GetBehavior(), ABILITY_BEHAVIOR_UNIT_TARGET) then
        if ability:GetName() == "ogre_magi_frost_armor" then
            local castRange = ability:GetCastRange()
            local allies = minion:GetNearbyHeroes(castRange + 200, false, BOT_MODE_NONE)
            if #allies > 0 then
                for i = 1, #allies do
                    if IsValidTarget(allies[i]) and CanCastOnTarget(allies[i], ability) and
                        allies[i]:HasModifier("ogre_magi_frost_armor") == false then
                        minion:Action_UseAbilityOnEntity(ability, allies[i])
                        return
                    end
                end
            end
        else
            minion.castDesire, target = ConsiderUnitTarget(minion, ability)
            if minion.castDesire > 0 then
                -- print(minion:GetUnitName()..tostring(minion.castDesire).." Use Ability "..ability:GetName())
                minion:Action_UseAbilityOnEntity(ability, target)
                return
            end
        end
    elseif CheckFlag(ability:GetBehavior(), ABILITY_BEHAVIOR_POINT) then
        minion.castDesire, loc = ConsiderPointTarget(minion, ability)
        if minion.castDesire > 0 then
            -- print(minion:GetUnitName()..tostring(minion.castDesire).." Use Ability "..ability:GetName())
            minion:Action_UseAbilityOnLocation(ability, loc)
            return
        end
    elseif CheckFlag(ability:GetBehavior(), ABILITY_BEHAVIOR_NO_TARGET) then
        minion.castDesire = ConsiderNoTarget(minion, ability)
        if minion.castDesire > 0 then
            -- print(minion:GetUnitName()..tostring(minion.castDesire).." Use Ability "..ability:GetName())
            minion:Action_UseAbility(ability)
            return
        end
    end
end

function CastAbilityThink(minion)
    if CanCastAbility(minion.abilities[1]) then
        CastThink(minion, minion.abilities[1])
    end
    if CanCastAbility(minion.abilities[2]) then
        CastThink(minion, minion.abilities[2])
    end
    if CanCastAbility(minion.abilities[3]) then
        CastThink(minion, minion.abilities[3])
    end
    if CanCastAbility(minion.abilities[4]) then
        CastThink(minion, minion.abilities[4])
    end
end

function MinionWithSkillThink(minion)
    if IsBusy(minion) then
        return
    end
    if minion.abilities == nil then
        InitiateAbility(minion)
    end
    CastAbilityThink(minion)
    minion.attackDesire, minion.target = ConsiderIllusionAttack(minion)
    minion.moveDesire, minion.loc = ConsiderIllusionMove(minion)
    if minion.attackDesire > 0 then
        minion:Action_AttackUnit(minion.target, true)
        return
    end
    if minion.moveDesire > 0 then
        minion:Action_MoveToLocation(minion.loc)
        return
    end
end

function MinionThink(hMinionUnit)
    if bot == nil then
        bot = GetBot()
    end
    if IsValidUnit(hMinionUnit) then
        if hMinionUnit:IsIllusion() then
            IllusionThink(hMinionUnit)
        elseif IsAttackingWard(hMinionUnit:GetUnitName()) then
            -- AttackingWardThink(hMinionUnit);
            return
        elseif CantBeControlled(hMinionUnit:GetUnitName()) then
            CantBeControlledThink(hMinionUnit)
        end
    end
end

return MyModule
