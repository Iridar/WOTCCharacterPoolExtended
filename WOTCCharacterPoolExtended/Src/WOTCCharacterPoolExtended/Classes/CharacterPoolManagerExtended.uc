class CharacterPoolManagerExtended extends CharacterPoolManager dependson(CPUnitData);

var private CPUnitData UnitData; // Use GetUnitData() before accessing it

var string CharPoolExtendedFilePath;

// ============================================================================
// OVERRIDDEN CHARACTER POOL MANAGER FUNCTIONS

event InitSoldier( XComGameState_Unit Unit, const out CharacterPoolDataElement CharacterPoolData )
{
	`LOG(GetFuncName() @ "called for unit:" @ Unit.GetFullName(),, 'IRITEST');

	super.InitSoldier(Unit, CharacterPoolData);
	
	GetUnitData();
	UnitData.ApplyAppearanceStore(Unit);
}

event InitSoldierOld(XComGameState_Unit Unit, const out CharacterPoolDataElement CharacterPoolData)
{
	super.InitSoldier(Unit, CharacterPoolData);
}

function SaveCharacterPool()
{
	`LOG(GetFuncName() @ "called",, 'IRITEST');

	SaveCharacterPoolExtended();
	super.SaveCharacterPool();
}

// Replace pointless 'assert' with 'return none' so we can do error detecting
// in case player attempts to import a unit with a custom char template that's not present with their current modlist
event XComGameState_Unit CreateSoldier(name DataTemplateName)
{
	local XComGameState					SoldierContainerState;
	local XComGameState_Unit			NewSoldierState;	
	local X2CharacterTemplateManager    CharTemplateMgr;	
	local X2CharacterTemplate           CharacterTemplate;
	local TSoldier                      CharacterGeneratorResult;
	local XGCharacterGenerator          CharacterGenerator;
	local XComGameStateHistory			History;
	local XComGameStateContext_ChangeContainer ChangeContainer;

	History = `XCOMHISTORY;
	
	//Create a game state to use for creating a unit
	ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Character Pool Manager");
	SoldierContainerState = History.CreateNewGameState(true, ChangeContainer);

	CharTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	if (CharTemplateMgr == none)
	{
		History.CleanupPendingGameState(SoldierContainerState);
		return none;
	}

	CharacterTemplate = CharTemplateMgr.FindCharacterTemplate(DataTemplateName);	

	if (CharacterTemplate != none)
	{
		CharacterGenerator = `XCOMGAME.Spawn(CharacterTemplate.CharacterGeneratorClass);
		if (CharacterGenerator == none)
		{
			History.CleanupPendingGameState(SoldierContainerState);
			return none;
		}

		NewSoldierState = CharacterTemplate.CreateInstanceFromTemplate(SoldierContainerState);
		NewSoldierState.RandomizeStats();

		NewSoldierState.bAllowedTypeSoldier = true;

		CharacterGeneratorResult = CharacterGenerator.CreateTSoldier(DataTemplateName);
		NewSoldierState.SetTAppearance(CharacterGeneratorResult.kAppearance);
		NewSoldierState.SetCharacterName(CharacterGeneratorResult.strFirstName, CharacterGeneratorResult.strLastName, CharacterGeneratorResult.strNickName);
		NewSoldierState.SetCountry(CharacterGeneratorResult.nmCountry);
		class'XComGameState_Unit'.static.NameCheck(CharacterGenerator, NewSoldierState, eNameType_Full);

		NewSoldierState.GenerateBackground(, CharacterGenerator.BioCountryName);
	}
	
	//Tell the history that we don't actually want this game state
	History.CleanupPendingGameState(SoldierContainerState);

	return NewSoldierState;
}

// ============================================================================
// INTERNAL FUNCTIONS

final function SortCharacterPoolBySoldierClass()
{
	CharacterPool.Sort(SortCharacterPoolBySoldierClassFn);
}

final function SortCharacterPoolBySoldierName()
{
	CharacterPool.Sort(SortCharacterPoolBySoldierNameFn);
}

private final function int SortCharacterPoolBySoldierNameFn(XComGameState_Unit UnitA, XComGameState_Unit UnitB)
{
	if (UnitA.GetFullName() < UnitB.GetFullName())
	{
		return 1;
	}
	else if (UnitA.GetFullName() > UnitB.GetFullName())
	{
		return -1;
	}
	return 0;
}

