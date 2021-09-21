class CPUnitData extends Object;

const CharPoolExtendedImportFolderPath = "\\Documents\\my games\\XCOM2 War of the Chosen\\XComGame\\CharacterPool\\CharacterPoolExtended\\";

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
	local int Index;

	Index = FindUnitIndex(UnitState);
	if (Index == INDEX_NONE)
		return false;

	UnitState.AppearanceStore = CharacterPoolDatas[Index].AppearanceStore;
	return true;
}

final function UpdateOrAddUnit(XComGameState_Unit UnitState)
{
	local CPExtendedStruct NewCPExtendedData;
	local int Index;

	Index = FindUnitIndex(UnitState);
	if (Index != INDEX_NONE)
	{
		CharacterPoolDatas[Index].CharacterPoolData = GetCharacterPoolDataFromUnit(UnitState);
		CharacterPoolDatas[Index].AppearanceStore = UnitState.AppearanceStore;
	}
	else
	{
		NewCPExtendedData.CharacterPoolData = GetCharacterPoolDataFromUnit(UnitState);
		NewCPExtendedData.AppearanceStore = UnitState.AppearanceStore;
		CharacterPoolDatas.AddItem(NewCPExtendedData);
	}
}

private function int FindUnitIndex(XComGameState_Unit UnitState)
{
	local CPExtendedStruct CPExtendedData;
	local int Index;

	foreach CharacterPoolDatas(CPExtendedData, Index)
	{
		if (CPExtendedData.CharacterPoolData.strFirstName == UnitState.GetFirstName() &&
			CPExtendedData.CharacterPoolData.strLastName == UnitState.GetLastName() &&
			CPExtendedData.CharacterPoolData.kAppearance.iGender == UnitState.kAppearance.iGender)
		{
			return Index;
		}
	}

	return INDEX_NONE;
}

private function CharacterPoolDataElement GetCharacterPoolDataFromUnit(XComGameState_Unit Unit)
{	
	local CharacterPoolDataElement CharacterPoolSerializeHelper;

	CharacterPoolSerializeHelper.strFirstName = Unit.GetFirstName();
	CharacterPoolSerializeHelper.strLastName = Unit.GetLastName();
	CharacterPoolSerializeHelper.strNickName = Unit.GetNickName();	
	CharacterPoolSerializeHelper.m_SoldierClassTemplateName = Unit.GetSoldierClassTemplate().DataName;
	CharacterPoolSerializeHelper.CharacterTemplateName = Unit.GetMyTemplate().DataName;
	CharacterPoolSerializeHelper.kAppearance = Unit.kAppearance;
	CharacterPoolSerializeHelper.Country = Unit.GetCountry();
	CharacterPoolSerializeHelper.AllowedTypeSoldier = Unit.bAllowedTypeSoldier;
	CharacterPoolSerializeHelper.AllowedTypeVIP = Unit.bAllowedTypeVIP;
	CharacterPoolSerializeHelper.AllowedTypeDarkVIP = Unit.bAllowedTypeDarkVIP;
	CharacterPoolSerializeHelper.PoolTimestamp = Unit.PoolTimestamp;
	CharacterPoolSerializeHelper.BackgroundText = Unit.GetBackground();

	return CharacterPoolSerializeHelper;
}

final function string GetImportPath(string strFileName)
{
	return class'Engine'.static.GetEnvironmentVariable("USERPROFILE") $ CharPoolExtendedImportFolderPath $ strFileName $ ".bin";
}