class CPUnitData extends Object;

struct CPExtendedStruct
{
	// Stores most of the info regarding character pool unit: name, bio, current appearance.
	var CharacterPoolDataElement CharacterPoolData;

	// Store appearance store separately, because 'CharacterPoolDataElement' doesn't include it.
	var array<AppearanceInfo> AppearanceStore;
};

var array<CPExtendedStruct> CharacterPoolDatas;

final function bool ApplyAppearanceStore(XComGameState_Unit UnitState)
{
	local CPExtendedStruct CPExtendedData;

	foreach CharacterPoolDatas(CPExtendedData)
	{
		if (CPExtendedData.CharacterPoolData.strFirstName == UnitState.GetFirstName() &&
			CPExtendedData.CharacterPoolData.strLastName == UnitState.GetLastName() &&
			CPExtendedData.CharacterPoolData.kAppearance.iGender == UnitState.kAppearance.iGender)
		{
			UnitState.AppearanceStore = CPExtendedData.AppearanceStore;
			return true;
		}
	}
	return false;
}