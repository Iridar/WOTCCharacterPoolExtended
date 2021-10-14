class UIArmory_Photobooth_CPExtended extends UIArmory_Photobooth;

// Currently unused, leftovers from the experiment of entering PB from CP.

var array<XComGameState_Unit> PossibleUnits;

function UpdateSoldierData()
{
	PossibleUnits = `CHARACTERPOOLMGR.CharacterPool;
}

function SetSoldier(int LocationIndex, int SoldierIndex)
{
	local array<StateObjectReference> arrSoldiers;
	local StateObjectReference Soldier;

	if (SoldierIndex < 0)
	{
		Soldier.ObjectID = 0;
	}
	else
	{
		`PHOTOBOOTH.GetPossibleSoldiers(LocationIndex, m_arrSoldiers, arrSoldiers);
		Soldier = arrSoldiers[SoldierIndex];
	}	

	`PHOTOBOOTH.SetSoldier(LocationIndex, Soldier, false, SoldierPawnCreated);
}

function GetSoldierData(int LocationIndex, out array<String> outSoldierNames, out int outSoldierIndex)
{
	local XComGameStateHistory History;
	local XComGameState_Unit Unit;
	local array<StateObjectReference> arrPossibleSoldiers;
	local int i;

	History = `XCOMHISTORY;	
	outSoldierIndex = `PHOTOBOOTH.GetPossibleSoldiers(LocationIndex, m_arrSoldiers, arrPossibleSoldiers);

	outSoldierNames.Length = 0;
	outSoldierNames.AddItem(m_strEmptyOption);
	outSoldierIndex++;

	for (i = 0; i < arrPossibleSoldiers.Length; ++i)
	{		
		Unit = XComGameState_Unit(History.GetGameStateForObjectID(arrPossibleSoldiers[i].ObjectID));
		outSoldierNames.AddItem(Unit.GetName(eNameType_Full));
	}
}