class UICustomize_CPExtended extends UICustomize;

struct CheckboxPresetStruct
{
	var name Preset;
	var name CheckboxName;
	var bool bChecked;
};
var config(WOTCCharacterPoolExtended_DEFAULT) array<CheckboxPresetStruct> CheckboxPresetsDefaults;
var config(CharacterPoolExtended_NULLCONFIG) array<CheckboxPresetStruct> CheckboxPresets;

var config(WOTCCharacterPoolExtended_DEFAULT) array<name> Presets;

// TODO:
/*
Works with Unrestricted Customization?

Make clicking an item toggle its checkbox?
Fix weapons / Dual Wielding not working in CP?
Search bar for CP units?
Preview background (biography) change
Soldier Class filtering for uniforms (maybe add "universal uniform" checbox? Store status as unit value?
Maybe add "reskin armor" button?
Scars and beards (facial hair) had none -> none conversions, fix it.
Enter photobooth from CP?
Per-uniform selection of which parts of the appearance are a part of the uniform.
Choose stored appearance on the customize screen?

'Show all' checkbox for the cosmetics list
Validate appearance button should work in armory? Should probably remove stored appearance, or validate all stored appearances

// Classes up to UICustomize_CPExtended (not counting) are licked up.

## Checks:
1. Check if you can customize a unit with all armors in the campaign, then save them into CP, and that they will actually have all that appearance in the next campaign
2. Working with character pool files: creating new one, creating (importing) an existing one, deleting. exporting/importing units with appearance store.

## Finalization
0. Clean up everything. Commentate. Add private/final.
0.5 Localize stuff.
1. Get rid of the logs or clean them up and turn them off
2. Fix log error spam.

## Ideas for later
1. Equipping weapons in CP will reskin them automatically with XSkin (RustyDios). Probably use a Tuple.
*/

// Internal cached info
var private CharacterPoolManagerExtended		PoolMgr;
var private X2BodyPartTemplateManager			BodyPartMgr;
var private X2StrategyElementTemplateManager	StratMgr;
var private X2ItemTemplateManager				ItemMgr;
var private	XComGameStateHistory				History;
var private bool								bRefreshPawn;
var private bool								bUniformMode;
var private name								CurrentPreset;

// Info about selected CP unit
var private TAppearance						SelectedAppearance;
var private X2SoldierPersonalityTemplate	SelectedAttitude;
var private bool							bNoChangeSelected;
var private XComGameState_Unit				SelectedUnit;

// Info about Armory unit
var private XComHumanPawn					ArmoryPawn;
var private XComGameState_Unit				ArmoryUnit;
var private vector							OriginalPawnLocation;
var private TAppearance						OriginalAppearance; // Appearance to restore if the player exits the screen without selecting anything
var private name							ArmorTemplateName;
var private X2SoldierPersonalityTemplate	OriginalAttitude;

// Left list with lotta checkboxes for selecting which parts of the CP unit appearance are being carried over.
var private UIBGBox OptionsBG;
var private UIList	OptionsList;

// Upper right list with a few checkboxes for filtering the list of CP units
var private UIBGBox FiltersBG;
var private UIList	FiltersList;

// ================================================================================================================================================
// INITIAL SETUP - called once when screen is pushed, or when switching to a new armory unit.

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local UIScreen	   CycleScreen;
	local UIMouseGuard MouseGuard;

	`LOG(GetFuncName() @ CheckboxPresets.Length @ default.CheckboxPresets.Length,, 'IRITEST');

	super.InitScreen(InitController, InitMovie, InitName);

	// Cache stuff.
	PoolMgr = CharacterPoolManagerExtended(`CHARACTERPOOLMGR);
	if (PoolMgr == none)
		super.CloseScreen();

	BodyPartMgr = class'X2BodyPartTemplateManager'.static.GetBodyPartTemplateManager();
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	History = `XCOMHISTORY;
	CacheArmoryUnitData();

	// 'List' of soldiers whose appearance you can copy.
	List.OnItemClicked = SoldierListItemClicked;
	List.SetPosition(1920 - List.Width - 70, 360);
	List.SetHeight(300);

	ListBG.SetPosition(1920 - List.Width - 80, 345);
	ListBG.SetHeight(730);

	// Mouse guard dims the entire screen when this UIScreen is spawned, not sure why.
	// Setting it to 3D seems to fix it.
	foreach Movie.Pres.ScreenStack.Screens(CycleScreen)
	{
		MouseGuard = UIMouseGuard(CycleScreen);
		if (MouseGuard == none)
			continue;

		MouseGuard.bIsIn3D = true;
		MouseGuard.SetAlpha(0);
	}

	// Move the soldier name header further into the left upper corner.
	Header.SetPosition(20 + Header.Width, 20);
	
	// Create left list	of soldier customization options.
	OptionsBG = Spawn(class'UIBGBox', self).InitBG('LeftOptionsListBG', 20, 180);
	OptionsBG.SetAlpha(80);
	OptionsBG.SetWidth(582);
	OptionsBG.SetHeight(1080 - 70 - OptionsBG.Y);

	OptionsList = Spawn(class'UIList', self);
	OptionsList.bAnimateOnInit = false;
	OptionsList.InitList('LeftOptionsList', 30, 190);
	OptionsList.SetWidth(542);
	OptionsList.SetHeight(1080 - 80 - OptionsList.Y);
	OptionsList.Navigator.LoopSelection = true;
	OptionsList.OnItemClicked = OptionsListItemClicked;
	
	OptionsBG.ProcessMouseEvents(List.OnChildMouseEvent);

	// Create upper right list
	CreateFiltersList();
}

simulated private function CreateFiltersList()
{
	local UIMechaListItem SpawnedItem;

	FiltersBG = Spawn(class'UIBGBox', self).InitBG('UpperRightFiltersListBG', ListBG.X, 10);
	FiltersBG.SetAlpha(80);
	FiltersBG.SetWidth(582);
	FiltersBG.SetHeight(330);

	FiltersList = Spawn(class'UIList', self);
	FiltersList.bAnimateOnInit = false;
	FiltersList.InitList('UpperRightFiltersList', List.X, 20);
	FiltersList.SetWidth(542);
	FiltersList.SetHeight(310);
	FiltersList.Navigator.LoopSelection = true;
	//FiltersList.OnItemClicked = FiltersListItemClicked;
	
	FiltersBG.ProcessMouseEvents(FiltersList.OnChildMouseEvent);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.SetDisabled(true);
	SpawnedItem.UpdateDataDescription("APPLY TO"); // TODO: Localize

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('ApplyToThisUnit');
	SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS("This unit"), "", true, none, none);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('ApplyToSquad');
	SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS("squad"), "", false, none, none);

	if (bInArmory)
	{
		SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('ApplyToBarracks');
		SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS("barracks"), "", false, none, none);
	}
	else
	{
		SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('ApplyToCharPool');
		SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS("Character Pool"), "", false, none, none);
	}

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.SetDisabled(true);
	SpawnedItem.UpdateDataDescription("FILTERS"); // TODO: Localize

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('FilterGender');
	SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(class'UICustomize_Info'.default.m_strGender), "", true, FilterCheckboxChanged, none);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('FilterClass');
	SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(class'UIPersonnel'.default.m_strButtonLabels[ePersonnelSoldierSortType_Class]), "", false, FilterCheckboxChanged, none);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('FilterArmorAppearance');
	SpawnedItem.SetDisabled(ArmorTemplateName == '', "No armor template on the unit" @ ArmoryUnit.GetFullName());
	SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS("Armor Appearance"), "", true, FilterCheckboxChanged, none); // TODO: Localize
}

simulated private function FilterCheckboxChanged(UICheckbox CheckBox)
{
	UpdateSoldierList();
}
/*
simulated function FiltersListItemClicked(UIList ContainerList, int ItemIndex)
{
	local UIMechaListItem ListItem;
	
	ListItem = UIMechaListItem(FiltersList.GetItem(ItemIndex));
	if (ListItem != none)
	{
		ListItem.Checkbox.SetChecked(!ListItem.Checkbox.bChecked, true);
		//UpdateSoldierList();
	}
}*/

simulated function CacheArmoryUnitData()
{
	local X2ItemTemplate ArmorTemplate;

	ArmoryUnit = CustomizeManager.UpdatedUnitState;
	if (ArmoryUnit == none)
		super.CloseScreen();

	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn == none)
		super.CloseScreen();

	ArmorTemplate = class'Help'.static.GetItemTemplateFromCosmeticTorso(ArmoryPawn.m_kAppearance.nmTorso);
	if (ArmorTemplate != none)
	{
		ArmorTemplateName = ArmorTemplate.DataName;
	}

	OriginalAppearance = ArmoryPawn.m_kAppearance;
	SelectedAppearance = OriginalAppearance;
	OriginalAttitude = ArmoryUnit.GetPersonalityTemplate();

	UpdatePawnLocation();
}

simulated static function CycleToSoldier(StateObjectReference NewRef)
{
	local UICustomize_CPExtended CustomizeScreen;
	super.CycleToSoldier(NewRef);

	CustomizeScreen = UICustomize_CPExtended(`SCREENSTACK.GetFirstInstanceOf(class'UICustomize_CPExtended'));
	if (CustomizeScreen != none)
	{
		CustomizeScreen.CacheArmoryUnitData();
		CustomizeScreen.UpdateOptionsList();
	}
}

