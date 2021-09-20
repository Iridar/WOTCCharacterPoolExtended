class CharacterPoolManagerExtended extends CharacterPoolManager;

const CharPoolPath = "\\Documents\\my games\\XCOM2 War of the Chosen\\XComGame\\CharacterPool\\CharacterPoolExtended\\";

event InitSoldier( XComGameState_Unit Unit, const out CharacterPoolDataElement CharacterPoolData )
{
	local XComGameState_Unit SavedUnit;

	super.InitSoldier(Unit, CharacterPoolData);

	`LOG("Attempting to load unit:" @ Unit.GetFullName(),, 'IRITEST');
	SavedUnit = LoadUnitState(Unit.GetFullName()); // CRASH IS HERE
	/*if (SavedUnit != none)
	{
		`LOG("Found saved unit for:" @ Unit.GetFullName() @ ", copying appearance store.",, 'IRITEST');
		Unit.AppearanceStore = SavedUnit.AppearanceStore;
	}
	else `LOG("Did NOT found saved unit for:" @ Unit.GetFullName(),, 'IRITEST');*/
}

// Doesn't appear to be getting called.
function LoadCharacterPool()
{
	`LOG(GetFuncName() @ "called" @ CharacterPool.Length,, 'IRITEST');

	super.LoadCharacterPool();
}

function SaveCharacterPool()
{
	local XComGameState_Unit UnitState;

	`LOG(GetFuncName() @ "called",, 'IRITEST');

	foreach CharacterPool(UnitState)
	{
		SaveUnitState(UnitState);
	}

	super.SaveCharacterPool();
}

private function SaveUnitState(const XComGameState_Unit UnitState)
{
    local bool Success;

    Success = class'Engine'.static.BasicSaveObject(UnitState, GetFileNameFromSoldierName(UnitState.GetFullName()), false, 1);

    `LOG("Saved unit:" @ UnitState.GetFullName() @ Success @ GetFileNameFromSoldierName(UnitState.GetFullName()),, 'IRITEST');
}

private function XComGameState_Unit LoadUnitState(const string strSoldierName)
{
	local XComGameState_Unit UnitState;
    local bool Success;
   
    Success = class'Engine'.static.BasicLoadObject(UnitState, GetFileNameFromSoldierName(strSoldierName), false, 1);

	`LOG("Loaded unit:" @ UnitState.GetFullName() @ Success @ GetFileNameFromSoldierName(strSoldierName),, 'IRITEST');

	return UnitState;
}

static private function string GetFileNameFromSoldierName(string strSoldierName)
{
	return class'Engine'.static.GetEnvironmentVariable("USERPROFILE") $ CharPoolPath $ name(strSoldierName) $ ".bin";
}