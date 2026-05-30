local minionutils = dofile(GetScriptDirectory() .. "/base/NewMinionUtil")

function MinionThink(hMinionUnit)
	if minionutils.IsValidUnit(hMinionUnit) then
		if hMinionUnit:IsIllusion() then
			minionutils.IllusionThink(hMinionUnit);
		elseif minionutils.CantBeControlled(hMinionUnit:GetUnitName()) then
			minionutils.CantBeControlledThink(hMinionUnit);
		else
			print("unrecognised minion: " .. hMinionUnit:GetUnitName())
			return;
		end
	end
end

function CourierUsageThink()

end