simulated function UpdateData()
{
	super.UpdateData();

	UpdateSoldierList();
	UpdateOptionsList();
}
/*
simulated function UpdateNavHelp()
{
	super.UpdateNavHelp();

	NavHelp.AddLeftHelp("UNIFORM MODE:" $ bUniformMode ? "ON" : "OFF",			
				class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RT_R2, 
				OnUniformButtonClicked,
				false,
				"Tooltip placeholder",
				class'UIUtilities'.const.ANCHOR_BOTTOM_CENTER);
}

simulated private function OnUniformButtonClicked()
{
	bUniformMode = !bUniformMode;
	UpdateNavHelp();

	UpdateOptionsList();
	UpdateUnitAppearance();	
	UpdatePawnAttitudeAnimation();
}
*/
simulated private function OnEntireUnitButtonClicked()
{
	SetCheckbox('nmHead', true);
	SetCheckbox('iGender', true);
	SetCheckbox('iRace', true);
	SetCheckbox('nmHaircut', true);
	SetCheckbox('iHairColor', true);
	SetCheckbox('iFacialHair', true);
	SetCheckbox('nmBeard', true);
	SetCheckbox('iSkinColor', true);
	SetCheckbox('iEyeColor', true);
	SetCheckbox('nmFlag', true);
	SetCheckbox('iVoice', true);
	SetCheckbox('iAttitude', true);
	SetCheckbox('iArmorDeco', true);
	SetCheckbox('iArmorTint', true);
	SetCheckbox('iArmorTintSecondary', true);
	SetCheckbox('iWeaponTint', true);
	SetCheckbox('iTattooTint', true);
	SetCheckbox('nmWeaponPattern', true);
	SetCheckbox('nmTorso', true);
	SetCheckbox('nmArms', true);
	SetCheckbox('nmLegs', true);
	SetCheckbox('nmHelmet', true);
	SetCheckbox('nmEye', true);
	SetCheckbox('nmTeeth', true);
	SetCheckbox('nmFacePropLower', true);
	SetCheckbox('nmFacePropUpper', true);
	SetCheckbox('nmPatterns', true);
	SetCheckbox('nmVoice', true);
	SetCheckbox('nmLanguage', true);
	SetCheckbox('nmTattoo_LeftArm', true);
	SetCheckbox('nmTattoo_RightArm', true);
	SetCheckbox('nmScars', true);
	SetCheckbox('nmTorso_Underlay', true);
	SetCheckbox('nmArms_Underlay', true);
	SetCheckbox('nmLegs_Underlay', true);
	SetCheckbox('nmFacePaint', true);
	SetCheckbox('nmLeftArm', true);
	SetCheckbox('nmRightArm', true);
	SetCheckbox('nmLeftArmDeco', true);
	SetCheckbox('nmRightArmDeco', true);
	SetCheckbox('nmLeftForearm', true);
	SetCheckbox('nmRightForearm', true);
	SetCheckbox('nmThighs', true);
	SetCheckbox('nmShins', true);
	SetCheckbox('nmTorsoDeco', true);
	SetCheckbox('bGhostPawn', true);

	UpdateUnitAppearance();	
	//UpdatePawnAttitudeAnimation();
}
/*
simulated function UpdateSoldierListOld()
{
	local UIMechaListItem_Soldier			SpawnedItem;
	local XComGameState_Unit				CheckUnit;
	local string							UnitName;
	local XComGameState_HeadquartersXCom	XComHQ;
	local array<XComGameState_Unit>			Soldiers;
	local bool								bCPHeaderSpawned;
	local bool								bBarracksHeaderSpawned;
	local bool								bDeadCrewHeaderSpawned;
	local int i;

	List.ClearItems();

	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.UpdateDataDescription("SELECT UNIT"); // TODO: Localize
	SpawnedItem.SetDisabled(true); 

	// First entry is always "No change"
	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.UpdateDataCheckbox("NO CHANGE", "", true, SoldierCheckboxChanged, none); // TODO: Localize
	SpawnedItem.UnitState = ArmoryUnit;

	// Character pool
	foreach PoolMgr.CharacterPool(CheckUnit, i)
	{
		if (!DoesUnitPassActiveFilters(CheckUnit))
			continue;

		if (!bCPHeaderSpawned)
		{
			bCPHeaderSpawned = true;
			SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
			SpawnedItem.bAnimateOnInit = false;
			SpawnedItem.InitListItem();
			SpawnedItem.UpdateDataDescription("CHARACTER POOL"); // TODO: Localize
			SpawnedItem.SetDisabled(true); 
		}

		UnitName = PoolMgr.GetUnitFullNameExtraData(i);
		if (IsUnitPresentInCampaign(CheckUnit)) // If unit was already drawn from the CP, color their entry green.
			UnitName = class'UIUtilities_Text'.static.GetColoredText(UnitName, eUIState_Good);

		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UpdateDataCheckbox(UnitName, "", false, SoldierCheckboxChanged, none);
		SpawnedItem.UnitState = CheckUnit;
	}
	
	// Soldiers in barracks
	XComHQ = `XCOMHQ;
	Soldiers = XComHQ.GetSoldiers(); 
	foreach Soldiers(CheckUnit)
	{
		if (!DoesUnitPassActiveFilters(CheckUnit))
			continue;

		if (!bBarracksHeaderSpawned)
		{
			bBarracksHeaderSpawned = true;
			SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
			SpawnedItem.bAnimateOnInit = false;
			SpawnedItem.InitListItem();
			SpawnedItem.UpdateDataDescription("BARRACKS"); // TODO: Localize
			SpawnedItem.SetDisabled(true); 
		}

		UnitName = class'CharacterPoolManagerExtended'.static.GetUnitStateFullNameExtraData(CheckUnit);
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UpdateDataCheckbox(UnitName, "", false, SoldierCheckboxChanged, none);
		SpawnedItem.UnitState = CheckUnit;
	}
	// Soldiers in morgue
	Soldiers = GetDeadSoldiers(XComHQ);
	foreach Soldiers(CheckUnit)
	{
		if (!DoesUnitPassActiveFilters(CheckUnit))
			continue;

		if (!bDeadCrewHeaderSpawned)
		{
			bDeadCrewHeaderSpawned = true;
			SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
			SpawnedItem.bAnimateOnInit = false;
			SpawnedItem.InitListItem();
			SpawnedItem.UpdateDataDescription("MORGUE"); // TODO: Localize
			SpawnedItem.SetDisabled(true); 
		}

		UnitName = class'CharacterPoolManagerExtended'.static.GetUnitStateFullNameExtraData(CheckUnit);
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UpdateDataCheckbox(UnitName, "", false, SoldierCheckboxChanged, none);
		SpawnedItem.UnitState = CheckUnit;
	}
}*/

// ================================================================================================================================================
// LIVE UPDATE FUNCTIONS - called when toggling checkboxes or selecting a new CP unit.

