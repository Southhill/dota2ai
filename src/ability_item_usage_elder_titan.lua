----------------------------------------------------------------------------
--	Ranked Matchmaking AI v1.3 New Structure
--	Author: adamqqq		Email:adamqqq@163.com
----------------------------------------------------------------------------
--------------------------------------
-- General Initialization
--------------------------------------
if
	GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or
		GetBot():IsIllusion()
 then
	return
end

local utility = require(GetScriptDirectory() .. "/util/Utility")
require(GetScriptDirectory() .. "/ability_item_usage_generic")
local AbilityExtensions = require(GetScriptDirectory() .. "/util/AbilityAbstraction")

local debugmode = false
local npcBot = GetBot()
local Talents = {}
local Abilities = {}
local AbilitiesReal = {}

ability_item_usage_generic.InitAbility(Abilities, AbilitiesReal, Talents)

local AbilityToLevelUp = {
	Abilities[2],
	Abilities[1],
	Abilities[2],
	Abilities[3],
	Abilities[2],
	Abilities[4],
	Abilities[2],
	Abilities[1],
	Abilities[1],
	"talent",
	Abilities[1],
	Abilities[4],
	Abilities[3],
	Abilities[3],
	"talent",
	Abilities[3],
	"nil",
	Abilities[4],
	"nil",
	"talent",
	"nil",
	"nil",
	"nil",
	"nil",
	"talent"
}

local TalentTree = {
	function()
		return Talents[1]
	end,
	function()
		return Talents[3]
	end,
	function()
		return Talents[6]
	end,
	function()
		return Talents[7]
	end
}

-- check skill build vs current level
utility.CheckAbilityBuild(AbilityToLevelUp)

function AbilityLevelUpThink()
	ability_item_usage_generic.AbilityLevelUpThink2(AbilityToLevelUp, TalentTree)
end

--------------------------------------
-- Ability Usage Thinking
--------------------------------------
local cast = {}
cast.Desire = {}
cast.Target = {}
cast.Type = {}
local Consider = {}
local CanCast = {utility.NCanCast, utility.NCanCast, utility.NCanCast, utility.UCanCast}
local enemyDisabled = utility.enemyDisabled

function GetComboDamage()
	return ability_item_usage_generic.GetComboDamage(AbilitiesReal)
end

function GetComboMana()
	return ability_item_usage_generic.GetComboMana(AbilitiesReal)
end

Consider[1] = function()
	local abilityNumber = 1
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber]

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local CastRange = 0
	local Damage = ability:GetAbilityDamage()
	local Radius = ability:GetAOERadius() - 50
	local CastPoint = ability:GetCastPoint()

	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
	local enemys = npcBot:GetNearbyHeroes(Radius, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	local creeps = npcBot:GetNearbyCreeps(Radius + 300, true)
	local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)
	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------
	-- Check for a channeling enemy
	for _, npcEnemy in pairs(enemys) do
		if (npcEnemy:IsChanneling() and CanCast[abilityNumber](npcEnemy)) then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy
		end
	end

	--Try to kill enemy hero
	if (npcBot:GetActiveMode() ~= BOT_MODE_RETREAT) then
		if (WeakestEnemy ~= nil) then
			if (CanCast[abilityNumber](WeakestEnemy)) then
				if
					(HeroHealth <= WeakestEnemy:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) or
						(HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_MAGICAL) and
							npcBot:GetMana() > ComboMana))
				 then
					return BOT_ACTION_DESIRE_HIGH, WeakestEnemy
				end
			end
		end
	end
	--------------------------------------
	-- Mode based usage
	--------------------------------------
	--protect myself
	if ((npcBot:WasRecentlyDamagedByAnyHero(2) and #enemys >= 1) or #enemys >= 2) then
		for _, npcEnemy in pairs(enemys) do
			if (CanCast[abilityNumber](npcEnemy)) then
				return BOT_ACTION_DESIRE_HIGH, "immediately"
			end
		end
	end

	-- If my mana is enough,use it at enemy
	if (npcBot:GetActiveMode() == BOT_MODE_LANING) then
		if ((ManaPercentage > 0.4 or npcBot:GetMana() > ComboMana) and ability:GetLevel() >= 2) then
			if (WeakestEnemy ~= nil) then
				if (CanCast[abilityNumber](WeakestEnemy)) then
					if (GetUnitToUnitDistance(npcBot, WeakestEnemy) < Radius - CastPoint * WeakestEnemy:GetCurrentMovementSpeed()) then
						return BOT_ACTION_DESIRE_LOW, WeakestEnemy
					end
				end
			end
		end
	end

	-- If we're farming and can hit 2+ creeps
	if (npcBot:GetActiveMode() == BOT_MODE_FARM) then
		if (#creeps >= 2) then
			if
				(CreepHealth <= WeakestCreep:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) and npcBot:GetMana() > ComboMana)
			 then
				return BOT_ACTION_DESIRE_LOW, WeakestCreep
			end
		end
	end

	-- If we're going after someone
	if
		(npcBot:GetActiveMode() == BOT_MODE_ROAM or npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
			npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
			npcBot:GetActiveMode() == BOT_MODE_ATTACK)
	 then
		local npcEnemy = npcBot:GetTarget()

		if (npcEnemy ~= nil) then
			if
				(CanCast[abilityNumber](npcEnemy) and not enemyDisabled(npcEnemy) and
					GetUnitToUnitDistance(npcBot, npcEnemy) <= Radius)
			 then
				return BOT_ACTION_DESIRE_MODERATE, npcEnemy
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

Consider[2] = function()
	local abilityNumber = 2
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber]

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local CastRange = ability:GetCastRange()
	local Damage = ability:GetAbilityDamage()
	local Radius = ability:GetAOERadius()
	local CastPoint = ability:GetCastPoint()

	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
	local enemys = npcBot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	local creeps = npcBot:GetNearbyCreeps(1600, true)
	local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)

	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------
	-- Check for a channeling enemy
	for _, npcEnemy in pairs(enemys) do
		if (npcEnemy:IsChanneling()) then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation()
		end
	end

	--try to kill enemy hero
	if (npcBot:GetActiveMode() ~= BOT_MODE_RETREAT) then
		if (WeakestEnemy ~= nil) then
			if (CanCast[abilityNumber](WeakestEnemy)) then
				if
					(HeroHealth <= WeakestEnemy:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) or
						(HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_MAGICAL) and
							npcBot:GetMana() > ComboMana))
				 then
					return BOT_ACTION_DESIRE_HIGH, WeakestEnemy:GetExtrapolatedLocation(CastPoint)
				end
			end
		end
	end
	--------------------------------------
	-- Mode based usage
	--------------------------------------
	-- If we're farming and can kill 3+ creeps with LSA
	if (npcBot:GetActiveMode() == BOT_MODE_FARM) then
		local locationAoE = npcBot:FindAoELocation(true, false, npcBot:GetLocation(), CastRange, Radius, 0, Damage)

		if (locationAoE.count >= 3) then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc
		end
	end

	-- If we're pushing or defending a lane and can hit 4+ creeps, go for it
	if
		(npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
			npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT or
			npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or
			npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or
			npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOT)
	 then
		local locationAoE = npcBot:FindAoELocation(true, false, npcBot:GetLocation(), CastRange, Radius, 0, 0)

		if (locationAoE.count >= 4) then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc
		end
	end

	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if (npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH) then
		for _, npcEnemy in pairs(enemys) do
			if (npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0)) then
				if (CanCast[abilityNumber](npcEnemy)) then
					return BOT_ACTION_DESIRE_MODERATE, npcEnemy:GetExtrapolatedLocation(CastPoint)
				end
			end
		end
	end

	-- If we're going after someone
	if
		(npcBot:GetActiveMode() == BOT_MODE_ROAM or npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
			npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
			npcBot:GetActiveMode() == BOT_MODE_ATTACK)
	 then
		local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), CastRange, Radius, 0, 0)
		if (locationAoE.count >= 2) then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc
		end

		local npcEnemy = npcBot:GetTarget()

		if (npcEnemy ~= nil) then
			if (CanCast[abilityNumber](npcEnemy)) then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetExtrapolatedLocation(CastPoint)
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

