----------------------------------------------------------------------------
--	Ranked Matchmaking AI v1.1 NewStructure
--	Author: adamqqq		Email:adamqqq@163.com
--	敌法�?(Anti-Mage) 技能与物品使用脚本
----------------------------------------------------------------------------
--------------------------------------
-- 通用初始�?
--------------------------------------
local utility = require(GetScriptDirectory() .. "/base/Utility")
require(GetScriptDirectory() .. "/ability_item_usage_generic")
local AbilityExtensions = require(GetScriptDirectory() .. "/base/AbilityAbstraction")
local heroUnit = require(GetScriptDirectory() .. "/base/HeroUtility")

local debugmode = false
local npcBot = GetBot()
local Talents = {}       -- 天赋列表
local Abilities = {}     -- 技能名称列�?
local AbilitiesReal = {} -- 技能对象列�?

-- 初始化技能和天赋
ability_item_usage_generic.InitAbility(Abilities, AbilitiesReal, Talents)

-- 技能加点顺序表（共30级）
-- �?技能（法力燃烧），�?技能（闪烁），3技能（法术护盾），5技能（大招�?
local AbilityToLevelUp = {
	Abilities[1], -- 1�? 法力燃烧
	Abilities[2], -- 2�? 闪烁
	Abilities[1], -- 3�? 法力燃烧
	Abilities[3], -- 4�? 法术护盾
	Abilities[2], -- 5�? 闪烁
	Abilities[5], -- 6�? 大招
	Abilities[2], -- 7�? 闪烁
	Abilities[2], -- 8�? 闪烁
	Abilities[1], -- 9�? 法力燃烧
	"talent",  -- 10�? 天赋
	Abilities[1], -- 11�? 法力燃烧
	Abilities[5], -- 12�? 大招
	Abilities[3], -- 13�? 法术护盾
	Abilities[3], -- 14�? 法术护盾
	"talent",  -- 15�? 天赋
	Abilities[3], -- 16�? 法术护盾
	"nil",     -- 17�? 属性奖�?
	Abilities[5], -- 18�? 大招
	"nil",     -- 19�? 属性奖�?
	"talent",  -- 20�? 天赋
	"nil",     -- 21�? 属性奖�?
	"nil",     -- 22�? 属性奖�?
	"nil",     -- 23�? 属性奖�?
	"nil",     -- 24�? 属性奖�?
	"talent"   -- 25�? 天赋
}

-- 天赋选择树（按照顺序�?0/15/20/25级左右天赋）
local TalentTree = {
	function() return Talents[1] end, -- 10级左天赋
	function() return Talents[4] end, -- 15级右天赋
	function() return Talents[6] end, -- 20级右天赋
	function() return Talents[8] end, -- 25级右天赋
	function() return Talents[2] end, -- 10级右天赋
	function() return Talents[3] end, -- 15级左天赋
	function() return Talents[5] end, -- 20级左天赋
	function() return Talents[7] end, -- 25级左天赋
}

utility.CheckAbilityBuild(AbilityToLevelUp)

-- 技能加点主入口
function AbilityLevelUpThink()
	ability_item_usage_generic.AbilityLevelUpThink(AbilityToLevelUp, TalentTree)
end

--------------------------------------
-- 技能使用逻辑
--------------------------------------
local cast = {}
cast.Desire = {}    -- 施放欲望�?
cast.Target = {}    -- 施放目标
cast.Type = {}      -- 施放类型
local Consider = {} -- 各技能的考虑函数
local CanCast = { utility.NCanCast, utility.NCanCast, utility.NCanCast, utility.UCanCast, utility.NCanCast }
local enemyDisabled = utility.enemyDisabled

-- 计算连招总伤�?
function GetComboDamage()
	return ability_item_usage_generic.GetComboDamage(AbilitiesReal)
end

-- 计算连招总蓝�?
function GetComboMana()
	return ability_item_usage_generic.GetComboMana(AbilitiesReal)
end