simulated function UpdateSoldierList()
{
	local UIMechaListItem_Soldier			SpawnedItem;
	local XComGameState_Unit				CheckUnit;
	local XComGameState_HeadquartersXCom	XComHQ;
	local array<XComGameState_Unit>			Soldiers;
	local bool								bCPHeaderSpawned;
	local bool								bBarracksHeaderSpawned;
	local bool								bDeadCrewHeaderSpawned;
	local int i;

	List.ClearItems();

	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.UpdateDataDescription("SELECT APPEARANCE"); // TODO: Localize
	SpawnedItem.SetDisabled(true); 

	// First entry is always "No change"
	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.UpdateDataCheckbox("NO CHANGE", "", true, SoldierCheckboxChanged, none); // TODO: Localize
	SpawnedItem.StoredAppearance.Appearance = OriginalAppearance;
	SpawnedItem.bNoChange = true;

	// Character pool
	foreach PoolMgr.CharacterPool(CheckUnit, i)
	{
		if (!bCPHeaderSpawned)
		{
			bCPHeaderSpawned = true;
			SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
			SpawnedItem.bAnimateOnInit = false;
			SpawnedItem.InitListItem();
			SpawnedItem.UpdateDataDescription("CHARACTER POOL"); // TODO: Localize
			SpawnedItem.SetDisabled(true); 
		}

		CreateAppearanceStoreEntriesForUnit(CheckUnit, true);
	}
	
	// Soldiers in barracks
	XComHQ = `XCOMHQ;
	Soldiers = XComHQ.GetSoldiers(); 
	foreach Soldiers(CheckUnit)
	{
		if (!bBarracksHeaderSpawned)
		{
			bBarracksHeaderSpawned = true;
			SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
			SpawnedItem.bAnimateOnInit = false;
			SpawnedItem.InitListItem();
			SpawnedItem.UpdateDataDescription("BARRACKS"); // TODO: Localize
			SpawnedItem.SetDisabled(true); 
		}

		CreateAppearanceStoreEntriesForUnit(CheckUnit);
	}
	// Soldiers in morgue
	Soldiers = GetDeadSoldiers(XComHQ);
	foreach Soldiers(CheckUnit)
	{
		if (!bDeadCrewHeaderSpawned)
		{
			bDeadCrewHeaderSpawned = true;
			SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
			SpawnedItem.bAnimateOnInit = false;
			SpawnedItem.InitListItem();
			SpawnedItem.UpdateDataDescription("MORGUE"); // TODO: Localize
			SpawnedItem.SetDisabled(true); 
		}

		CreateAppearanceStoreEntriesForUnit(CheckUnit);
	}
}

simulated private function CreateAppearanceStoreEntriesForUnit(const XComGameState_Unit UnitState, optional bool bCharPool)
{
	local AppearanceInfo		StoredAppearance;
	local X2ItemTemplate		ArmorTemplate;
	local EGender				Gender;
	local name					LocalArmorTemplateName;
	local string				DisplayName;
	local bool					bCurrentAppearance;
	local bool					bCurrentAppearanceFound;
	local string				UnitName;
	local UIMechaListItem_Soldier SpawnedItem;

	if (!IsUnitSameType(UnitState))
		return;

	if (GetFilterListCheckboxStatus('FilterClass') && ArmoryUnit.GetSoldierClassTemplateName() != UnitState.GetSoldierClassTemplateName())
		return;

	UnitName = class'CharacterPoolManagerExtended'.static.GetUnitStateFullNameExtraData(UnitState);
	if (bCharPool && IsUnitPresentInCampaign(UnitState)) // If unit was already drawn from the CP, color their entry green.
			UnitName = class'UIUtilities_Text'.static.GetColoredText(UnitName, eUIState_Good);

	foreach UnitState.AppearanceStore(StoredAppearance)
	{
		Gender = EGender(int(Right(StoredAppearance.GenderArmorTemplate, 1)));
		if (GetFilterListCheckboxStatus('FilterGender') && OriginalAppearance.iGender != Gender)
			continue;

		LocalArmorTemplateName = name(Left(StoredAppearance.GenderArmorTemplate, Len(StoredAppearance.GenderArmorTemplate) - 1));
		if (GetFilterListCheckboxStatus('FilterArmorAppearance') && ArmorTemplateName != LocalArmorTemplateName)
			continue;

		ArmorTemplate = ItemMgr.FindItemTemplate(LocalArmorTemplateName);

		DisplayName = UnitName @ "|";

		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayName @= ArmorTemplate.FriendlyName;
		}
		else
		{
			DisplayName @= string(LocalArmorTemplateName);
		}

		if (Gender == eGender_Male)
		{
			DisplayName @= "|" @ class'XComCharacterCustomization'.default.Gender_Male;
		}
		else if (Gender == eGender_Female)
		{
			DisplayName @= "|" @ class'XComCharacterCustomization'.default.Gender_Female;
		}

		bCurrentAppearance = StoredAppearance.Appearance == UnitState.kAppearance;
		if (bCurrentAppearance)
		{
			bCurrentAppearanceFound = true;

			DisplayName @= "(Current)"; // TODO: Localize
		}
		
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UpdateDataCheckbox(DisplayName, "", false, SoldierCheckboxChanged, none);
		SpawnedItem.StoredAppearance = StoredAppearance;
		SpawnedItem.SetPersonalityTemplate();
		SpawnedItem.UnitState = UnitState;
	}
	if (!bCurrentAppearanceFound)
	{
		Gender = EGender(UnitState.kAppearance.iGender);
		if (GetFilterListCheckboxStatus('FilterGender') && OriginalAppearance.iGender != Gender)
			return;

		// Can't use Item State cuz Character Pool units would have none.
		ArmorTemplate = class'Help'.static.GetItemTemplateFromCosmeticTorso(UnitState.kAppearance.nmTorso);

		if (GetFilterListCheckboxStatus('FilterArmorAppearance') && ArmorTemplateName != ArmorTemplate == none ? '' : ArmorTemplate.DataName)
			return;

		DisplayName = UnitState.GetFullName() @ "|";

		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayName @= ArmorTemplate.FriendlyName;
		}
		else
		{
			DisplayName @= string(LocalArmorTemplateName);
		}

		if (Gender == eGender_Male)
		{
			DisplayName @= "|" @ class'XComCharacterCustomization'.default.Gender_Male;
		}
		else if (Gender == eGender_Female)
		{
			DisplayName @= "|" @ class'XComCharacterCustomization'.default.Gender_Female;
		}
		DisplayName @= "(Current)"; // TODO: Localize
		
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UpdateDataCheckbox(DisplayName, "", false, SoldierCheckboxChanged, none);
		//SpawnedItem.StoredAppearance.GenderArmorTemplate
		SpawnedItem.StoredAppearance.Appearance = UnitState.kAppearance;
		SpawnedItem.SetPersonalityTemplate();
		SpawnedItem.UnitState = UnitState;
	}
}

simulated private function array<XComGameState_Unit> GetDeadSoldiers(XComGameState_HeadquartersXCom XComHQ)
{
	local XComGameState_Unit Soldier;
	local array<XComGameState_Unit> Soldiers;
	local int idx;

	for (idx = 0; idx < XComHQ.DeadCrew.Length; idx++)
	{
		Soldier = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.DeadCrew[idx].ObjectID));

		if (Soldier != none && Soldier.IsSoldier())
		{
			Soldiers.AddItem(Soldier);
		}
	}
	return Soldiers;
}
/*
simulated private function bool DoesUnitPassActiveFilters(const XComGameState_Unit UnitState)
{
	if (!IsUnitSameType(UnitState))
		return false;

	if (GetFilterListCheckboxStatus('FilterGender') && OriginalAppearance.iGender != UnitState.kAppearance.iGender)
		return false;

	if (GetFilterListCheckboxStatus('FilterArmorAppearance') && ArmorTemplateName != '' && !UnitState.HasStoredAppearance(OriginalAppearance.iGender, ArmorTemplateName))
		return false;

	if (GetFilterListCheckboxStatus('FilterClass') && ArmoryUnit.GetSoldierClassTemplateName() != UnitState.GetSoldierClassTemplateName())
		return false;

	return true;
}*/

simulated private function bool IsUnitSameType(const XComGameState_Unit UnitState)
{	
	// TODO: Use this check if Unrestricted Customization is not active
	if (true)
	{
		if (UnitState.GetMyTemplateName() != ArmoryUnit.GetMyTemplateName())
			return false;
	}
	else
	{
		// Filter out SPARKs and other non-soldier units.
		if (ArmoryUnit.UnitSize != UnitState.UnitSize)
				return false;

		if (ArmoryUnit.UnitHeight != UnitState.UnitHeight)
			return false;
	}
	return true;
}

// Don't look at me, that's how CP itself does this check :shrug:
simulated function bool IsUnitPresentInCampaign(const XComGameState_Unit CheckUnit)
{
	local XComGameState_Unit CycleUnit;

	foreach History.IterateByClassType(class'XComGameState_Unit', CycleUnit)
	{
		if (CycleUnit.GetFirstName() == CheckUnit.GetFirstName() &&
			CycleUnit.GetLastName() == CheckUnit.GetLastName())
		{
			return true;
		}
	}
	return false;
}



simulated function bool GetFilterListCheckboxStatus(name FilterName)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(FiltersList.ItemContainer.GetChildByName(FilterName, false));

	return ListItem != none && ListItem.Checkbox.bChecked;
}

simulated private function SoldierCheckboxChanged(UICheckbox CheckBox)
{
	local UIMechaListItem ListItem;
	local int Index;
	local int i;

	Index = List.GetItemIndex(CheckBox.ParentPanel);
	for (i = 0; i < List.ItemCount; i++)
	{
		if (i == Index)
			continue;

		ListItem = UIMechaListItem(List.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none)
			continue;

		ListItem.Checkbox.SetChecked(false, false);
	}

	CheckBox.SetChecked(true, false);
	if (Index != INDEX_NONE)
	{
		OnUnitSelected(Index);
	}
}

simulated function SoldierListItemClicked(UIList ContainerList, int ItemIndex)
{
	SoldierCheckboxChanged(GetListItem(ItemIndex).Checkbox);
}

simulated function UpdatePawnLocation()
{
	local vector PawnLocation;

	OriginalPawnLocation = ArmoryPawn.Location;
	PawnLocation = OriginalPawnLocation;

	PawnLocation.X += 20; // Nudge the soldier pawn to the left a little
	ArmoryPawn.SetLocation(PawnLocation);
}

// ================================================================================================================================================
// HELPER METHODS

simulated private function OnUnitSelected(int ItemIndex)
{
	local UIMechaListItem_Soldier ListItem;

	if (ItemIndex == INDEX_NONE)
		return;

	ListItem = UIMechaListItem_Soldier(List.GetItem(ItemIndex));
	SelectedAppearance = ListItem.StoredAppearance.Appearance;
	SelectedAttitude = ListItem.PersonalityTemplate;
	SelectedUnit = ListItem.UnitState;
	bNoChangeSelected = ListItem.bNoChange;

	if (ArmoryPawn.m_kAppearance.iGender != SelectedAppearance.iGender)
	{
		bRefreshPawn = true;
	} 

	UpdateOptionsList();
	UpdateUnitAppearance();	
}

simulated private function UpdateUnitAppearance()
{
	local TAppearance NewAppearance;

	NewAppearance = OriginalAppearance;
	CopyAppearance(NewAppearance, SelectedAppearance);

	ArmoryUnit.SetTAppearance(NewAppearance);
	ArmoryPawn.SetAppearance(NewAppearance);
	//ArmoryUnit.SetTAppearance(NewAppearance);
	//CustomizeManager.OnCategoryValueChange(eUICustomizeCat_WeaponColor, 0, NewAppearance.iWeaponTint);

	if (bRefreshPawn)
	{
		CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);

		// After ReCreatePawnVisuals, the CustomizeManager.ActorPawn, ArmoryPawn and become 'none'
		// Apparently there's some sort of threading issue at play, so we use an event listener to get a reference to the new pawn with a slight delay.
		//OnRefreshPawn();
		bRefreshPawn = false;
	}	
	else
	{
		UpdatePawnAttitudeAnimation(); // OnRefreshPawn() will call this automatically
	}

	UpdateHeader();
}

// Called from X2EventListener_CPExtended
simulated final function OnRefreshPawn()
{
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	UpdatePawnLocation();
	UpdatePawnAttitudeAnimation();

	`CPOLOG("ArmoryPawn present:" @ ArmoryPawn != none);

	// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
	UIMouseGuard_RotatePawn(`SCREENSTACK.GetFirstInstanceOf(class'UIMouseGuard_RotatePawn')).SetActorPawn(CustomizeManager.ActorPawn);
}

simulated private function UpdatePawnAttitudeAnimation()
{
	if (ArmoryPawn == none)
		return;

	if (IsCheckboxChecked('iAttitude'))
	{
		IdleAnimName = SelectedAttitude.IdleAnimName;
	}
	else
	{
		IdleAnimName = OriginalAttitude.IdleAnimName;
	}
	if (!ArmoryPawn.GetAnimTreeController().IsPlayingCurrentAnimation(IdleAnimName))
	{
		ArmoryPawn.PlayHQIdleAnim(IdleAnimName);
		ArmoryPawn.CustomizationIdleAnim = IdleAnimName;
	}
}

simulated function CloseScreen()
{	
	if (bNoChangeSelected)
	{
		CancelChanges();
	}
	else
	{
		ApplyChanges();
	}
	ArmoryPawn.SetLocation(OriginalPawnLocation);
	SavePresetCheckboxPositions();
	super.CloseScreen();
}

simulated private function SavePresetCheckboxPositions()
{
	local CheckboxPresetStruct	NewStruct;
	local UIMechaListItem		ListItem;
	local int					Index;
	local bool					bFound;
	local int i;

	`LOG(GetFuncName() @ "Options in the list:" @ OptionsList.ItemCount @ "Saved options:" @ CheckboxPresets.Length,, 'IRITEST');

	NewStruct.Preset = CurrentPreset;

	if (Presets.Length > 0)
	{
		i = Presets.Length + 1;
	}
	for (i = i; i < OptionsList.ItemCount; i++) // "i = i" bypasses compile error. Just need to have something in there.
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none)
			continue;

		//if (InStr(string(ListItem.MCName), "UIMechaListItem") != INDEX_NONE)
		//	continue;

		`LOG(i @ "List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ "Checked:" @ ListItem.Checkbox.bChecked,, 'IRITEST');

		bFound = false;
		for (Index = 0; Index < CheckboxPresets.Length; Index++)
		{
			if (CheckboxPresets[Index].CheckboxName == ListItem.MCName &&
				CheckboxPresets[Index].Preset == CurrentPreset)
			{
				CheckboxPresets[Index].bChecked = ListItem.Checkbox.bChecked;
				bFound = true;
				break;
			}
		}

		if (!bFound)
		{
			NewStruct.CheckboxName = ListItem.MCName;
			NewStruct.bChecked = ListItem.Checkbox.bChecked;
			CheckboxPresets.AddItem(NewStruct);
		}
	}
	
	default.CheckboxPresets = CheckboxPresets; // This is actually necessary
	SaveConfig();
}

simulated private function LoadPresetCheckboxPositions()
{
	local UIMechaListItem		ListItem;
	local int					Index;
	local bool					bFound;
	local int i;

	`LOG(GetFuncName() @ "Options in the list:" @ OptionsList.ItemCount @ "Saved options:" @ CheckboxPresets.Length,, 'IRITEST');

	if (Presets.Length > 0)
	{
		i = Presets.Length + 1;
	}
	for (i = i; i < OptionsList.ItemCount; i++) 
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none)
			continue;

		`LOG(i @ "List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ "Checked:" @ ListItem.Checkbox.bChecked,, 'IRITEST');

		bFound = false;
		for (Index = 0; Index < CheckboxPresets.Length; Index++)
		{
			if (CheckboxPresets[Index].CheckboxName == ListItem.MCName &&
				CheckboxPresets[Index].Preset == CurrentPreset)
			{
				ListItem.Checkbox.SetChecked(CheckboxPresets[Index].bChecked, false);
				bFound = true;
				`LOG(i @ "Found non-default entry:" @ CheckboxPresets[Index].bChecked,, 'IRITEST');
				break;
			}
		}

		if (!bFound)
		{
			for (Index = 0; Index < CheckboxPresetsDefaults.Length; Index++)
			{
				if (CheckboxPresetsDefaults[Index].CheckboxName == ListItem.MCName &&
					CheckboxPresetsDefaults[Index].Preset == CurrentPreset)
				{
					ListItem.Checkbox.SetChecked(CheckboxPresetsDefaults[Index].bChecked, false);
					`LOG(i @ "Found default entry:" @ CheckboxPresetsDefaults[Index].bChecked,, 'IRITEST');
					break;
				}
			}
		}
	}
	//SavePresetCheckboxPositions();
}

simulated private function ApplyPresetCheckboxPositions()
{
	local UIMechaListItem		ListItem;
	local int					Index;
	local bool					bFound;
	local int i;

	`LOG(GetFuncName() @ "Options in the list:" @ OptionsList.ItemCount @ "Saved options:" @ CheckboxPresets.Length,, 'IRITEST');

	if (Presets.Length > 0)
	{
		i = Presets.Length + 1;
	}
	for (i = i; i < OptionsList.ItemCount; i++) 
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none)
			continue;

		`LOG(i @ "List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ "Checked:" @ ListItem.Checkbox.bChecked,, 'IRITEST');

		bFound = false;
		for (Index = 0; Index < CheckboxPresets.Length; Index++)
		{
			if (CheckboxPresets[Index].CheckboxName == ListItem.MCName &&
				CheckboxPresets[Index].Preset == CurrentPreset)
			{
				ListItem.Checkbox.SetChecked(CheckboxPresets[Index].bChecked, false);
				bFound = true;
				`LOG(i @ "Found non-default entry:" @ CheckboxPresets[Index].bChecked,, 'IRITEST');
				break;
			}
		}

		if (!bFound)
		{
			for (Index = 0; Index < CheckboxPresetsDefaults.Length; Index++)
			{
				if (CheckboxPresetsDefaults[Index].CheckboxName == ListItem.MCName &&
					CheckboxPresetsDefaults[Index].Preset == CurrentPreset)
				{
					ListItem.Checkbox.SetChecked(CheckboxPresetsDefaults[Index].bChecked, false);
					`LOG(i @ "Found default entry:" @ CheckboxPresetsDefaults[Index].bChecked,, 'IRITEST');
					break;
				}
			}
		}
	}
	//SavePresetCheckboxPositions();
}

simulated private function ApplyChanges()
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local StateObjectReference				SquadUnitRef;
	local array<XComGameState_Unit>			UnitStates;
	local XComGameState_Unit				UnitState;
	local XComGameState						NewGameState;

	// Current Unit
	if (GetFilterListCheckboxStatus('ApplyToThisUnit'))
	{
		ApplyChangesToArmoryUnit();
	}
	if (GetFilterListCheckboxStatus('ApplyToCharPool'))
	{
		foreach PoolMgr.CharacterPool(UnitState)
		{
			ApplyChangesToUnit(UnitState);
		}
		PoolMgr.SaveCharacterPool();
	}

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ(true);
	if (XComHQ == none)
		return;

	// Squad
	if (GetFilterListCheckboxStatus('ApplyToSquad'))
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply appearance changes to squad");
		foreach XComHQ.Squad(SquadUnitRef)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(SquadUnitRef.ObjectID));
			if (UnitState == none || UnitState.IsDead() || !IsUnitSameType(UnitState))
				continue;

			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
			ApplyChangesToUnit(UnitState);
		}
		`GAMERULES.SubmitGameState(NewGameState);
	}
	// Barracks except for squad and soldiers away on Covert Action
	if (GetFilterListCheckboxStatus('ApplyToBarracks'))
	{
		UnitStates = XComHQ.GetSoldiers(true, true);

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply appearance changes to barracks");
		foreach UnitStates(UnitState)
		{
			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
			ApplyChangesToUnit(UnitState);
		}
		`GAMERULES.SubmitGameState(NewGameState);
	}
}

simulated private function ApplyChangesToUnit(XComGameState_Unit UnitState)
{
	local TAppearance CurrentAppearance;
	local string strFirstName;
	local string strNickname;
	local string strLastName;

	if (IsCheckboxChecked('FirstName'))
		strFirstName = SelectedUnit.GetFirstName();
	else
		strFirstName = UnitState.GetFirstName();

	if (IsCheckboxChecked('Nickname'))
		strNickname = SelectedUnit.GetNickName();
	else
		strNickname = UnitState.GetNickName();

	if (IsCheckboxChecked('LastName'))
		strLastName = SelectedUnit.GetLastName();
	else
		strLastName = UnitState.GetLastName();

	if (IsCheckboxChecked('nmFlag'))
		UnitState.SetCountry(ArmoryPawn.m_kAppearance.nmFlag);

	UnitState.SetCharacterName(strFirstName, strLastName, strNickname);

	if (IsCheckboxChecked('Biography'))
		UnitState.SetBackground(SelectedUnit.GetBackground());

	CurrentAppearance = UnitState.kAppearance;
	CopyAppearance(CurrentAppearance, SelectedAppearance);

	UnitState.SetTAppearance(CurrentAppearance);
	UnitState.UpdatePersonalityTemplate();
	UnitState.StoreAppearance();
}

simulated private function ApplyChangesToArmoryUnit()
{
	local XComGameState NewGameState;
	local string strFirstName;
	local string strNickname;
	local string strLastName;

	//NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply appearance changes");
	//ArmoryUnit = XComGameState_Unit(NewGameState.ModifyStateObject(ArmoryUnit.Class, ArmoryUnit.ObjectID));

	ArmoryUnit.SetTAppearance(ArmoryPawn.m_kAppearance);
	//ArmoryUnit.StoreAppearance();

	if (IsCheckboxChecked('FirstName'))
		strFirstName = SelectedUnit.GetFirstName();
	else
		strFirstName = ArmoryUnit.GetFirstName();

	if (IsCheckboxChecked('Nickname'))
		strNickname = SelectedUnit.GetNickName();
	else
		strNickname = ArmoryUnit.GetNickName();

	if (IsCheckboxChecked('LastName'))
		strLastName = SelectedUnit.GetLastName();
	else
		strLastName = ArmoryUnit.GetLastName();

	if (IsCheckboxChecked('nmFlag'))
		ArmoryUnit.SetCountry(ArmoryPawn.m_kAppearance.nmFlag);

	ArmoryUnit.SetCharacterName(strFirstName, strLastName, strNickname);

	if (IsCheckboxChecked('Biography'))
		ArmoryUnit.SetBackground(SelectedUnit.GetBackground());

	CustomizeManager.SubmitUnitCustomizationChanges();

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply appearance changes");
	ArmoryUnit = XComGameState_Unit(NewGameState.ModifyStateObject(ArmoryUnit.Class, ArmoryUnit.ObjectID));
	ArmoryUnit.UpdatePersonalityTemplate();
	
	//if (IsCheckboxChecked('AppearanceStore'))
	//{
		// TODO: Replace this with a proper function that would append/replace appearance store
	//	ArmoryUnit.AppearanceStore = SelectedUnit.AppearanceStore;
	//}

	ArmoryUnit.StoreAppearance();
	`GAMERULES.SubmitGameState(NewGameState);

	ArmoryPawn.CustomizationIdleAnim = ArmoryUnit.GetPersonalityTemplate().IdleAnimName;

	//CustomizeManager.UpdatedUnitState = ArmoryUnit;

	//CustomizeManager.OnCategoryValueChange(eUICustomizeCat_WeaponColor, 0, ArmoryPawn.m_kAppearance.iWeaponTint);
	//CustomizeManager.OnCategoryValueChange(eUICustomizeCat_Personality, 0, ArmoryPawn.m_kAppearance.iAttitude);
}

simulated function CancelChanges()
{
	if (ArmoryPawn.m_kAppearance.iGender != OriginalAppearance.iGender)
	{
		bRefreshPawn = true;
	}

	ArmoryUnit.SetTAppearance(OriginalAppearance);
	ArmoryPawn.SetAppearance(OriginalAppearance);

	if (bRefreshPawn)
	{
		CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);
		bRefreshPawn = false;
	}	
	else
	{
		UpdatePawnAttitudeAnimation();
	}
}

// ================================================================================================================================================
// OPTIONS LIST - List of checkboxes on the left that determines which parts of the appearance should be copied from CP unit to Armory unit.

simulated private function CopyAppearance(out TAppearance NewAppearance, const out TAppearance UniformAppearance)
{
	//NewAppearance = UniformAppearance;

	if (IsCheckboxChecked('nmHead'))				NewAppearance.nmHead = UniformAppearance.nmHead;
	if (IsCheckboxChecked('iGender'))				NewAppearance.iGender = UniformAppearance.iGender;
	if (IsCheckboxChecked('iRace'))					NewAppearance.iRace = UniformAppearance.iRace;
	if (IsCheckboxChecked('nmHaircut'))				NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
	if (IsCheckboxChecked('iHairColor'))			NewAppearance.iHairColor = UniformAppearance.iHairColor;
	if (IsCheckboxChecked('iFacialHair'))			NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
	if (IsCheckboxChecked('nmBeard'))				NewAppearance.nmBeard = UniformAppearance.nmBeard;
	if (IsCheckboxChecked('iSkinColor'))			NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
	if (IsCheckboxChecked('iEyeColor'))				NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
	if (IsCheckboxChecked('nmFlag'))				NewAppearance.nmFlag = UniformAppearance.nmFlag;
	if (IsCheckboxChecked('iVoice'))				NewAppearance.iVoice = UniformAppearance.iVoice;
	if (IsCheckboxChecked('iAttitude'))				NewAppearance.iAttitude = UniformAppearance.iAttitude;
	if (IsCheckboxChecked('iArmorDeco'))			NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
	if (IsCheckboxChecked('iArmorTint'))			NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
	if (IsCheckboxChecked('iArmorTintSecondary'))	NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
	if (IsCheckboxChecked('iWeaponTint'))			NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
	if (IsCheckboxChecked('iTattooTint'))			NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
	if (IsCheckboxChecked('nmWeaponPattern'))		NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
	if (IsCheckboxChecked('nmTorso'))				NewAppearance.nmTorso = UniformAppearance.nmTorso;
	if (IsCheckboxChecked('nmArms'))				NewAppearance.nmArms = UniformAppearance.nmArms;
	if (IsCheckboxChecked('nmLegs'))				NewAppearance.nmLegs = UniformAppearance.nmLegs;
	if (IsCheckboxChecked('nmHelmet'))				NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
	if (IsCheckboxChecked('nmEye'))					NewAppearance.nmEye = UniformAppearance.nmEye;
	if (IsCheckboxChecked('nmTeeth'))				NewAppearance.nmTeeth = UniformAppearance.nmTeeth;
	if (IsCheckboxChecked('nmFacePropLower'))		NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
	if (IsCheckboxChecked('nmFacePropUpper'))		NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
	if (IsCheckboxChecked('nmPatterns'))			NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
	if (IsCheckboxChecked('nmVoice'))				NewAppearance.nmVoice = UniformAppearance.nmVoice;
	if (IsCheckboxChecked('nmLanguage'))			NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
	if (IsCheckboxChecked('nmTattoo_LeftArm'))		NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
	if (IsCheckboxChecked('nmTattoo_RightArm'))		NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;
	if (IsCheckboxChecked('nmScars'))				NewAppearance.nmScars = UniformAppearance.nmScars;
	if (IsCheckboxChecked('nmTorso_Underlay'))		NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
	if (IsCheckboxChecked('nmArms_Underlay'))		NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
	if (IsCheckboxChecked('nmLegs_Underlay'))		NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
	if (IsCheckboxChecked('nmFacePaint'))			NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;
	if (IsCheckboxChecked('nmLeftArm'))				NewAppearance.nmLeftArm = UniformAppearance.nmLeftArm;
	if (IsCheckboxChecked('nmRightArm'))			NewAppearance.nmRightArm = UniformAppearance.nmRightArm;
	if (IsCheckboxChecked('nmLeftArmDeco'))			NewAppearance.nmLeftArmDeco = UniformAppearance.nmLeftArmDeco;
	if (IsCheckboxChecked('nmRightArmDeco'))		NewAppearance.nmRightArmDeco = UniformAppearance.nmRightArmDeco;
	if (IsCheckboxChecked('nmLeftForearm'))			NewAppearance.nmLeftForearm = UniformAppearance.nmLeftForearm;
	if (IsCheckboxChecked('nmRightForearm'))		NewAppearance.nmRightForearm = UniformAppearance.nmRightForearm;
	if (IsCheckboxChecked('nmThighs'))				NewAppearance.nmThighs = UniformAppearance.nmThighs;
	if (IsCheckboxChecked('nmShins'))				NewAppearance.nmShins = UniformAppearance.nmShins;
	if (IsCheckboxChecked('nmTorsoDeco'))			NewAppearance.nmTorsoDeco = UniformAppearance.nmTorsoDeco;
	if (IsCheckboxChecked('bGhostPawn'))			NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;
}

simulated private function bool IsCheckboxChecked(name OptionName)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(OptionsList.GetChildByName(OptionName, false));

	return ListItem != none && ListItem.Checkbox.bChecked;
}

