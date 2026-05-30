local NewMinionUtility = require(GetScriptDirectory() .. "/base/NewMinionUtil")

function MinionThink(hMinionUnit)
	if NewMinionUtility.IsValidUnit(hMinionUnit) then
		if hMinionUnit:IsIllusion() then
			NewMinionUtility.IllusionThink(hMinionUnit);
		elseif NewMinionUtility.IsAttackingWard(hMinionUnit:GetUnitName()) then
			NewMinionUtility.AttackingWardThink(hMinionUnit);
		else
			return;
		end
	end
end