-- 计算闪烁攻击的最佳落点（预测敌方移动方向�?
local function GetBlinkAttackLocation(enemy)
	local attackDistance = enemy:GetBoundingRadius() + npcBot:GetBoundingRadius()
	if AbilityExtensions:HasPhasedMovement(enemy) or AbilityExtensions:HasUnobstructedMovement(enemy) then
		attackDistance = npcBot:GetAttackRange()
	end
	-- 预测敌人下一步位�?
	local enemyNextStep =
		enemy:GetLocation() + Vector(math.cos(enemy:GetFacing()), math.sin(enemy:GetFacing())) * attackDistance
	local distanceFromNextStep = GetUnitToLocationDistance(npcBot, enemyNextStep)
	local blinkRadius = AbilitiesReal[2]:GetSpecialValueInt("blink_range")
	if blinkRadius <= distanceFromNextStep then
		return AbilityExtensions:GetPointFromLineByDistance(npcBot:GetLocation(), enemy:GetLocation(), blinkRadius)
	else
		return enemyNextStep
	end
end

-- 判断闪烁到目标附近是否太危险
local function TooDangerousToBlinkNear(npc)
	local enoughHealth =
		AbilityExtensions:GetHealthPercent(npcBot) >= AbilityExtensions:GetHealthPercent(npc) + 0.2 and
		npcBot:GetHealth() >= npc:GetHealth() * 0.8
	-- 极度危险的情况（石化凝视、时间结界、猴子大招、无敌）
	local isVeryDangerous =
		npc:HasModifier("modifier_medusa_stone_gaze") or npc:HasModifier("modifier_faceless_void_chronosphere_selfbuff") or
		npc:HasModifier("modifier_monkey_king_fur_army_soldier_in_position") or
		AbilityExtensions:IsInvulnerable(npc)
	if isVeryDangerous then
		return true
	end
	-- 危险的情况（蝙蝠燃油、冰龙飞行、魔免）
	local isDangerous =
		npc:HasModifier("modifier_batrider_firefly") or npc:HasModifier("modifier_winter_wyvern_arctic_burn_flight") or
		npc:IsMagicImmune()
	if isDangerous and not enoughHealth then
		return true
	end
	return false
end