simulated private function SetCheckbox(name OptionName, bool bChecked)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(OptionsList.GetChildByName(OptionName, false));

	if (ListItem != none)
	{
		ListItem.Checkbox.SetChecked(bChecked, false);
	}
}

simulated function UpdateOptionsList()
{
	SavePresetCheckboxPositions();
	OptionsList.ClearItems();

	// PRESETS
	CreateOptionPresets();
	
	if (SelectedAppearance == OriginalAppearance)
		return;

	// HEAD
	if (ShouldShowHeadCategory()) CreateOptionCategory(class'UICustomize_Menu'.default.m_strEditHead); 

	if (OriginalAppearance.iGender != SelectedAppearance.iGender)							CreateOptionGender('iGender', OriginalAppearance.iGender, SelectedAppearance.iGender);
	if (OriginalAppearance.iRace != SelectedAppearance.iRace)								CreateOptionInt('iRace', OriginalAppearance.iRace, SelectedAppearance.iRace);
	if (OriginalAppearance.iSkinColor != SelectedAppearance.iSkinColor)						CreateOptionInt('iSkinColor', OriginalAppearance.iSkinColor, SelectedAppearance.iSkinColor);
	if (OriginalAppearance.nmHead != SelectedAppearance.nmHead)								CreateOptionName('nmHead', OriginalAppearance.nmHead , SelectedAppearance.nmHead);
	if (OriginalAppearance.nmHelmet != SelectedAppearance.nmHelmet)							CreateOptionName('nmHelmet', OriginalAppearance.nmHelmet, SelectedAppearance.nmHelmet);
	if (OriginalAppearance.nmFacePropLower != SelectedAppearance.nmFacePropLower)			CreateOptionName('nmFacePropLower', OriginalAppearance.nmHelmet, SelectedAppearance.nmFacePropLower);
	if (OriginalAppearance.nmFacePropUpper != SelectedAppearance.nmFacePropUpper)			CreateOptionName('nmFacePropUpper', OriginalAppearance.nmFacePropUpper, SelectedAppearance.nmFacePropUpper);
	if (OriginalAppearance.nmHaircut != SelectedAppearance.nmHaircut)						CreateOptionName('nmHaircut', OriginalAppearance.nmHaircut, SelectedAppearance.nmHaircut);
	if (OriginalAppearance.nmBeard != SelectedAppearance.nmBeard)							CreateOptionName('nmBeard', OriginalAppearance.nmBeard, SelectedAppearance.nmBeard);
	if (OriginalAppearance.iHairColor != SelectedAppearance.iHairColor)						CreateOptionColorInt('iHairColor', OriginalAppearance.iHairColor, SelectedAppearance.iHairColor, ePalette_HairColor);
	if (OriginalAppearance.iFacialHair != SelectedAppearance.iFacialHair)					CreateOptionInt('iFacialHair', OriginalAppearance.iFacialHair, SelectedAppearance.iFacialHair);
	if (OriginalAppearance.iEyeColor != SelectedAppearance.iEyeColor)						CreateOptionColorInt('iEyeColor', OriginalAppearance.iEyeColor, SelectedAppearance.iEyeColor, ePalette_EyeColor);
	if (OriginalAppearance.nmScars != SelectedAppearance.nmScars)							CreateOptionName('nmScars', OriginalAppearance.nmScars, SelectedAppearance.nmScars);
	if (OriginalAppearance.nmFacePaint != SelectedAppearance.nmFacePaint)					CreateOptionName('nmFacePaint', OriginalAppearance.nmFacePaint, SelectedAppearance.nmFacePaint);
	if (OriginalAppearance.nmEye != SelectedAppearance.nmEye)								CreateOptionName('nmEye', OriginalAppearance.nmEye ,SelectedAppearance.nmEye);
	if (OriginalAppearance.nmTeeth != SelectedAppearance.nmTeeth)							CreateOptionName('nmTeeth', OriginalAppearance.nmTeeth, SelectedAppearance.nmTeeth);

	// BODY
	if (ShouldShowBodyCategory()) CreateOptionCategory(class'UICustomize_Menu'.default.m_strEditBody); 

	if (OriginalAppearance.nmTorso != SelectedAppearance.nmTorso)							CreateOptionName('nmTorso', OriginalAppearance.nmTorso, SelectedAppearance.nmTorso);
	if (OriginalAppearance.nmArms != SelectedAppearance.nmArms)								CreateOptionName('nmArms', OriginalAppearance.nmArms, SelectedAppearance.nmArms);
	if (OriginalAppearance.nmLegs != SelectedAppearance.nmLegs)								CreateOptionName('nmLegs', OriginalAppearance.nmLegs, SelectedAppearance.nmLegs);
	if (OriginalAppearance.nmTorso_Underlay != SelectedAppearance.nmTorso_Underlay)			CreateOptionName('nmTorso_Underlay', OriginalAppearance.nmTorso_Underlay, SelectedAppearance.nmTorso_Underlay);
	if (OriginalAppearance.nmArms_Underlay != SelectedAppearance.nmArms_Underlay)			CreateOptionName('nmArms_Underlay', OriginalAppearance.nmArms_Underlay, SelectedAppearance.nmArms_Underlay);
	if (OriginalAppearance.nmLeftArm != SelectedAppearance.nmLeftArm)						CreateOptionName('nmLeftArm', OriginalAppearance.nmLeftArm, SelectedAppearance.nmLeftArm);
	if (OriginalAppearance.nmRightArm != SelectedAppearance.nmRightArm)						CreateOptionName('nmRightArm', OriginalAppearance.nmRightArm, SelectedAppearance.nmRightArm);
	if (OriginalAppearance.nmLeftArmDeco != SelectedAppearance.nmLeftArmDeco)				CreateOptionName('nmLeftArmDeco', OriginalAppearance.nmLeftArmDeco, SelectedAppearance.nmLeftArmDeco);
	if (OriginalAppearance.nmRightArmDeco != SelectedAppearance.nmRightArmDeco)				CreateOptionName('nmRightArmDeco', OriginalAppearance.nmRightArmDeco, SelectedAppearance.nmRightArmDeco);
	if (OriginalAppearance.nmLeftForearm != SelectedAppearance.nmLeftForearm)				CreateOptionName('nmLeftForearm', OriginalAppearance.nmLeftForearm, SelectedAppearance.nmLeftForearm);
	if (OriginalAppearance.nmRightForearm != SelectedAppearance.nmRightForearm)				CreateOptionName('nmRightForearm', OriginalAppearance.nmRightForearm, SelectedAppearance.nmRightForearm);
	if (OriginalAppearance.nmLegs_Underlay != SelectedAppearance.nmLegs_Underlay)			CreateOptionName('nmLegs_Underlay', OriginalAppearance.nmLegs_Underlay, SelectedAppearance.nmLegs_Underlay);
	if (OriginalAppearance.nmThighs != SelectedAppearance.nmThighs)							CreateOptionName('nmThighs', OriginalAppearance.nmThighs, SelectedAppearance.nmThighs);
	if (OriginalAppearance.nmShins != SelectedAppearance.nmShins)							CreateOptionName('nmShins', OriginalAppearance.nmShins, SelectedAppearance.nmShins);
	if (OriginalAppearance.nmTorsoDeco != SelectedAppearance.nmTorsoDeco)					CreateOptionName('nmTorsoDeco', OriginalAppearance.nmTorsoDeco, SelectedAppearance.nmTorsoDeco);

	// TATTOOS - thanks to Xym for Localize()
	if (ShouldShowTattooCategory()) CreateOptionCategory(Localize("UIArmory_Customize", "m_strBaseLabels[eUICustomizeBase_Tattoos]", "XComGame"));

	if (OriginalAppearance.nmTattoo_LeftArm != SelectedAppearance.nmTattoo_LeftArm)			CreateOptionName('nmTattoo_LeftArm', OriginalAppearance.nmTattoo_LeftArm, SelectedAppearance.nmTattoo_LeftArm);
	if (OriginalAppearance.nmTattoo_RightArm != SelectedAppearance.nmTattoo_RightArm)		CreateOptionName('nmTattoo_RightArm', OriginalAppearance.nmTattoo_RightArm, SelectedAppearance.nmTattoo_RightArm);
	if (ShouldShowTatooColorOption())														CreateOptionColorInt('iTattooTint', OriginalAppearance.iTattooTint, SelectedAppearance.iTattooTint, ePalette_ArmorTint);
	
	// ARMOR PATTERN
	if (ShouldShowArmorPatternCategory()) CreateOptionCategory(class'UICustomize_Body'.default.m_strArmorPattern);

	if (OriginalAppearance.nmPatterns != SelectedAppearance.nmPatterns)						CreateOptionName('nmPatterns', OriginalAppearance.nmPatterns, SelectedAppearance.nmPatterns);
	if (OriginalAppearance.iArmorDeco != SelectedAppearance.iArmorDeco)						CreateOptionInt('iArmorDeco', OriginalAppearance.iArmorDeco, SelectedAppearance.iArmorDeco);
	if (OriginalAppearance.iArmorTint != SelectedAppearance.iArmorTint)						CreateOptionColorInt('iArmorTint', OriginalAppearance.iArmorTint, SelectedAppearance.iArmorTint, ePalette_ArmorTint);
	if (OriginalAppearance.iArmorTintSecondary != SelectedAppearance.iArmorTintSecondary)	CreateOptionColorInt('iArmorTintSecondary', OriginalAppearance.iArmorTintSecondary, SelectedAppearance.iArmorTintSecondary, ePalette_ArmorTint, false);

	// WEAPON PATTERN
	if (ShouldShowWeaponPatternCategory())  CreateOptionCategory(class'UICustomize_Weapon'.default.m_strWeaponPattern); // WEAPON PATTERN

	if (OriginalAppearance.nmWeaponPattern != SelectedAppearance.nmWeaponPattern)			CreateOptionName('nmWeaponPattern', OriginalAppearance.nmWeaponPattern, SelectedAppearance.nmWeaponPattern);
	if (OriginalAppearance.iWeaponTint != SelectedAppearance.iWeaponTint)					CreateOptionColorInt('iWeaponTint', OriginalAppearance.iWeaponTint, SelectedAppearance.iWeaponTint, ePalette_ArmorTint);	

	if (ShouldShowPersonalityCategory()) CreateOptionCategory(Localize("UIArmory_Customize", "m_strBaseLabels[eUICustomizeBase_Personality]", "XComGame")); // PERSONALITY

	if (OriginalAppearance.iAttitude != SelectedAppearance.iAttitude)						CreateOptionAttitude();
	if (OriginalAppearance.nmVoice != SelectedAppearance.nmVoice)							CreateOptionName('nmVoice', OriginalAppearance.nmVoice, SelectedAppearance.nmVoice);
	if (OriginalAppearance.nmFlag != SelectedAppearance.nmFlag)								CreateOptionCountryName(OriginalAppearance.nmFlag, SelectedAppearance.nmFlag);
	if (OriginalAppearance.nmLanguage != SelectedAppearance.nmLanguage)						CreateOptionName('nmLanguage', OriginalAppearance.nmLanguage, SelectedAppearance.nmLanguage);

	MaybeCreateOptionFirstName();
	MaybeCreateOptionNickName();
	MaybeCreateOptionLastName();
	MaybeCreateOptionBiography();
	//MaybeCreateOptionAppearanceStore();

	//LogAllOptions();

	ActivatePreset();
}

