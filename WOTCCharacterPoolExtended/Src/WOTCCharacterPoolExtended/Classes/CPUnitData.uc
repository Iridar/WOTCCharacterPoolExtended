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

final function int GetNumUnits()
{
	return CharacterPoolDatas.Length;
}


final function array<string> GetUnitsFriendly()
{
	local array<string> ReturnArray;

	local CPExtendedStruct CPExtendedData;

	foreach CharacterPoolDatas(CPExtendedData)
	{
		
		if (CPExtendedData.CharacterPoolData.strNickName != "")
			ReturnArray.AddItem(CPExtendedData.CharacterPoolData.strFirstName @ "\"" $ CPExtendedData.CharacterPoolData.strNickName $ "\"" @ CPExtendedData.CharacterPoolData.strLastName);
		else
			ReturnArray.AddItem(CPExtendedData.CharacterPoolData.strFirstName @ CPExtendedData.CharacterPoolData.strLastName);
	}
	return ReturnArray;
}

final function array<string> GetUnitsFriendlyExtraData()
{
	local array<string>		ReturnArray;
	local string			SoldierString;
	local CPExtendedStruct	CPExtendedData;
	local X2SoldierClassTemplate			ClassTemplate;
	local X2SoldierClassTemplateManager		ClassMgr;

	ClassMgr = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();

	foreach CharacterPoolDatas(CPExtendedData)	
	{
		ClassTemplate = ClassMgr.FindSoldierClassTemplate(CPExtendedData.CharacterPoolData.m_SoldierClassTemplateName);
		if (ClassTemplate != none)
		{
			SoldierString = ClassTemplate.DisplayName $ ": ";
		}
		else
		{
			SoldierString = "";
		}

		if (CPExtendedData.CharacterPoolData.strNickName != "")
		{
			SoldierString $= CPExtendedData.CharacterPoolData.strFirstName @ "\"" $ CPExtendedData.CharacterPoolData.strNickName $ "\"" @ CPExtendedData.CharacterPoolData.strLastName;
		}
		else
		{
			SoldierString $= CPExtendedData.CharacterPoolData.strFirstName @ CPExtendedData.CharacterPoolData.strLastName;
		}

		ReturnArray.AddItem(SoldierString);
	}
	return ReturnArray;
}


final function SortCharacterPoolBySoldierClass()
{
	CharacterPoolDatas.Sort(SortCharacterPoolBySoldierClassFn);
}

final function SortCharacterPoolBySoldierName()
{
	CharacterPoolDatas.Sort(SortCharacterPoolBySoldierNameFn);
}

private function int SortCharacterPoolBySoldierNameFn(CPExtendedStruct UnitA, CPExtendedStruct UnitB)
{
	if (GetFullName(UnitA) < GetFullName(UnitB))
	{
		return 1;
	}
	else if (GetFullName(UnitA) > GetFullName(UnitB))
	{
		return -1;
	}
	return 0;
}

private function string GetFullName(CPExtendedStruct Unit)
{
	return Unit.CharacterPoolData.strFirstName @ Unit.CharacterPoolData.strLastName;
}

private function int SortCharacterPoolBySoldierClassFn(CPExtendedStruct UnitA, CPExtendedStruct UnitB)
{
	local X2SoldierClassTemplate TemplateA;
	local X2SoldierClassTemplate TemplateB;
	local X2SoldierClassTemplateManager ClassMgr;

	ClassMgr = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();

	TemplateA = ClassMgr.FindSoldierClassTemplate(UnitA.CharacterPoolData.m_SoldierClassTemplateName);
	TemplateB = ClassMgr.FindSoldierClassTemplate(UnitB.CharacterPoolData.m_SoldierClassTemplateName);

	// Put units without soldier class template below those with one.
	if (TemplateA == none)
	{
		if (TemplateB == none)
		{
			return 0;	
		}		
		else
		{
			return -1;
		}
	}
	else if (TemplateB == none)
	{
		return 1;
	}

	if (TemplateA.DisplayName == TemplateB.DisplayName)
	{
		return 0;
	}
	
	if (TemplateA.DataName == 'Rookie')
	{
		return 1;
	}
	if (TemplateB.DataName == 'Rookie')
	{
		return -1;
	}
	
	if (TemplateA.DisplayName < TemplateB.DisplayName)
	{
		return 1;
	}
	return -1;
}