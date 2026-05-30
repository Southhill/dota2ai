local NewMinionUtility = require(GetScriptDirectory() .. "/base/NewMinionUtil")

function MinionThink(hMinionUnit)
	if NewMinionUtility.IsValidUnit(hMinionUnit) then
		if hMinionUnit:IsIllusion() then
			NewMinionUtility.IllusionThink(hMinionUnit);
		elseif NewMinionUtility.CantBeControlled(hMinionUnit:GetUnitName()) then
			NewMinionUtility.CantBeControlledThink(hMinionUnit);
		else
			return;
		end
	end
end