simulated private function LogAllOptions()
{
	local UIMechaListItem		ListItem;
	local int i;

	`LOG(GetFuncName() @  OptionsList.ItemCount,, 'IRITEST');
	`LOG("----------------------------------------------------------",, 'IRITEST');

	for (i = 0; i < OptionsList.ItemCount; i++)
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none)
			continue;
			
		`LOG("List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ ListItem.Checkbox != none,, 'IRITEST');
	}
	`LOG("----------------------------------------------------------",, 'IRITEST');
}

simulated private function CreateOptionPresets()
{
	local string strFriendlyPresetName;
	local int i;

	if (Presets.Length == 0)
		return;

	CreateOptionCategory(class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset); 
	`LOG(GetFuncName() @ `showvar(CurrentPreset),, 'IRITEST');

	for (i = 0; i < Presets.Length; i++)
	{
		strFriendlyPresetName = Localize("UICustomize_CPExtended", string(Presets[i]), "WOTCCharacterPoolExtended");
		if (strFriendlyPresetName == "")
			strFriendlyPresetName = string(Presets[i]);

		CreateOptionPreset(Presets[i], strFriendlyPresetName, "", CurrentPreset == Presets[i]);
	}
}

simulated private function bool ShouldShowHeadCategory()
{	
	return  OriginalAppearance.iRace != SelectedAppearance.iRace ||
			OriginalAppearance.iSkinColor != SelectedAppearance.iSkinColor ||
			OriginalAppearance.nmHead != SelectedAppearance.nmHead ||
			OriginalAppearance.nmHelmet != SelectedAppearance.nmHelmet ||
			OriginalAppearance.nmFacePropLower != SelectedAppearance.nmFacePropLower ||
			OriginalAppearance.nmFacePropUpper != SelectedAppearance.nmFacePropUpper ||
			OriginalAppearance.nmHaircut != SelectedAppearance.nmHaircut ||
			OriginalAppearance.nmBeard != SelectedAppearance.nmBeard ||
			OriginalAppearance.iHairColor != SelectedAppearance.iHairColor ||
			OriginalAppearance.iFacialHair != SelectedAppearance.iFacialHair ||
			OriginalAppearance.iEyeColor != SelectedAppearance.iEyeColor||
			OriginalAppearance.nmScars != SelectedAppearance.nmScars ||
			OriginalAppearance.nmFacePaint != SelectedAppearance.nmFacePaint ||
			OriginalAppearance.nmEye != SelectedAppearance.nmEye ||
			OriginalAppearance.nmTeeth != SelectedAppearance.nmTeeth;
}

