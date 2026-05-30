local NewMinionUtility = require(GetScriptDirectory() .. "/base/NewMinionUtil")
local AbilityExtensions = require(GetScriptDirectory() .. "/base/AbilityAbstraction")

local function DiveBombCanCast(target)
	return target ~= nil and AbilityExtensions:NormalCanCast(target, false) and
		not AbilityExtensions:IsSeverelyDisabled(target)
end

function HawkThink(minion)
	local diveBomb = minion:GetAbilityByName("beastmaster_hawk_dive")
	if diveBomb:IsHidden() or not diveBomb:IsFullyCastable() then
		return
	end

	local target = GetBot():GetTarget()
	if DiveBombCanCast(target) then
		minion:Action_UseAbilityOnEntity(diveBomb, target)
	end
	local nearbyEnemies = AbilityExtensions:Filter(AbilityExtensions:GetNearbyNonIllusionHeroes(minion), DiveBombCanCast)
	if #nearbyEnemies > 0 then
		minion:Action_UseAbilityOnEntity(nearbyEnemies[1], target)
	end
end

function MinionThink(hMinionUnit)
	if NewMinionUtility.IsValidUnit(hMinionUnit) then
		if NewMinionUtility.IsHawk(hMinionUnit:GetUnitName()) then
			HawkThink(hMinionUnit)
		elseif NewMinionUtility.IsMinionWithSkill(hMinionUnit:GetUnitName()) then
			NewMinionUtility.MinionWithSkillThink(hMinionUnit)
		else
			NewMinionUtility.IllusionThink(hMinionUnit)
		end
	end
end
