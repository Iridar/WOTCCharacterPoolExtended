class CharacterPoolManagerExtended extends CharacterPoolManager;

const CharPoolPath = "\\Documents\\my games\\XCOM2 War of the Chosen\\XComGame\\CharacterPool\\CharacterPoolExtended\\";

event InitSoldier( XComGameState_Unit Unit, const out CharacterPoolDataElement CharacterPoolData )
{
	local CPUnitData UnitData;

	super.InitSoldier(Unit, CharacterPoolData);

	`LOG(GetFuncName() @ Unit.GetFullName(),, 'IRITEST');

	`LOG("Attempting to load unit:" @ Unit.GetFullName(),, 'IRITEST');
	UnitData = LoadUnitData(Unit.GetFullName()); // CRASH IS HERE
	if (UnitData != none)
	{
		`LOG("Found saved unit for:" @ Unit.GetFullName() @ ", copying appearance store.",, 'IRITEST');
		Unit.AppearanceStore = UnitData.AppearanceStore;
	}
	else `LOG("Did NOT found saved unit for:" @ Unit.GetFullName(),, 'IRITEST');
}

// Doesn't appear to be getting called.
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
   
    Success = class'Engine'.static.BasicLoadObject(UnitData, GetFileNameFromSoldierName(strSoldierName), false, 1);

	`LOG("Loaded unit:" @ strSoldierName @ Success @ GetFileNameFromSoldierName(strSoldierName),, 'IRITEST');

	return UnitData;
}

static private function string GetFileNameFromSoldierName(string strSoldierName)
{
	return class'Engine'.static.GetEnvironmentVariable("USERPROFILE") $ CharPoolPath $ name(strSoldierName) $ ".bin";
}

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