Consider[4] = function()
	local abilityNumber = 4
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber]

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local CastRange = ability:GetCastRange()
	local Damage = ability:GetAbilityDamage()
	local Radius = ability:GetSpecialValueInt("crack_width")
	local CastPoint = ability:GetCastPoint()
	local CrackTime = ability:GetSpecialValueInt("crack_time") - 1.5

	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
	local enemys = npcBot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	local creeps = npcBot:GetNearbyCreeps(1600, true)
	local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)

	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------
	--try to kill enemy hero
	if (npcBot:GetActiveMode() ~= BOT_MODE_RETREAT) then
		if (WeakestEnemy ~= nil) then
			if (CanCast[abilityNumber](WeakestEnemy)) then
				if
					(HeroHealth <= WeakestEnemy:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) or
						(HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_MAGICAL) and
							npcBot:GetMana() > ComboMana))
				 then
					return BOT_ACTION_DESIRE_HIGH, WeakestEnemy:GetExtrapolatedLocation(CastPoint + CrackTime)
				end
			end
		end
	end
	--------------------------------------
	-- Mode based usage
	--------------------------------------
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if (npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH) then
		for _, npcEnemy in pairs(enemys) do
			if (npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0)) then
				if (CanCast[abilityNumber](npcEnemy)) then
					return BOT_ACTION_DESIRE_MODERATE, npcEnemy:GetExtrapolatedLocation(CastPoint + CrackTime)
				end
			end
		end
	end

	-- If we're going after someone
	if
		(npcBot:GetActiveMode() == BOT_MODE_ROAM or npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
			npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
			npcBot:GetActiveMode() == BOT_MODE_ATTACK)
	 then
		local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), CastRange, Radius, 0, 0)
		if (locationAoE.count >= 2) then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

AbilityExtensions:AutoModifyConsiderFunction(npcBot, Consider, AbilitiesReal)
function AbilityUsageThink()
	-- Check if we're already using an ability
	if (npcBot:IsUsingAbility() or npcBot:IsChanneling() or npcBot:IsSilenced()) then
		return
	end

	ComboMana = GetComboMana()
	AttackRange = npcBot:GetAttackRange()
	ManaPercentage = npcBot:GetMana() / npcBot:GetMaxMana()
	HealthPercentage = npcBot:GetHealth() / npcBot:GetMaxHealth()

	cast = ability_item_usage_generic.ConsiderAbility(AbilitiesReal, Consider)
	---------------------------------debug--------------------------------------------
	if (debugmode == true) then
		ability_item_usage_generic.PrintDebugInfo(AbilitiesReal, cast)
	end
	ability_item_usage_generic.UseAbility(AbilitiesReal, cast)
end

function CourierUsageThink()
	ability_item_usage_generic.CourierUsageThink()
end
