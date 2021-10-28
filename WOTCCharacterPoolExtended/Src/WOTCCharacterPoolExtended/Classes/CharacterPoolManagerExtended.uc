class CharacterPoolManagerExtended extends CharacterPoolManager dependson(CPUnitData);

// This class is a replacement for the game's own CharacterPoolManager with some extra functions and modifications.
// The biggest difference is that in the addition to game's own .bin CP files, we also use "extended" format
// in the form of CPUnitData class, which also stores units' appearance store.
// Other big difference is that we validate units' appearance (to remove broken body parts caused by removed mods)
// only if the mod is configured to do so via MCM. 
// This is done so that people's Character Pool isn't immediately broken the moment they dare to run the game with a few mods disabled.

var private CPUnitData UnitData; // Use GetUnitData() before accessing it

var string CharPoolExtendedFilePath;

`include(WOTCCharacterPoolExtended\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

// ============================================================================
// OVERRIDDEN CHARACTER POOL MANAGER FUNCTIONS

// Modified version of super.InitSoldier()
simulated final function InitSoldierOld(XComGameState_Unit Unit, const out CharacterPoolDataElement CharacterPoolData)
{
	local XGCharacterGenerator CharacterGenerator;
	local TSoldier             CharacterGeneratorResult;

	`CPOLOG("called for unit:" @ Unit.GetFullName());

	Unit.SetSoldierClassTemplate(CharacterPoolData.m_SoldierClassTemplateName);
	Unit.SetCharacterName(CharacterPoolData.strFirstName, CharacterPoolData.strLastName, CharacterPoolData.strNickName);
	Unit.SetTAppearance(CharacterPoolData.kAppearance);
	Unit.SetCountry(CharacterPoolData.Country);
	Unit.SetBackground(CharacterPoolData.BackgroundText);

	Unit.bAllowedTypeSoldier = CharacterPoolData.AllowedTypeSoldier;
	Unit.bAllowedTypeVIP = CharacterPoolData.AllowedTypeVIP;
	Unit.bAllowedTypeDarkVIP = CharacterPoolData.AllowedTypeDarkVIP;

	Unit.PoolTimestamp = CharacterPoolData.PoolTimestamp;

	if (!(Unit.bAllowedTypeSoldier || Unit.bAllowedTypeVIP || Unit.bAllowedTypeDarkVIP))
		Unit.bAllowedTypeSoldier = true;

	// ADDED
	// Skip appearance validation if MCM says so
	if (!`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_DEBUG) || 
		`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_REVIEW))
		return;
	// END OF ADDED

	//No longer re-creates the entire character, just set the invalid attributes to the first element
	//if (!ValidateAppearance(CharacterPoolData.kAppearance))
	if (!FixAppearanceOfInvalidAttributes(Unit.kAppearance))
	{
		//This should't fail now that we attempt to fix invalid attributes
		CharacterGenerator = `XCOMGRI.Spawn(Unit.GetMyTemplate().CharacterGeneratorClass);
		`assert(CharacterGenerator != none);
		CharacterGeneratorResult = CharacterGenerator.CreateTSoldierFromUnit(Unit, none);
		Unit.SetTAppearance(CharacterGeneratorResult.kAppearance);
	}
}