private final function int SortCharacterPoolBySoldierClassFn(XComGameState_Unit UnitA, XComGameState_Unit UnitB)
{
	local X2SoldierClassTemplate TemplateA;
	local X2SoldierClassTemplate TemplateB;

	TemplateA = UnitA.GetSoldierClassTemplate();
	TemplateB = UnitB.GetSoldierClassTemplate();

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

final function SaveCharacterPoolExtended()
{
	local CPExtendedStruct		CPExtendedUnitData;
	local CPExtendedStruct		EmptyCPExtendedUnitData;
	local bool					Success;
	local XComGameState_Unit	UnitState;

	UnitData = new class'CPUnitData';

	foreach CharacterPool(UnitState)
	{
		CPExtendedUnitData = EmptyCPExtendedUnitData;

		FillCharacterPoolData(UnitState); // This saves UnitState to 'CharacterPoolSerializeHelper' 
		CPExtendedUnitData.CharacterPoolData = CharacterPoolSerializeHelper;
		CPExtendedUnitData.AppearanceStore = UnitState.AppearanceStore;

		UnitData.CharacterPoolDatas.AddItem(CPExtendedUnitData);

		`LOG("Saved" @ UnitState.GetFullName() @ "to CP Extended:" @ CPExtendedUnitData.AppearanceStore.Length,, 'IRITEST');
	}

    Success = class'Engine'.static.BasicSaveObject(UnitData, class'Engine'.static.GetEnvironmentVariable("USERPROFILE") $ CharPoolExtendedFilePath, false, 1);

    `LOG("Saved CP Extended:" @ Success,, 'IRITEST');
}

final function CPUnitData GetUnitData()
{
	if (UnitData != none)
		return UnitData;

	UnitData = new class'CPUnitData';
	
	if (class'Engine'.static.BasicLoadObject(UnitData, class'Engine'.static.GetEnvironmentVariable("USERPROFILE") $ CharPoolExtendedFilePath, false, 1))
	{
		`LOG("Loaded CP Extended: true",, 'IRITEST');
	}
	else 
	{
		SaveCharacterPoolExtended();
		`LOG("Failed to load CP Extended, recreating it.",, 'IRITEST');
	}
}

final function string GetUnitFullNameExtraData(const int Index)
{
	local XComGameState_Unit		CPUnit;
	local string					SoldierString;
	local X2SoldierClassTemplate	ClassTemplate;

	CPUnit = CharacterPool[Index];

	ClassTemplate = CPUnit.GetSoldierClassTemplate();
	if (ClassTemplate != none)
	{
		SoldierString = ClassTemplate.DisplayName $ ": ";
	}
	else
	{
		SoldierString = "";
	}

	if (CPUnit.GetNickName() != "")
	{
		SoldierString $= CPUnit.GetFirstName @ "\"" $ CPUnit.GetNickName() $ "\"" @ CPUnit.GetLastName();
	}
	else
	{
		SoldierString $= CPUnit.GetFirstName @ CPUnit.GetLastName();
	}

	return SoldierString;
}

// ============================================================================
// INTERNAL HELPERS

private function PrintCP()
{
	local XComGameState_Unit UnitState;
	local int i;

	`LOG("####" @ GetFuncName() @ "BEGIN",, 'IRITEST');

	foreach CharacterPool(UnitState, i)
	{
		`LOG(i @ UnitState.GetFullName(),, 'IRITEST');
	}

	`LOG("####" @ GetFuncName() @ "END",, 'IRITEST');
}

// ============================================================================
// These don't appear to be getting called.
/*
function LoadCharacterPool()
{
	`LOG(GetFuncName() @ "called" @ CharacterPool.Length,, 'IRITEST');

	super.LoadCharacterPool();
}

function LoadBaseGameCharacterPool()
{
	`LOG(GetFuncName() @ "before called" @ CharacterPool.Length,, 'IRITEST');

	super.LoadBaseGameCharacterPool();

	`LOG(GetFuncName() @ "after called" @ CharacterPool.Length,, 'IRITEST');
}
*/

defaultproperties
{
	CharPoolExtendedFilePath = "\\Documents\\my games\\XCOM2 War of the Chosen\\XComGame\\CharacterPool\\CharacterPoolExtended.bin"
}