class CharacterPoolManagerExtended extends CharacterPoolManager;

const CharPoolPath = "\\Documents\\my games\\XCOM2 War of the Chosen\\XComGame\\CharacterPool\\CharacterPoolExtended\\";

// ============================================================================
// OVERRIDDEN CHARACTER POOL MANAGER FUNCTIONS

event InitSoldier( XComGameState_Unit Unit, const out CharacterPoolDataElement CharacterPoolData )
{
	local CPUnitData UnitData;

	super.InitSoldier(Unit, CharacterPoolData);

	`LOG(GetFuncName() @ "Attempting to load data for unit:" @ Unit.GetFullName(),, 'IRITEST');

	UnitData = LoadUnitData(Unit.GetFullName());
	if (UnitData != none)
	{
		`LOG("Unit data found, copying appearance store.",, 'IRITEST');
		Unit.AppearanceStore = UnitData.AppearanceStore;
	}
	else `LOG("Did NOT found saved unit for:" @ Unit.GetFullName(),, 'IRITEST');
}

function SaveCharacterPool()
{
	local XComGameState_Unit UnitState;

	`LOG(GetFuncName() @ "called",, 'IRITEST');

	foreach CharacterPool(UnitState)
	{
		SaveUnitData(UnitState);
	}

	super.SaveCharacterPool();
}
/*
function XComGameState_Unit GetCharacter(string CharacterName)
{
	local int Index;	

	for(Index = 0; Index < CharacterPool.Length; ++Index)
	{
		if(CharacterName == CharacterPool[Index].GetFullName())
		{
			return CharacterPool[Index];
		}
	}

	return none;
}*/

// ============================================================================
// INTERNAL FUNCTIONS

private function SaveUnitData(const XComGameState_Unit UnitState)
{
    local bool Success;
	local CPUnitData NewData;

	NewData = new class'CPUnitData';
	NewData.AppearanceStore = UnitState.AppearanceStore;

    Success = class'Engine'.static.BasicSaveObject(NewData, GetFileNameFromSoldierName(UnitState.GetFullName()), false, 1);

    `LOG("Saved unit:" @ UnitState.GetFullName() @ Success @ GetFileNameFromSoldierName(UnitState.GetFullName()),, 'IRITEST');
}

private function CPUnitData LoadUnitData(const string strSoldierName)
{
	local CPUnitData UnitData;
    local bool Success;
   
	UnitData = new class'CPUnitData';
    Success = class'Engine'.static.BasicLoadObject(UnitData, GetFileNameFromSoldierName(strSoldierName), false, 1);

	`LOG("Loaded unit:" @ strSoldierName @ Success @ GetFileNameFromSoldierName(strSoldierName),, 'IRITEST');
	if (Success)
	{
		return UnitData;
	}
	return none;
}

static private function string GetFileNameFromSoldierName(string strSoldierName)
{
	return class'Engine'.static.GetEnvironmentVariable("USERPROFILE") $ CharPoolPath $ name(strSoldierName) $ ".bin";
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