-- 技�?（闪烁）的考虑函数
Consider[2] = function()
	local abilityNumber = 2
	--------------------------------------
	-- 通用变量设置
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber]

	-- 技能不可用或被禁用地形传�?
	if not ability:IsFullyCastable() or AbilityExtensions:CannotTeleport(npcBot) then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local CastRange = ability:GetSpecialValueInt("blink_range")
	local allys = utility.GetNearbyVisibleHeroes(npcBot, 1200, false, BOT_MODE_NONE)
	local enemys = utility.GetNearbyVisibleHeroes(npcBot, CastRange + 300, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	local trees = npcBot:GetNearbyTrees(300)

	-- 非撤退模式下尝试击杀敌方英雄
	if (npcBot:GetActiveMode() ~= BOT_MODE_RETREAT) then
		if (WeakestEnemy ~= nil) then
			local enemys2 = WeakestEnemy:GetNearbyHeroes(900, true, BOT_MODE_NONE)
			if (CanCast[abilityNumber](WeakestEnemy) and #enemys2 <= 2) then
				if
					(HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_MAGICAL) and
						npcBot:GetMana() > ComboMana and
						GetUnitToUnitDistance(npcBot, WeakestEnemy) > 200)
				then
					if TooDangerousToBlinkNear(WeakestEnemy) then
						return 0
					end
					return BOT_ACTION_DESIRE_HIGH, GetBlinkAttackLocation(WeakestEnemy)
				end
			end
		end
	end

	-- 卡住时闪烁逃生
	if heroUnit.IsStuck(npcBot) then
		local loc = utility.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, utility.GetUnitsTowardsLocation(npcBot, loc, CastRange)
	end

	-- 撤退时闪烁回基地
	if
		(npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:DistanceFromFountain() >= 2000 and
			(ManaPercentage >= 0.6 or npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH or HealthPercentage <= 0.6))
	then
		return BOT_ACTION_DESIRE_HIGH, utility.GetUnitsTowardsLocation(npcBot, GetAncient(GetTeam()), CastRange)
	end

	-- 追击敌人时闪烁靠�?
	if
		(npcBot:GetActiveMode() == BOT_MODE_ROAM or npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
			npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
			npcBot:GetActiveMode() == BOT_MODE_ATTACK)
	then
		local npcEnemy = npcBot:GetTarget()

		if (ManaPercentage > 0.4 or npcBot:GetMana() > ComboMana) then
			if (npcEnemy ~= nil) then
				local enemys2 = npcEnemy:GetNearbyHeroes(900, false, BOT_MODE_NONE)
				if (enemys2 ~= nil and #enemys2 <= 2) then
					if
						(CanCast[abilityNumber](npcEnemy) and GetUnitToUnitDistance(npcBot, npcEnemy) < CastRange + 75 * #allys and
							GetUnitToUnitDistance(npcBot, npcEnemy) > 200)
					then
						if TooDangerousToBlinkNear(npcEnemy) then
							return 0
						end
						return BOT_ACTION_DESIRE_MODERATE, GetBlinkAttackLocation(npcEnemy)
					end
				end
			end
		end
	end

	-- use blink to dodge ability
	local projectiles = AbilityExtensions:GetIncomingDodgeWorthProjectiles(npcBot)
	local castPoint = ability:GetCastPoint()
	local defaultProjectileVelocity = 1500
	if
		#projectiles ~= 0 and not AbilitiesReal[3]:IsFullyCastable() and
		not npcBot:HasModifier("modifier_antimage_counterspell")
	then
		for _, projectile in pairs(projectiles) do
			if GetUnitToLocationDistance(npcBot, projectile.location) > castPoint * defaultProjectileVelocity then
				local escapeLocation = utility.GetUnitsTowardsLocation(npcBot, projectile.location, 400)
				return BOT_ACTION_DESIRE_MODERATE, escapeLocation
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

Consider[3] = function()
	local abilityNumber = 3
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber]

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local allys = utility.GetNearbyVisibleHeroes(npcBot, 1200, false, BOT_MODE_NONE)
	local enemys = utility.GetNearbyVisibleHeroes(npcBot, 900, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	local trees = npcBot:GetNearbyTrees(300)

	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if (npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH) then
		local incProj = npcBot:GetIncomingTrackingProjectiles()
		for _, p in pairs(incProj) do
			if
				GetUnitToLocationDistance(npcBot, p.location) <= 300 and p.is_attack == false and
				not AbilityExtensions:IgnoreAbilityBlock(p.ability)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end

	-- If we're going after someone
	if
		(npcBot:GetActiveMode() == BOT_MODE_ROAM or npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
			npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
			npcBot:GetActiveMode() == BOT_MODE_ATTACK or
			(npcBot:GetActiveMode() == BOT_MODE_LANING and ManaPercentage >= 0.4))
	then
		local npcTarget = npcBot:GetTarget()
		if (npcTarget ~= nil) then
			if CanCast[abilityNumber](npcTarget) and GetUnitToUnitDistance(npcBot, npcTarget) < 600 then
				local incProj = AbilityExtensions:GetIncomingDodgeWorthProjectiles(npcBot)
				for _, p in pairs(incProj) do
					if GetUnitToLocationDistance(npcBot, p.location) <= 300 then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

Consider[4] = function()
	local abilityNumber = 4
	local ability = AbilitiesReal[abilityNumber]
	if not ability:IsFullyCastable() then
		return 0
	end
	local allys = utility.GetNearbyVisibleHeroes(npcBot, 1200, false, BOT_MODE_NONE)
	local enemies =
		AbilityExtensions:Filter(
			utility.GetNearbyVisibleHeroes(npcBot, 1600, true, BOT_MODE_NONE),
			function(t)
				return GetUnitToUnitDistance(npcBot, t) >= 450
			end
		)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemies)
	if #enemies == 0 then
		return 0
	end
	if npcBot:GetActiveMode() ~= BOT_MODE_RETREAT and (#enemies >= 2 or enemies[1]:GetHealth() >= npcBot:GetHealth() * 1.5) then
		return BOT_ACTION_DESIRE_MODERATE, WeakestEnemy:GetLocation()
	end
end

Consider[5] = function()
	local abilityNumber = 5
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber]

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local CastRange = ability:GetCastRange()
	local DamagePercent = ability:GetSpecialValueFloat("mana_void_damage_per_mana")
	local Radius = ability:GetAOERadius()

	local allys = utility.GetNearbyVisibleHeroes(npcBot, 1200, false, BOT_MODE_NONE)
	local enemys = utility.GetNearbyVisibleHeroes(npcBot, CastRange + 300, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------
	--Try to kill enemy hero

	if npcBot:GetActiveMode() ~= BOT_MODE_RETREAT then
		local targets = utility.GetNearbyVisibleHeroes(npcBot, CastRange + 400, true, BOT_MODE_NONE)
		local goodTargets = {}
		for _, t in pairs(targets) do
			if AbilityExtensions:MustBeIllusion(npcBot, t) then
				break
			end
			local g = {}
			local enemies =
				AbilityExtensions:Filter(
					t:GetNearbyHeroes(Radius, false, BOT_MODE_NONE) or {},
					function(tt)
						return AbilityExtensions:MayNotBeIllusion(npcBot, tt)
					end
				)
			local rawDamage = (t:GetMaxMana() - t:GetMana()) * DamagePercent
			g.totalDamage = rawDamage * (AbilityExtensions:GetEnemyHeroNumber(npcBot, enemies) + 1)
			g.totalKill =
				AbilityExtensions:Count(
					enemies,
					function(e)
						return e:GetActualIncomingDamage(rawDamage, DAMAGE_TYPE_MAGICAL) >= e:GetHealth() and
							not AbilityExtensions:CannotBeKilledNormally(e)
					end
				)
			g.totalKillNames =
				AbilityExtensions:Map(
					AbilityExtensions:Filter(
						enemies,
						function(e)
							return e:GetActualIncomingDamage(rawDamage, DAMAGE_TYPE_MAGICAL) >= e:GetHealth() and
								not AbilityExtensions:CannotBeKilledNormally(e)
						end
					),
					function(e)
						return e:GetUnitName()
					end
				)
			g.rate = g.totalKill + g.totalDamage * 600 / 10000 * npcBot:GetNetWorth()
			g.target = t
			table.insert(goodTargets, g)
		end
		if #goodTargets > 1 then
		end
		AbilityExtensions:Sort(
			goodTargets,
			function(a, b)
				return b.rate - a.rate
			end
		)
		local t = goodTargets[1]
		if t ~= nil then
			if
				t.totalDamage >= 600 / 10000 * npcBot:GetNetWorth() and
				(t.target:GetMaxMana() - t.target:GetMana()) >= 300 + DotaTime() / 4 and
				(AbilityExtensions:GetManaPercent(t.target) <= 0.1 or
					npcBot:GetActiveMode() ~= BOT_MODE_RETREAT and GetUnitToUnitDistance(npcBot, t) <= npcBot:GetAttackRange())
			then
				return BOT_ACTION_DESIRE_HIGH, t.target
			end
			if
				t.totalKill >= 2 or
				t.totalKill == 1 and not t.target:WasRecentlyDamagedByAnyHero(1) and
				#t.target:GetNearbyHeroes(350, true, BOT_MODE_NONE) == 0
			then
				return BOT_ACTION_DESIRE_HIGH, t.target
			end
		end
	end

	for _, npcEnemy in pairs(enemys) do
		if (npcEnemy:IsChanneling() and CanCast[abilityNumber](npcEnemy)) then
			return BOT_ACTION_DESIRE_MODERATE, npcEnemy
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