event InitSoldier( XComGameState_Unit Unit, const out CharacterPoolDataElement CharacterPoolData )
{
	`CPOLOG("called for unit:" @ Unit.GetFullName());

	InitSoldierOld(Unit, CharacterPoolData);
	GetUnitData();
	UnitData.LoadExtraData(Unit);
}

function SaveCharacterPool()
{
	`CPOLOG("called");

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

// Serialize all character pool units, including their appearance store, into the "extended" Character Pool file format, and write it to disk.
final function SaveCharacterPoolExtended()
{
	//local CPExtendedStruct		CPExtendedUnitData;
	//local CPExtendedStruct		EmptyCPExtendedUnitData;
	local bool					Success;
	local XComGameState_Unit	UnitState;

	//UnitData = new class'CPUnitData';
	GetUnitData();

	foreach CharacterPool(UnitState)
	{
		//CPExtendedUnitData = EmptyCPExtendedUnitData;

		//FillCharacterPoolData(UnitState); // This saves UnitState to 'CharacterPoolSerializeHelper' 

		UnitData.UpdateOrAddUnit(UnitState);
		//CPExtendedUnitData.CharacterPoolData = CharacterPoolSerializeHelper;
		//CPExtendedUnitData.AppearanceStore = UnitState.AppearanceStore;
		//CPExtendedUnitData.bIsUniform = IsUnitUniform(UnitState);
		//CPExtendedUnitData.bIsAnyClassUniform = class'Help'.static.IsUnitAnyClassUniform(UnitState);

		//UnitData.CharacterPoolDatas.AddItem(CPExtendedUnitData);

		`CPOLOG("Adding" @ UnitState.GetFullName() @ "to CPUnitData, including stored appearances:" @ UnitState.AppearanceStore.Length);
	}

    Success = SaveDefaultCharacterPool();

    `CPOLOG("Was able to successfully write Extended Character Pool file to disk:" @ Success);
}

final function bool SaveDefaultCharacterPool()
{
	return class'Engine'.static.BasicSaveObject(UnitData, class'Engine'.static.GetEnvironmentVariable("USERPROFILE") $ CharPoolExtendedFilePath, false, 1);
}

// Read the "extended" Character Pool file from disk.
final function CPUnitData GetUnitData()
{
	if (UnitData != none)
		return UnitData;

	UnitData = new class'CPUnitData';
	
	if (class'Engine'.static.BasicLoadObject(UnitData, class'Engine'.static.GetEnvironmentVariable("USERPROFILE") $ CharPoolExtendedFilePath, false, 1))
	{
		`CPOLOG("Successfully loaded Extended Character Pool file.");
	}
	else 
	{
		`CPOLOG("Failed to load Extended Character Pool file, attempting to recreate.");
		SaveCharacterPoolExtended();
	}
}

final function string GetUnitFullNameExtraData_Index(const int Index)
{
	local XComGameState_Unit UnitState;
	
	UnitState = CharacterPool[Index];

	return GetUnitFullNameExtraData_UnitState_Static(UnitState);
}

static final function string GetUnitFullNameExtraData_UnitState_Static(const XComGameState_Unit UnitState)
{
	local X2SoldierClassTemplate ClassTemplate;
	local string SoldierString;

	ClassTemplate = UnitState.GetSoldierClassTemplate();
	if (ClassTemplate != none)
	{
		SoldierString = ClassTemplate.DisplayName $ ": ";
	}
	else
	{
		SoldierString = "";
	}

	if (UnitState.GetNickName() != "")
	{
		SoldierString $= UnitState.GetFirstName() @ "\"" $ UnitState.GetNickName() $ "\"" @ UnitState.GetLastName();
	}
	else
	{
		SoldierString $= UnitState.GetFirstName() @ UnitState.GetLastName();
	}
	return SoldierString;
}

// Helper method that fixes unit's appearance if they have bodyparts from mods that are not currently active.
simulated final function ValidateUnitAppearance(XComGameState_Unit UnitState)
{
	local XGCharacterGenerator CharacterGenerator;
	local TSoldier             CharacterGeneratorResult;

	if (!FixAppearanceOfInvalidAttributes(UnitState.kAppearance))
	{
		CharacterGenerator = `XCOMGRI.Spawn(UnitState.GetMyTemplate().CharacterGeneratorClass);
		if (CharacterGenerator != none)
		{
			CharacterGeneratorResult = CharacterGenerator.CreateTSoldierFromUnit(UnitState, none);
			UnitState.SetTAppearance(CharacterGeneratorResult.kAppearance);
		}
	}
}

// ---------------------------------------------------------------------------
// UNIFORM STATUS
final function bool IsUnitUniform(XComGameState_Unit UnitState)
{
	GetUnitData();

	if (UnitData != none)
	{
		return UnitData.IsUnitUniform(UnitState);
	}
	return false;
}

final function bool IsUnitAnyClassUniform(XComGameState_Unit UnitState)
{
	GetUnitData();

	if (UnitData != none)
	{
		return UnitData.IsUnitAnyClassUniform(UnitState);
	}
	return false;
}

final function SetIsUnitUniform(XComGameState_Unit UnitState, bool bValue)
{
	GetUnitData();

	if (UnitData != none)
	{
		UnitData.SetIsUnitUniform(UnitState, bValue);
		SaveDefaultCharacterPool();
	}
}

final function SetIsUnitAnyClassUniform(XComGameState_Unit UnitState, bool bValue)
{
	GetUnitData();

	if (UnitData != none)
	{
		UnitData.SetIsUnitAnyClassUniform(UnitState, bValue);
		SaveDefaultCharacterPool();
	}
}

final function bool IsUniformValidForUnit(const XComGameState_Unit UnitState, const XComGameState_Unit UniformUnit)
{	
	return UnitState.GetSoldierClassTemplateName() == UniformUnit.GetSoldierClassTemplateName() || IsUnitAnyClassUniform(UniformUnit);
}

final function array<CosmeticOptionStruct> GetCosmeticOptionsForUnit(const XComGameState_Unit UnitState, const string GenderArmorTemplate)
{
	local array<CosmeticOptionStruct> EmptyArray;

	GetUnitData();
	if (UnitData != none)
	{
		return UnitData.GetCosmeticOptionsForUnit(UnitState, GenderArmorTemplate);
	}

	EmptyArray.Length = 0; // Get rid of compile warning
	return EmptyArray;
}

final function SaveCosmeticOptionsForUnit(const array<CosmeticOptionStruct> CosmeticOptions, const XComGameState_Unit UnitState, const string GenderArmorTemplate)
{
	GetUnitData();
	if (UnitData != none)
	{
		`CPOLOG(CosmeticOptions.length @ UnitState.GetFullName() @ GenderArmorTemplate);
		UnitData.SaveCosmeticOptionsForUnit(CosmeticOptions, UnitState, GenderArmorTemplate);
		SaveDefaultCharacterPool();
	}
}

final function bool GetUniformAppearanceForUnit(out TAppearance NewAppearance, const XComGameState_Unit UnitState, const name ArmorTemplateName)
{
	local array<XComGameState_Unit> UniformStates;
	local XComGameState_Unit		UniformState;
	
	UniformStates = GetClassSpecificUniforms(ArmorTemplateName, NewAppearance.iGender, UnitState.GetSoldierClassTemplateName());
	if (UniformStates.Length > 0)
	{
		UniformState = UniformStates[`SYNC_RAND(UniformStates.Length)];

		`CPOLOG("Selected random class uniform:" @ UniformState.GetFullName() @ "Out of possible:" @ UniformStates.Length);

		CopyUniformAppearance(NewAppearance, UniformState, ArmorTemplateName);
		return true;		
	}

	UniformStates = GetAnyClassUniforms(ArmorTemplateName, NewAppearance.iGender);
	if (UniformStates.Length > 0)
	{
		UniformState = UniformStates[`SYNC_RAND(UniformStates.Length)];

		`CPOLOG("Selected random ANY class uniform:" @ UniformState.GetFullName() @ "Out of possible:" @ UniformStates.Length);

		CopyUniformAppearance(NewAppearance, UniformState, ArmorTemplateName);
		return true;
	}

	return false;
}

private function array<XComGameState_Unit> GetClassSpecificUniforms(const name ArmorTemplateName, const int iGender, const name SoldierClass)
{
	local array<XComGameState_Unit> UniformStates;
	local XComGameState_Unit		UniformState;

	foreach CharacterPool(UniformState)
	{
		if (IsUnitUniform(UniformState) && 
			!IsUnitAnyClassUniform(UniformState) && 
			UniformState.GetSoldierClassTemplateName() == SoldierClass && 
			UniformState.HasStoredAppearance(iGender, ArmorTemplateName))
		{
			UniformStates.AddItem(UniformState);
		}
	}
	return UniformStates;
}
private function array<XComGameState_Unit> GetAnyClassUniforms(const name ArmorTemplateName, const int iGender)
{
	local array<XComGameState_Unit> UniformStates;
	local XComGameState_Unit		UniformState;

	foreach CharacterPool(UniformState)
	{
		if (IsUnitUniform(UniformState) && 
			IsUnitAnyClassUniform(UniformState) &&
			UniformState.HasStoredAppearance(iGender, ArmorTemplateName))
		{
			UniformStates.AddItem(UniformState);
		}
	}
	return UniformStates;
}


private function CopyUniformAppearance(out TAppearance NewAppearance, const XComGameState_Unit UniformState, const name ArmorTemplateName)
{
	local TAppearance					UniformAppearance;
	local array<CosmeticOptionStruct>	CosmeticOptions;
	local bool							bGenderChange;
	local string						GenderArmorTemplate;

	UniformState.GetStoredAppearance(UniformAppearance, NewAppearance.iGender, ArmorTemplateName);

	GetUnitData();
	if (UnitData != none)
	{
		GenderArmorTemplate = ArmorTemplateName $ NewAppearance.iGender;
		CosmeticOptions = UnitData.GetCosmeticOptionsForUnit(UniformState, GenderArmorTemplate);
	}
	if (CosmeticOptions.Length > 0)
	{	
		if (ShouldCopyUniformPiece('iGender', CosmeticOptions))
		{
			bGenderChange = true;
			NewAppearance.iGender = UniformAppearance.iGender; 
			NewAppearance.nmPawn = UniformAppearance.nmPawn;
			NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
			NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
			NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
		}
		if (bGenderChange || NewAppearance.iGender == UniformAppearance.iGender)
		{		
			if (ShouldCopyUniformPiece('nmHead', CosmeticOptions)) {NewAppearance.nmHead = UniformAppearance.nmHead; NewAppearance.nmEye = UniformAppearance.nmEye; NewAppearance.nmTeeth = UniformAppearance.nmTeeth; NewAppearance.iRace = UniformAppearance.iRace;}
			//if (ShouldCopyUniformPiece('iRace', CosmeticOptions)) NewAppearance.iRace = UniformAppearance.iRace;
			if (ShouldCopyUniformPiece('nmHaircut', CosmeticOptions)) NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
			//if (ShouldCopyUniformPiece('iFacialHair', CosmeticOptions)) NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
			if (ShouldCopyUniformPiece('nmBeard', CosmeticOptions)) NewAppearance.nmBeard = UniformAppearance.nmBeard;
			//if (ShouldCopyUniformPiece('iVoice', CosmeticOptions)) NewAppearance.iVoice = UniformAppearance.iVoice;
			if (ShouldCopyUniformPiece('nmTorso', CosmeticOptions)) NewAppearance.nmTorso = UniformAppearance.nmTorso;
			if (ShouldCopyUniformPiece('nmArms', CosmeticOptions)) NewAppearance.nmArms = UniformAppearance.nmArms;
			if (ShouldCopyUniformPiece('nmLegs', CosmeticOptions)) NewAppearance.nmLegs = UniformAppearance.nmLegs;
			if (ShouldCopyUniformPiece('nmHelmet', CosmeticOptions)) NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
			if (ShouldCopyUniformPiece('nmFacePropLower', CosmeticOptions)) NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
			if (ShouldCopyUniformPiece('nmFacePropUpper', CosmeticOptions)) NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
			if (ShouldCopyUniformPiece('nmVoice', CosmeticOptions)) NewAppearance.nmVoice = UniformAppearance.nmVoice;
			if (ShouldCopyUniformPiece('nmScars', CosmeticOptions)) NewAppearance.nmScars = UniformAppearance.nmScars;
			//if (ShouldCopyUniformPiece('nmTorso_Underlay', CosmeticOptions)) NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
			//if (ShouldCopyUniformPiece('nmArms_Underlay', CosmeticOptions)) NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
			//if (ShouldCopyUniformPiece('nmLegs_Underlay', CosmeticOptions)) NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
			if (ShouldCopyUniformPiece('nmFacePaint', CosmeticOptions)) NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;
			if (ShouldCopyUniformPiece('nmLeftArm', CosmeticOptions)) NewAppearance.nmLeftArm = UniformAppearance.nmLeftArm;
			if (ShouldCopyUniformPiece('nmRightArm', CosmeticOptions)) NewAppearance.nmRightArm = UniformAppearance.nmRightArm;
			if (ShouldCopyUniformPiece('nmLeftArmDeco', CosmeticOptions)) NewAppearance.nmLeftArmDeco = UniformAppearance.nmLeftArmDeco;
			if (ShouldCopyUniformPiece('nmRightArmDeco', CosmeticOptions)) NewAppearance.nmRightArmDeco = UniformAppearance.nmRightArmDeco;
			if (ShouldCopyUniformPiece('nmLeftForearm', CosmeticOptions)) NewAppearance.nmLeftForearm = UniformAppearance.nmLeftForearm;
			if (ShouldCopyUniformPiece('nmRightForearm', CosmeticOptions)) NewAppearance.nmRightForearm = UniformAppearance.nmRightForearm;
			if (ShouldCopyUniformPiece('nmThighs', CosmeticOptions)) NewAppearance.nmThighs = UniformAppearance.nmThighs;
			if (ShouldCopyUniformPiece('nmShins', CosmeticOptions)) NewAppearance.nmShins = UniformAppearance.nmShins;
			if (ShouldCopyUniformPiece('nmTorsoDeco', CosmeticOptions)) NewAppearance.nmTorsoDeco = UniformAppearance.nmTorsoDeco;
		}
		if (ShouldCopyUniformPiece('iHairColor', CosmeticOptions)) NewAppearance.iHairColor = UniformAppearance.iHairColor;
		if (ShouldCopyUniformPiece('iSkinColor', CosmeticOptions)) NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
		if (ShouldCopyUniformPiece('iEyeColor', CosmeticOptions)) NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
		if (ShouldCopyUniformPiece('nmFlag', CosmeticOptions)) NewAppearance.nmFlag = UniformAppearance.nmFlag;
		if (ShouldCopyUniformPiece('iAttitude', CosmeticOptions)) NewAppearance.iAttitude = UniformAppearance.iAttitude;
		//if (ShouldCopyUniformPiece('iArmorDeco', CosmeticOptions)) NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
		if (ShouldCopyUniformPiece('iArmorTint', CosmeticOptions)) NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
		if (ShouldCopyUniformPiece('iArmorTintSecondary', CosmeticOptions)) NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
		if (ShouldCopyUniformPiece('iWeaponTint', CosmeticOptions)) NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
		if (ShouldCopyUniformPiece('iTattooTint', CosmeticOptions)) NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
		if (ShouldCopyUniformPiece('nmWeaponPattern', CosmeticOptions)) NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
		if (ShouldCopyUniformPiece('nmPatterns', CosmeticOptions)) NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
		//if (ShouldCopyUniformPiece('nmLanguage', CosmeticOptions)) NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
		if (ShouldCopyUniformPiece('nmTattoo_LeftArm', CosmeticOptions)) NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
		if (ShouldCopyUniformPiece('nmTattoo_RightArm', CosmeticOptions)) NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;
		//if (ShouldCopyUniformPiece('bGhostPawn', CosmeticOptions)) NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;
	}
	else
	{
		class'UICustomize_CPExtended'.static.CopyAppearance_Static(NewAppearance, UniformAppearance, 'PresetUniform');
	}
}

private function bool ShouldCopyUniformPiece(const name OptionName, const out array<CosmeticOptionStruct> CosmeticOptions)
{
	local int Index;

	Index = CosmeticOptions.Find('OptionName', OptionName);
	if (Index != INDEX_NONE)
	{
		return CosmeticOptions[Index].bChecked;
	}
	return false;
}

final function bool IsCharacterPoolCharacter(const XComGameState_Unit UnitState)
{
	local int Index;	

	for (Index = 0; Index < CharacterPool.Length; ++Index)
	{
		if (UnitState.GetFullName() == CharacterPool[Index].GetFullName())
		{
			return true;
		}
	}

	return false;
}

final function bool ShouldAutoManageUniform(const XComGameState_Unit UnitState)
{
	return `XOR(`GETMCMVAR(AUTOMATIC_UNIFORM_MANAGEMENT), IsAutoManageUniformFlagSet(UnitState));
}

final function bool IsAutoManageUniformFlagSet(const XComGameState_Unit UnitState)
{
	local UnitValue UV;

	if (IsCharacterPoolCharacter(UnitState))
	{
		GetUnitData();
		if (UnitData != none)
		{
			return UnitData.ShouldAutoManageUniform(UnitState);
		}
		return false;
	}
	return UnitState.GetUnitValue(class'UISL_CPExtended'.default.AutoManageUniformValueName, UV);
}

final function SetAutoManageUniform(const XComGameState_Unit UnitState, const bool bValue)
{
	GetUnitData();
	if (UnitData != none)
	{
		UnitData.SetAutoManageUniform(UnitState, bValue);
		SaveDefaultCharacterPool();
	}
}


// ---------------------------------------------------------------------------

// ============================================================================
// INTERNAL HELPERS

private function PrintCP()
{
	local XComGameState_Unit UnitState;
	local int i;

	`CPOLOG("####" @ GetFuncName() @ "BEGIN");

	foreach CharacterPool(UnitState, i)
	{
		`CPOLOG(i @ UnitState.GetFullName());
	}

	`CPOLOG("####" @ GetFuncName() @ "END");
}

// ============================================================================
// These don't appear to be getting called.
/*
function LoadCharacterPool()
{
	`CPOLOG(GetFuncName() @ "called" @ CharacterPool.Length);

	super.LoadCharacterPool();
}

function LoadBaseGameCharacterPool()
{
	`CPOLOG(GetFuncName() @ "before called" @ CharacterPool.Length);

	super.LoadBaseGameCharacterPool();

	`CPOLOG(GetFuncName() @ "after called" @ CharacterPool.Length);
}
*/

defaultproperties
{
	CharPoolExtendedFilePath = "\\Documents\\my games\\XCOM2 War of the Chosen\\XComGame\\CharacterPool\\CharacterPoolExtended.bin"
}