simulated private function bool ShouldShowBodyCategory()
{	
	return  OriginalAppearance.nmTorso != SelectedAppearance.nmTorso ||
			OriginalAppearance.nmArms != SelectedAppearance.nmArms ||				
			OriginalAppearance.nmLegs != SelectedAppearance.nmLegs ||					
			OriginalAppearance.nmTorso_Underlay != SelectedAppearance.nmTorso_Underlay ||
			OriginalAppearance.nmArms_Underlay != SelectedAppearance.nmArms_Underlay ||
			OriginalAppearance.nmLeftArm != SelectedAppearance.nmLeftArm ||
			OriginalAppearance.nmRightArm != SelectedAppearance.nmRightArm ||
			OriginalAppearance.nmLeftArmDeco != SelectedAppearance.nmLeftArmDeco ||
			OriginalAppearance.nmRightArmDeco != SelectedAppearance.nmRightArmDeco ||		
			OriginalAppearance.nmLeftForearm != SelectedAppearance.nmLeftForearm ||	
			OriginalAppearance.nmRightForearm != SelectedAppearance.nmRightForearm ||		
			OriginalAppearance.nmLegs_Underlay != SelectedAppearance.nmLegs_Underlay ||	
			OriginalAppearance.nmThighs != SelectedAppearance.nmThighs ||
			OriginalAppearance.nmShins != SelectedAppearance.nmShins ||				
			OriginalAppearance.nmTorsoDeco != SelectedAppearance.nmTorsoDeco;
}

simulated private function bool ShouldShowTattooCategory()
{	
	return   OriginalAppearance.nmTattoo_LeftArm != SelectedAppearance.nmTattoo_LeftArm ||
			 OriginalAppearance.nmTattoo_RightArm != SelectedAppearance.nmTattoo_RightArm ||
			 ShouldShowTatooColorOption();
}

simulated private function bool ShouldShowTatooColorOption()
{
	// Show tattoo color only if we're changing it *and* at least one of the tattoos for the new appearance isn't empty
	return	OriginalAppearance.iTattooTint != SelectedAppearance.iTattooTint && 
			(SelectedAppearance.nmTattoo_LeftArm != 'Tattoo_Arms_BLANK' || 
			SelectedAppearance.nmTattoo_RightArm != 'Tattoo_Arms_BLANK');
}

simulated private function bool ShouldShowArmorPatternCategory()
{	
	return OriginalAppearance.nmPatterns != SelectedAppearance.nmPatterns ||		
		   OriginalAppearance.iArmorDeco != SelectedAppearance.iArmorDeco ||				
		   OriginalAppearance.iArmorTint != SelectedAppearance.iArmorTint ||				
		   OriginalAppearance.iArmorTintSecondary != SelectedAppearance.iArmorTintSecondary;
}

simulated private function bool ShouldShowWeaponPatternCategory()
{	
	return	OriginalAppearance.nmWeaponPattern != SelectedAppearance.nmWeaponPattern ||
			OriginalAppearance.iWeaponTint != SelectedAppearance.iWeaponTint;
}

simulated private function bool ShouldShowPersonalityCategory()
{	
	return	OriginalAppearance.iAttitude != SelectedAppearance.iAttitude ||
			OriginalAppearance.nmVoice != SelectedAppearance.nmVoice ||		
			OriginalAppearance.nmFlag != SelectedAppearance.nmFlag ||
			OriginalAppearance.nmLanguage != SelectedAppearance.nmLanguage ||
			ArmoryUnit.GetFirstName() == SelectedUnit.GetFirstName() ||
			ArmoryUnit.GetLastName() == SelectedUnit.GetLastName() ||
			ArmoryUnit.GetNickName() == SelectedUnit.GetNickName() ||
			ArmoryUnit.GetBackground() == SelectedUnit.GetBackground();				
}
simulated private function CreateOptionName(name OptionName, name CosmeticTemplateName, name NewCosmeticTemplateName)
{
	local UIMechaListItem SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName) $ ":" @ GetBodyPartFriendlyName(OptionName, CosmeticTemplateName) @ "->" @ GetBodyPartFriendlyName(OptionName, NewCosmeticTemplateName), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated private function CreateOptionCountryName(name CountryTemplateName, name NewCountryTemplateName)
{
	local UIMechaListItem SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('nmFlag');

	SpawnedItem.UpdateDataCheckbox(class'UICustomize_Info'.default.m_strNationality $ ":" @ GetFriendlyCountryName(CountryTemplateName) @ "->" @ GetFriendlyCountryName(NewCountryTemplateName), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated private function MaybeCreateOptionFirstName()
{
	local UIMechaListItem SpawnedItem;

	if (ArmoryUnit.GetFirstName() == SelectedUnit.GetFirstName())
		return;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('FirstName');

	SpawnedItem.UpdateDataCheckbox(class'UICustomize_Info'.default.m_strFirstNameLabel $ ":" @ ArmoryUnit.GetFirstName() @ "->" @ SelectedUnit.GetFirstName(), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated private function MaybeCreateOptionLastName()
{
	local UIMechaListItem SpawnedItem;

	if (ArmoryUnit.GetLastName() == SelectedUnit.GetLastName())
		return;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('LastName');

	SpawnedItem.UpdateDataCheckbox(class'UICustomize_Info'.default.m_strLastNameLabel $ ":" @ ArmoryUnit.GetLastName() @ "->" @ SelectedUnit.GetLastName(), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated private function MaybeCreateOptionNickname()
{
	local UIMechaListItem SpawnedItem;

	if (ArmoryUnit.GetNickName() == SelectedUnit.GetNickName())
		return;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('Nickname');

	SpawnedItem.UpdateDataCheckbox(class'UICustomize_Info'.default.m_strNicknameLabel $ ":" @ ArmoryUnit.GetNickName() @ "->" @ SelectedUnit.GetNickName(), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated private function MaybeCreateOptionBiography()
{
	local UIMechaListItem SpawnedItem;

	if (ArmoryUnit.GetBackground() == SelectedUnit.GetBackground())
		return;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('Biography');

	SpawnedItem.UpdateDataCheckbox(class'UICustomize_Info'.default.m_strEditBiography, 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated private function UpdateHeader()
{
	local string strFirstName;
	local string strNickname;
	local string strLastName;
	local string StatusTimeValue;
	local string StatusTimeLabel;
	local string StatusDesc;
	local string strDisplayName;
	local string flagIcon;
	local X2CountryTemplate	CountryTemplate;

	if (IsCheckboxChecked('FirstName'))
		strFirstName = SelectedUnit.GetFirstName();
	else
		strFirstName = ArmoryUnit.GetFirstName();

	if (IsCheckboxChecked('Nickname'))
		strNickname = SelectedUnit.GetNickName();
	else
		strNickname = ArmoryUnit.GetNickName();

	if (IsCheckboxChecked('LastName'))
		strLastName = SelectedUnit.GetLastName();
	else
		strLastName = ArmoryUnit.GetLastName();

	if (IsCheckboxChecked('nmFlag'))
		CountryTemplate = X2CountryTemplate(StratMgr.FindStrategyElementTemplate(SelectedAppearance.nmFlag));
	else
		CountryTemplate = X2CountryTemplate(StratMgr.FindStrategyElementTemplate(OriginalAppearance.nmFlag));
	
	if (CountryTemplate!= none)
	{
		flagIcon = CountryTemplate.FlagImage;
	}

	class'UIUtilities_Strategy'.static.GetPersonnelStatusSeparate(ArmoryUnit, StatusDesc, StatusTimeLabel, StatusTimeValue, , true); 
	
	if (strNickname == "")
		strDisplayName = strFirstName @ strLastName;
	else
		strDisplayName = strFirstName @ "'" $ strNickname $ "'" @ strLastName;

	Header.SetSoldierInfo( Caps(strDisplayName),
						Header.m_strStatusLabel, StatusDesc,
						Header.m_strMissionsLabel, string(Unit.GetNumMissions()),
						Header.m_strKillsLabel, string(Unit.GetNumKills()),
						Unit.GetSoldierClassIcon(), Caps(ArmoryUnit.GetSoldierClassDisplayName()),
						Unit.GetSoldierRankIcon(), Caps(ArmoryUnit.GetSoldierRankName()),
						flagIcon, ArmoryUnit.ShowPromoteIcon(), StatusTimeValue @ StatusTimeLabel);
}

simulated private function CreateOptionInt(name OptionName, int iValue, int iNewValue)
{
	local UIMechaListItem SpawnedItem;
	
	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);
									 
	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName) $ ":" @ string(iValue) @ "->" @ string(iNewValue), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated private function CreateOptionGender(name OptionName, int iValue, int iNewValue)
{
	local UIMechaListItem SpawnedItem;
	
	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);
									 
	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName) $ ":" @ GetFriendlyGender(EGender(iValue)) @ "->" @ GetFriendlyGender(EGender(iNewValue)), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated private function CreateOptionColorInt(name OptionName, int iValue, int iNewValue, EColorPalette PaletteType, optional bool bPrimary = true)
{
	local UIMechaListItem_Color			SpawnedItem;
	local XComLinearColorPalette	Palette;
	local LinearColor				ParamColor;
	local LinearColor				NewParamColor;

	SpawnedItem = Spawn(class'UIMechaListItem_Color', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);

	Palette = `CONTENT.GetColorPalette(PaletteType);
	if (bPrimary)
	{
		ParamColor = Palette.Entries[iValue].Primary;
		NewParamColor = Palette.Entries[iNewValue].Primary;
	}
	else
	{
		ParamColor = Palette.Entries[iValue].Secondary;
		NewParamColor = Palette.Entries[iNewValue].Secondary;
	}
	SpawnedItem.HTMLColorChip2 = GetHTMLColor(NewParamColor);
	SpawnedItem.strColorText_1 = string(iValue);
	SpawnedItem.strColorText_2 = string(iNewValue);
	SpawnedItem.UpdateDataColorChip(GetOptionFriendlyName(OptionName), GetHTMLColor(ParamColor));	
}

simulated private function CreateOptionAttitude()
{
	local UIMechaListItem SpawnedItem;
	
	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('iAttitude');
									 
	SpawnedItem.UpdateDataCheckbox(class'UICustomize_Info'.default.m_strAttitude $ ":" @ OriginalAttitude.FriendlyName @ "->" @ SelectedAttitude.FriendlyName, 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated private function MaybeCreateOptionAppearanceStore()
{
	local UIMechaListItem SpawnedItem;

	// TODO: Replace this check with a check that would compare armory unit appearance store with selected unit one
	if (SelectedUnit.AppearanceStore.Length == 0)
		return;
	
	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('AppearanceStore');
									 
	SpawnedItem.UpdateDataCheckbox("Appearance Store" $ ":" @ ArmoryUnit.AppearanceStore.Length @ "->" @ SelectedUnit.AppearanceStore.Length, // TODO: Localize this
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated private function OptionCheckboxChanged(UICheckbox CheckBox)
{
	UpdateUnitAppearance();
}

simulated private function CreateOptionCategory(string strText)
{
	local UIMechaListItem SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.SetDisabled(true);
	SpawnedItem.UpdateDataDescription(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(strText));
}

simulated private function string GetHTMLColor(LinearColor ParamColor)
{
	local string ColorString;

	ColorString = Right(ToHex(int(ParamColor.R * 255.0f)), 2) $ Right(ToHex(int(ParamColor.G * 255.0f)), 2)  $ Right(ToHex(int(ParamColor.B * 255.0f)), 2);
	
	return ColorString;
}


simulated private function CreateOptionPreset(name OptionName, string strText, string strTooltip, optional bool bChecked)
{
	local UIMechaListItem SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	SpawnedItem.UpdateDataCheckbox(strText, strTooltip, bChecked, OptionPresetCheckboxChanged, none);
}

simulated private function OptionPresetCheckboxChanged(UICheckbox CheckBox)
{
	CurrentPreset = UIMechaListItem(CheckBox.GetParent(class'UIMechaListItem')).MCName;
	UpdateOptionsList(); // This will call ActivatePreset()
	UpdateUnitAppearance();
}

simulated private function ActivatePreset()
{
	local name Preset;

	`LOG(GetFuncName() @ `showvar(CurrentPreset),, 'IRITEST');
	
	foreach Presets(Preset)
	{
		SetCheckbox(Preset, Preset == CurrentPreset);
	}
	ApplyPresetCheckboxPositions();
}

simulated function OptionsListItemClicked(UIList ContainerList, int ItemIndex)
{
	local UIMechaListItem ListItem;

	if (ItemIndex > Presets.Length)
		return;
	
	ListItem = UIMechaListItem(OptionsList.GetItem(ItemIndex));
	if (ListItem != none)
	{
		OptionPresetCheckboxChanged(ListItem.Checkbox);
	}
}

// ================================================================================================================================================
// LOCALIZATION HELPERS

simulated private function string GetBodyPartFriendlyName(name OptionName, name CosmeticTemplateName)
{
	local X2BodyPartTemplate	BodyPartTemplate;
	local string				PartType;

	if (CosmeticTemplateName == '')
		return class'UIPhotoboothBase'.default.m_strEmptyOption; // "none"

	PartType = GetPartType(OptionName);
	if (PartType != "")
	{
		BodyPartTemplate = BodyPartMgr.FindUberTemplate(PartType, CosmeticTemplateName);
	}

	//if (BodyPartTemplate != none && BodyPartTemplate.DisplayName == "")
	//	`LOG("No localized name for template:" @ BodyPartTemplate.DataName @ PartType @ OptionName,, 'IRITEST');

	if (BodyPartTemplate != none && BodyPartTemplate.DisplayName != "")
		return BodyPartTemplate.DisplayName;

	return string(CosmeticTemplateName);
}

simulated private function string GetPartType(name OptionName)
{
	switch (OptionName)
	{
	case'nmHead': return "Head";
	case'nmHaircut': return "Hair";
	case'nmBeard': return "Beards";
	case'nmVoice': return "Voice";
	case'nmFlag': return "";
	case'nmPatterns': return "Patterns";
	case'nmWeaponPattern': return "Patterns";
	case'nmTorso': return "Torso";
	case'nmArms': return "Arms";
	case'nmLegs': return "Legs";
	case'nmHelmet': return "Helmets";
	case'nmEye': return "Eyes";
	case'nmTeeth': return "Teeth";
	case'nmFacePropUpper': return "FacePropsUpper";
	case'nmFacePropLower': return "FacePropsLower";
	case'nmLanguage': return "";
	case'nmTattoo_LeftArm': return "Tattoos";
	case'nmTattoo_RightArm': return "Tattoos";
	case'nmScars': return "Scars";
	case'nmTorso_Underlay': return "";
	case'nmArms_Underlay': return "";
	case'nmLegs_Underlay': return "";
	case'nmFacePaint': return "Facepaint";
	case'nmLeftArm': return "LeftArm";
	case'nmRightArm': return "RightArm";
	case'nmLeftArmDeco': return "LeftArmDeco";
	case'nmRightArmDeco': return "RightArmDeco";
	case'nmLeftForearm': return "LeftForearm";
	case'nmRightForearm': return "RightForearm";
	case'nmThighs': return "Thighs";
	case'nmShins': return "Shins";
	case'nmTorsoDeco': return "TorsoDeco";
	default:
		return "";
	}
	
	//DecoKits
}

simulated private function string GetFriendlyCountryName(name CountryTemplateName)
{
	local X2CountryTemplate	CountryTemplate;

	CountryTemplate = X2CountryTemplate(StratMgr.FindStrategyElementTemplate(CountryTemplateName));

	return CountryTemplate != none ? CountryTemplate.DisplayName : string(CountryTemplateName);
}

simulated function string GetFriendlyGender(EGender iGender)
{
	switch (iGender)
	{
	case eGender_Male:
		return class'XComCharacterCustomization'.default.Gender_Male;
	case eGender_Female:
		return class'XComCharacterCustomization'.default.Gender_Female;
	default:
		return class'UIPhotoboothBase'.default.m_strEmptyOption;
	}
}

static simulated private function string GetOptionFriendlyName(name OptionName)
{
	switch (OptionName)
	{
	case'iRace': return class'UICustomize_Head'.default.m_strRace;
	case'iGender': return class'UICustomize_Info'.default.m_strGender;
	case'iHairColor': return class'UICustomize_Head'.default.m_strHairColor;
	case'iFacialHair': return class'UICustomize_Head'.default.m_strFacialHair;
	case'iSkinColor': return class'UICustomize_Head'.default.m_strSkinColor;
	case'iEyeColor': return class'UICustomize_Head'.default.m_strEyeColor;
	case'iAttitude': return class'UICustomize_Info'.default.m_strAttitude;
	case'iArmorDeco': return class'UICustomize_Body'.default.m_strMainColor;
	case'iArmorTint': return class'UICustomize_Body'.default.m_strMainColor;
	case'iArmorTintSecondary': return class'UICustomize_Body'.default.m_strSecondaryColor;
	case'iWeaponTint': return class'UICustomize_Weapon'.default.m_strWeaponColor;
	case'iTattooTint': return class'UICustomize_Body'.default.m_strTattooColor;
	case'nmHead': return class'UICustomize_Head'.default.m_strFace;
	case'nmHaircut': return class'UICustomize_Head'.default.m_strHair;
	case'nmBeard': return class'UICustomize_Head'.default.m_strFacialHair;
	case'nmVoice': return class'UICustomize_Info'.default.m_strVoice;
	case'nmFlag': return class'UICustomize_Info'.default.m_strNationality;
	case'nmPatterns': return class'UICustomize_Body'.default.m_strArmorPattern;
	case'nmWeaponPattern': return class'UICustomize_Weapon'.default.m_strWeaponPattern;
	case'nmTorso': return class'UICustomize_Body'.default.m_strTorso;
	case'nmArms': return class'UICustomize_Body'.default.m_strArms;
	case'nmLegs': return class'UICustomize_Body'.default.m_strLegs;
	case'nmHelmet': return class'UICustomize_Head'.default.m_strHelmet;
	case'nmEye': return "Eye type";
	case'nmTeeth': return "Teeth";
	case'nmFacePropUpper': return class'UICustomize_Head'.default.m_strUpperFaceProps;
	case'nmFacePropLower': return class'UICustomize_Head'.default.m_strLowerFaceProps;
	case'nmLanguage': return "Language";
	case'nmTattoo_LeftArm': return class'UICustomize_Body'.default.m_strTattoosLeft;
	case'nmTattoo_RightArm': return class'UICustomize_Body'.default.m_strTattoosRight;
	case'nmScars': return class'UICustomize_Head'.default.m_strScars;
	case'nmTorso_Underlay': return "Torso Underlay";
	case'nmArms_Underlay': return "Arms Underlay";
	case'nmLegs_Underlay': return "Legs Underlay";
	case'nmFacePaint': return class'UICustomize_Head'.default.m_strFacepaint;
	case'nmLeftArm': return class'UICustomize_Body'.default.m_strLeftArm;
	case'nmRightArm': return class'UICustomize_Body'.default.m_strRightArm;
	case'nmLeftArmDeco': return class'UICustomize_Body'.default.m_strLeftArmDeco;
	case'nmRightArmDeco': return class'UICustomize_Body'.default.m_strRightArmDeco;
	case'nmLeftForearm': return class'UICustomize_Body'.default.m_strLeftForearm;
	case'nmRightForearm': return class'UICustomize_Body'.default.m_strRightForearm;
	case'nmThighs': return class'UICustomize_Body'.default.m_strThighs;
	case'nmShins': return class'UICustomize_Body'.default.m_strShins;
	case'nmTorsoDeco': return class'UICustomize_Body'.default.m_strTorsoDeco;
	default:
		return "";
	}
}

simulated private function string GetColorFriendlyText(coerce string strText, LinearColor ParamColor)
{
	return "<font color='#" $ GetHTMLColor(ParamColor) $ "'>" $ strText $ "</font>";
}


static private function bool ShouldCopyUniformPiece(const name UniformPiece, const name PresetName)
{
	local CheckboxPresetStruct CheckboxPreset;

	foreach default.CheckboxPresets(CheckboxPreset)
	{
		if (CheckboxPreset.CheckboxName == UniformPiece &&
			CheckboxPreset.Preset == PresetName)
		{
			return CheckboxPreset.bChecked;
		}
	}
	foreach default.CheckboxPresetsDefaults(CheckboxPreset)
	{
		if (CheckboxPreset.CheckboxName == UniformPiece &&
			CheckboxPreset.Preset == PresetName)
		{
			return CheckboxPreset.bChecked;
		}
	}	
	return false;
}

static final function CopyAppearance_Static(out TAppearance NewAppearance, const TAppearance UniformAppearance, const name PresetName)
{
	if (ShouldCopyUniformPiece('nmHead', PresetName)) NewAppearance.nmHead = UniformAppearance.nmHead;
	if (ShouldCopyUniformPiece('iGender', PresetName)) NewAppearance.iGender = UniformAppearance.iGender;
	if (ShouldCopyUniformPiece('iRace', PresetName)) NewAppearance.iRace = UniformAppearance.iRace;
	if (ShouldCopyUniformPiece('nmHaircut', PresetName)) NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
	if (ShouldCopyUniformPiece('iHairColor', PresetName)) NewAppearance.iHairColor = UniformAppearance.iHairColor;
	if (ShouldCopyUniformPiece('iFacialHair', PresetName)) NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
	if (ShouldCopyUniformPiece('nmBeard', PresetName)) NewAppearance.nmBeard = UniformAppearance.nmBeard;
	if (ShouldCopyUniformPiece('iSkinColor', PresetName)) NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
	if (ShouldCopyUniformPiece('iEyeColor', PresetName)) NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
	if (ShouldCopyUniformPiece('nmFlag', PresetName)) NewAppearance.nmFlag = UniformAppearance.nmFlag;
	if (ShouldCopyUniformPiece('iVoice', PresetName)) NewAppearance.iVoice = UniformAppearance.iVoice;
	if (ShouldCopyUniformPiece('iAttitude', PresetName)) NewAppearance.iAttitude = UniformAppearance.iAttitude;
	if (ShouldCopyUniformPiece('iArmorDeco', PresetName)) NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
	if (ShouldCopyUniformPiece('iArmorTint', PresetName)) NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
	if (ShouldCopyUniformPiece('iArmorTintSecondary', PresetName)) NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
	if (ShouldCopyUniformPiece('iWeaponTint', PresetName)) NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
	if (ShouldCopyUniformPiece('iTattooTint', PresetName)) NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
	if (ShouldCopyUniformPiece('nmWeaponPattern', PresetName)) NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
	if (ShouldCopyUniformPiece('nmPawn', PresetName)) NewAppearance.nmPawn = UniformAppearance.nmPawn;
	if (ShouldCopyUniformPiece('nmTorso', PresetName)) NewAppearance.nmTorso = UniformAppearance.nmTorso;
	if (ShouldCopyUniformPiece('nmArms', PresetName)) NewAppearance.nmArms = UniformAppearance.nmArms;
	if (ShouldCopyUniformPiece('nmLegs', PresetName)) NewAppearance.nmLegs = UniformAppearance.nmLegs;
	if (ShouldCopyUniformPiece('nmHelmet', PresetName)) NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
	if (ShouldCopyUniformPiece('nmEye', PresetName)) NewAppearance.nmEye = UniformAppearance.nmEye;
	if (ShouldCopyUniformPiece('nmTeeth', PresetName)) NewAppearance.nmTeeth = UniformAppearance.nmTeeth;
	if (ShouldCopyUniformPiece('nmFacePropLower', PresetName)) NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
	if (ShouldCopyUniformPiece('nmFacePropUpper', PresetName)) NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
	if (ShouldCopyUniformPiece('nmPatterns', PresetName)) NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
	if (ShouldCopyUniformPiece('nmVoice', PresetName)) NewAppearance.nmVoice = UniformAppearance.nmVoice;
	if (ShouldCopyUniformPiece('nmLanguage', PresetName)) NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
	if (ShouldCopyUniformPiece('nmTattoo_LeftArm', PresetName)) NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
	if (ShouldCopyUniformPiece('nmTattoo_RightArm', PresetName)) NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;
	if (ShouldCopyUniformPiece('nmScars', PresetName)) NewAppearance.nmScars = UniformAppearance.nmScars;
	if (ShouldCopyUniformPiece('nmTorso_Underlay', PresetName)) NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
	if (ShouldCopyUniformPiece('nmArms_Underlay', PresetName)) NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
	if (ShouldCopyUniformPiece('nmLegs_Underlay', PresetName)) NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
	if (ShouldCopyUniformPiece('nmFacePaint', PresetName)) NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;
	if (ShouldCopyUniformPiece('nmLeftArm', PresetName)) NewAppearance.nmLeftArm = UniformAppearance.nmLeftArm;
	if (ShouldCopyUniformPiece('nmRightArm', PresetName)) NewAppearance.nmRightArm = UniformAppearance.nmRightArm;
	if (ShouldCopyUniformPiece('nmLeftArmDeco', PresetName)) NewAppearance.nmLeftArmDeco = UniformAppearance.nmLeftArmDeco;
	if (ShouldCopyUniformPiece('nmRightArmDeco', PresetName)) NewAppearance.nmRightArmDeco = UniformAppearance.nmRightArmDeco;
	if (ShouldCopyUniformPiece('nmLeftForearm', PresetName)) NewAppearance.nmLeftForearm = UniformAppearance.nmLeftForearm;
	if (ShouldCopyUniformPiece('nmRightForearm', PresetName)) NewAppearance.nmRightForearm = UniformAppearance.nmRightForearm;
	if (ShouldCopyUniformPiece('nmThighs', PresetName)) NewAppearance.nmThighs = UniformAppearance.nmThighs;
	if (ShouldCopyUniformPiece('nmShins', PresetName)) NewAppearance.nmShins = UniformAppearance.nmShins;
	if (ShouldCopyUniformPiece('nmTorsoDeco', PresetName)) NewAppearance.nmTorsoDeco = UniformAppearance.nmTorsoDeco;
	if (ShouldCopyUniformPiece('bGhostPawn', PresetName)) NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;
}


/*class'UICustomize_Info'.default.m_strFirstNameLabel=First Name
class'UICustomize_Info'.default.m_strLastNameLabel=Last Name
class'UICustomize_Info'.default.m_strNicknameLabel=Nickname
class'UICustomize_Info'.default.m_strEditBiography=Biography
*/


/*
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_FirstName]=FIRST NAME
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_LastName]=LAST NAME
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_NickName]=NICK NAME
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_DEV_Torso]=Torso (DEV)
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_DEV_Arms]=Arms (DEV)
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_DEV_Legs]=Legs (DEV)
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Skin]=SKIN

class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Face]=FACE

class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_EyeColor]=EYE COLOR
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_EyeType]=EYE TYPE
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_TeethType]=TEETH TYPE
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Hairstyle]=HAIR STYLE
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_HairColor]=HAIR COLOR
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_FaceDecorationUpper]=FACE DECORATION UPPER
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_FaceDecorationLower]=FACE DECORATION LOWER
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_FacialHair]=FACIAL HAIR
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Scars]=SCARS
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Tattoos]=TATTOOS

class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Personality]=PERSONALITY

class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Clothes]=CLOTHES
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Country]=COUNTRY
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Voice]=VOICE
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Gender]=GENDER
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Race]=RACE
*/

defaultproperties
{
	CurrentPreset = "PresetDefault"
}