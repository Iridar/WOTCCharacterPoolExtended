class UICustomize_CPExtended extends UICustomize;

enum ECosmeticType
{
	ECosmeticType_Name,
	ECosmeticType_Int,
	ECosmeticType_GenderInt,
	ECosmeticType_Biography
};

struct CheckboxPresetStruct
{
	var name Preset;
	var name OptionName;
	var bool bChecked;
};
var config(WOTCCharacterPoolExtended) array<CheckboxPresetStruct> CheckboxPresets;
var config(WOTCCharacterPoolExtended) array<name> Presets;

var protected config(WOTCCharacterPoolExtended) bool bShowCharPoolSoldiers;
var protected config(WOTCCharacterPoolExtended) bool bShowUniformSoldiers;
var protected config(WOTCCharacterPoolExtended) bool bShowBarracksSoldiers;
var protected config(WOTCCharacterPoolExtended) bool bShowDeadSoldiers;
var protected config(WOTCCharacterPoolExtended) bool bShowAllCosmeticOptions;
var protected config(WOTCCharacterPoolExtended) bool bInitComplete;

// TODO:
/*
# Priority

Extra Data parallel array doesn't appear to interact properly with importing/exporting units. Log everything, I guess.

Uniform extra info storag woes
https://discord.com/channels/165245941664710656/165245941664710656/903420519213318184

Also apply class specific uniforms on unit rank up?

# Character Pool
Fix weapons / Dual Wielding not working in CP?
Search bar for CP units?
Import uniforms from mod-added pools automatically?
Issue a warning if soldiers with duplicate names are present

Fix wrong unit being opened in CP sometimes. (Has to do with deleting units?)
-- Apparently the problem is the CP opens the unit you had selected when the interface ????????????, ? ?? ??? ???? ?? ???????? ??????. ??? ??????? ????????. ????? ?????????, ????????

If the MCM setting was enabled globally, and the player disabled it for some soldiers, and then the player disabled it globally, the setting will be enabled for those specific soldiers. 
This is undesirable. Figure out what to do about it. (probably wipe the setting when the MCM setting is disabled)

# This screen

Make clicking an item toggle its checkbox?
Way to add presets through in-game UI

## Checks:
1. Check if you can customize a unit with all armors in the campaign, then save them into CP, and that they will actually have all that appearance in the next campaign
2. Working with character pool files: creating new one, creating (importing) an existing one, deleting. exporting/importing units with appearance store.
3. Test automatic uniform managemennt settings. 

## Finalization
0. Clean up everything. Commentate. Add private/final. Go through TODO's
1. Localize stuff. Disabled reasons for cosmetic options.
2. Fix log error spam.

## Addressed

Maybe allow Appearance Store button to work as a "reskin armor" button? - redundant, can be done with this mod's customization screen by importing unit's own appearance from another armor.

## Ideas for later

AU units with custom rookie class should be able to choose from different classes in CP
I have no idea how they coded that, but it would appear that they stem from a separate species specific rookie template, then get a class independently, while the game properly treats them as rookies, allowing them to train in GTS. however in the character pool there is no option to change their class, which is an issue for anyone using the "use my class" mod

When copying biography, automatically update soldier name and country (MCM toggle)
Equipping weapons in CP will reskin them automatically with XSkin (RustyDios). Probably use a Tuple.

Enter Character Pool from Armory. Seems to be generally working, but has lots of weird behavior: 
incorrect soldier attitude, incorrect stance, legs getting IK'd to the armory floor, Loadout screen softlocking the game when exiting from it.

Enter photobooth from CP. Looks like it would require reworking a lot of the PB's functionality, since it relies on StateObjectReferences for units, which won't work for CP.
*/

// Internal cached info
var protected CharacterPoolManagerExtended		PoolMgr;
var protected X2BodyPartTemplateManager			BodyPartMgr;
var protected X2StrategyElementTemplateManager	StratMgr;
var protected X2ItemTemplateManager				ItemMgr;
var protected UIPawnMgr							PawnMgr;
var protected	XComGameStateHistory			History;
//var private bool								bUniformMode;
var protected name								CurrentPreset;
var protected string							SearchText;
var protected bool								bCanExitWithoutPopup;

var protected bool bShowCategoryHead;
var protected bool bShowCategoryBody;
var protected bool bShowCategoryTattoos;
var protected bool bShowCategoryArmorPattern;
var protected bool bShowCategoryWeaponPattern;
var protected bool bShowCategoryPersonality;

// Info about selected CP unit
var protected TAppearance					SelectedAppearance;
var protected X2SoldierPersonalityTemplate	SelectedAttitude;
var protected bool							bOriginalAppearanceSelected;
var protected XComGameState_Unit			SelectedUnit;

// Info about Armory unit
var protected XComHumanPawn					ArmoryPawn;
var protected XComGameState_Unit			ArmoryUnit;
var protected vector						OriginalPawnLocation;
var protected TAppearance					OriginalAppearance; // Appearance to restore if the player exits the screen without selecting anything
var protected TAppearance					PreviousAppearance; // Briefly cached appearance, used to check if we need to refresh pawn
var protected name							ArmorTemplateName;
var protected X2SoldierPersonalityTemplate	OriginalAttitude;

// Left list with lotta checkboxes for selecting which parts of the CP unit appearance are being carried over.
var protected UIBGBox	OptionsBG;
var protected UIList	OptionsList;

// Upper right list with a few checkboxes for filtering the list of CP units
var protected UIBGBox	FiltersBG;
var protected UIList	FiltersList;

// ================================================================================================================================================
// INITIAL SETUP - called once when screen is pushed, or when switching to a new armory unit.

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local UIScreen	   CycleScreen;
	local UIMouseGuard MouseGuard;

	`CPOLOG(GetFuncName() @ CheckboxPresets.Length @ default.CheckboxPresets.Length);

	super.InitScreen(InitController, InitMovie, InitName);

	// Cache stuff.
	PoolMgr = CharacterPoolManagerExtended(`CHARACTERPOOLMGR);
	if (PoolMgr == none)
		super.CloseScreen();

	BodyPartMgr = class'X2BodyPartTemplateManager'.static.GetBodyPartTemplateManager();
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	PawnMgr = Movie.Pres.GetUIPawnMgr();
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

	if (class'Help'.static.IsUnrestrictedCustomizationLoaded())
	{
		`CPOLOG("Setting timer for FixScreenPosition");
		SetTimer(0.1f, false, nameof(FixScreenPosition), self);
	}
}

simulated private function FixScreenPosition()
{
	// Unrestricted Customization does two things we want to get rid of:
	// 1. Shifts the entire screen's position (breaking the intended UI element placement)
	// 2. Adds a 'tool panel' with buttons like Copy / Paste / Randomize appearance,
	// which would be nice to have, but it's (A) redundant and (B) there's no room for it.
	local UIPanel Panel;
	if (Y == -100)
	{
		foreach ChildPanels(Panel)
		{
			if (Panel.Class.Name == 'uc_ui_ToolPanel')
			{
				Panel.Hide();
				break;
			}
		}
		`CPOLOG("Applying compatibility for Unrestricted Customization.");
		SetPosition(0, 0);
		return;
	}
	// In case of lags, we restart the timer until the issue is successfully resolved.
	SetTimer(0.1f, false, nameof(FixScreenPosition), self);
}

simulated function CreateFiltersList()
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
	//SpawnedItem.SetDisabled(true);
	SpawnedItem.UpdateDataButton("APPLY TO", "Apply Changes", OnApplyChangesButtonClicked); // TODO: Localize

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('ApplyToThisUnit');
	SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS("This unit"), "", true, none, none);

	SpawnedItem = Spawn(class'UIMechaListItem', FiltersList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('ApplyToSquad');
	SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS("squad"), "", false, none, none);
	SpawnedItem.SetDisabled(InShell());

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

	bOriginalAppearanceSelected = true;

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

	SelectedUnit = ArmoryUnit;
	OriginalAppearance = ArmoryPawn.m_kAppearance;
	SelectedAppearance = OriginalAppearance;
	OriginalAttitude = ArmoryUnit.GetPersonalityTemplate();
	OriginalPawnLocation = ArmoryPawn.Location;

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
		CustomizeScreen.UpdatePawnLocation();
	}
}

simulated function UpdateData()
{
	if (ColorSelector != none )
	{
		CloseColorSelector();
	}

	// Override in child classes for custom behavior
	Header.PopulateData(Unit);

	if(CustomizeManager.ActorPawn != none)
	{
		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(`SCREENSTACK.GetFirstInstanceOf(class'UIMouseGuard_RotatePawn')).SetActorPawn(CustomizeManager.ActorPawn);
	}

	UpdateSoldierList();
	UpdateOptionsList();
	UpdateUnitAppearance();
}

// ================================================================================================================================================
// LIVE UPDATE FUNCTIONS - called when toggling checkboxes or selecting a new CP unit.

simulated function UpdateSoldierList()
{
	local UIMechaListItem_Soldier			SpawnedItem;
	local XComGameState_Unit				CheckUnit;
	local XComGameState_HeadquartersXCom	XComHQ;
	local array<XComGameState_Unit>			Soldiers;

	List.ClearItems();

	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.UpdateDataButton(class'UIUtilities_Text'.static.GetColoredText("SELECT APPEARANCE", eUIState_Warning), 
		"Search" $ SearchText == "" ? "" : ":" @ SearchText, OnSearchButtonClicked); // TODO: Localize
	
	// First entry is always "No change"
	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.UpdateDataCheckbox("ORIGINAL APPEARANCE", "", bOriginalAppearanceSelected, SoldierCheckboxChanged, none); // TODO: Localize
	SpawnedItem.StoredAppearance.Appearance = OriginalAppearance;
	SpawnedItem.bOriginalAppearance = true;

	// Uniforms
	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('bShowUniformSoldiers');
	SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.GetColoredText("UNIFORMS", eUIState_Warning), "", bShowUniformSoldiers, SoldierCheckboxChanged, none); // TODO: Localize

	if (bShowUniformSoldiers)
	{
		foreach PoolMgr.CharacterPool(CheckUnit)
		{
			if (PoolMgr.IsUnitUniform(CheckUnit))
			{
				CreateAppearanceStoreEntriesForUnit(CheckUnit, true);
			}
		}
	}

	// Character pool
	SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('bShowCharPoolSoldiers');
	SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.GetColoredText("CHARACTER POOL", eUIState_Warning), "", bShowCharPoolSoldiers, SoldierCheckboxChanged, none); // TODO: Localize

	if (bShowCharPoolSoldiers)
	{
		foreach PoolMgr.CharacterPool(CheckUnit)
		{
			if (!PoolMgr.IsUnitUniform(CheckUnit))
			{
				CreateAppearanceStoreEntriesForUnit(CheckUnit, true);
			}
		}
	}
	if (!InShell())
	{
		// Soldiers in barracks
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('bShowBarracksSoldiers');
		SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.GetColoredText("BARRACKS", eUIState_Warning), "", bShowBarracksSoldiers, SoldierCheckboxChanged, none); // TODO: Localize

		XComHQ = `XCOMHQ;
		if (bShowBarracksSoldiers)
		{
			Soldiers = XComHQ.GetSoldiers(); 
			foreach Soldiers(CheckUnit)
			{
				CreateAppearanceStoreEntriesForUnit(CheckUnit);
			}
		}
		// Soldiers in morgue
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem('bShowDeadSoldiers');
		SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.GetColoredText("MORGUE", eUIState_Warning), "", bShowDeadSoldiers, SoldierCheckboxChanged, none); // TODO: Localize

		if (bShowDeadSoldiers)
		{
			Soldiers = GetDeadSoldiers(XComHQ);
			foreach Soldiers(CheckUnit)
			{
				CreateAppearanceStoreEntriesForUnit(CheckUnit);
			}
		}
	}
}


simulated private function OnApplyChangesButtonClicked(UIButton ButtonSource)
{
	bCanExitWithoutPopup = true;
	ApplyChanges();
	
	UpdateUnitAppearance();
	
	OriginalAppearance = ArmoryPawn.m_kAppearance;
	SelectedAppearance = OriginalAppearance;
	OriginalAttitude = ArmoryUnit.GetPersonalityTemplate();

	UpdateOptionsList();

	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
}

simulated private function OnSearchButtonClicked(UIButton ButtonSource)
{
	local TInputDialogData kData;

	if (SearchText != "")
	{
		SearchText = "";
		UpdateSoldierList();
	}
	else
	{
		kData.strTitle = "Search"; //TODO: Localize
		kData.iMaxChars = 99;
		kData.strInputBoxText = SearchText;
		kData.fnCallback = OnSearchInputBoxAccepted;

		Movie.Pres.UIInputDialog(kData);
	}
}

function OnSearchInputBoxAccepted(string text)
{
	SearchText = text;
	UpdateSoldierList();
}

simulated private function CreateAppearanceStoreEntriesForUnit(const XComGameState_Unit UnitState, optional bool bCharPool)
{
	local AppearanceInfo			StoredAppearance;
	local X2ItemTemplate			ArmorTemplate;
	local EGender					Gender;
	local name						LocalArmorTemplateName;
	local string					DisplayString;
	local bool						bCurrentAppearanceFound;
	local string					UnitName;
	local UIMechaListItem_Soldier	SpawnedItem;

	if (!IsUnitSameType(UnitState))
		return;

	if (GetFilterListCheckboxStatus('FilterClass') && ArmoryUnit.GetSoldierClassTemplateName() != UnitState.GetSoldierClassTemplateName())
		return;

	UnitName = class'CharacterPoolManagerExtended'.static.GetUnitFullNameExtraData_UnitState_Static(UnitState);
	if (bCharPool && IsUnitPresentInCampaign(UnitState)) // If unit was already drawn from the CP, color their entry green.
			UnitName = class'UIUtilities_Text'.static.GetColoredText(UnitName, eUIState_Good);

	// Cycle through Appearance Store, which may or may not include unit's current appearance.
	foreach UnitState.AppearanceStore(StoredAppearance)
	{	
		// Skip current appearance of current unit
		if (StoredAppearance.Appearance == OriginalAppearance && UnitState == ArmoryUnit)
			continue;

		Gender = EGender(int(Right(StoredAppearance.GenderArmorTemplate, 1)));
		if (GetFilterListCheckboxStatus('FilterGender') && OriginalAppearance.iGender != Gender)
			continue;

		LocalArmorTemplateName = name(Left(StoredAppearance.GenderArmorTemplate, Len(StoredAppearance.GenderArmorTemplate) - 1));
		if (GetFilterListCheckboxStatus('FilterArmorAppearance') && ArmorTemplateName != LocalArmorTemplateName)
			continue;

		ArmorTemplate = ItemMgr.FindItemTemplate(LocalArmorTemplateName);

		DisplayString = UnitName @ "|";

		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayString @= ArmorTemplate.FriendlyName;
		}
		else
		{
			DisplayString @= string(LocalArmorTemplateName);
		}

		if (Gender == eGender_Male)
		{
			DisplayString @= "|" @ class'XComCharacterCustomization'.default.Gender_Male;
		}
		else if (Gender == eGender_Female)
		{
			DisplayString @= "|" @ class'XComCharacterCustomization'.default.Gender_Female;
		}

		if (class'Help'.static.IsAppearanceCurrent(StoredAppearance.Appearance, UnitState.kAppearance))
		{
			bCurrentAppearanceFound = true;

			DisplayString @= "(Current)"; // TODO: Localize
		}

		if (SearchText != "" && InStr(DisplayString, SearchText,, true) == INDEX_NONE) // ignore case
			continue;
		
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.StoredAppearance = StoredAppearance;
		SpawnedItem.SetPersonalityTemplate();
		SpawnedItem.UnitState = UnitState;
		SpawnedItem.UpdateDataCheckbox(DisplayString, "", SelectedAppearance == SpawnedItem.StoredAppearance.Appearance && SpawnedItem.UnitState == SelectedUnit, SoldierCheckboxChanged, none);
		//SpawnedItem.SetDisabled(StoredAppearance.Appearance == OriginalAppearance && UnitState == ArmoryUnit); // Lock current appearance of current unit
	}

	// If Appearance Store didn't contain unit's current appearance, add unit's current appearance to the list as well.
	// As long it's not the currently selected unit there's no value in having them in the list.
	if (!bCurrentAppearanceFound)
	{
		// Skip current appearance of current unit
		if (UnitState.kAppearance == OriginalAppearance && UnitState == ArmoryUnit)
			return;

		Gender = EGender(UnitState.kAppearance.iGender);
		if (GetFilterListCheckboxStatus('FilterGender') && OriginalAppearance.iGender != Gender)
			return;

		// Can't use Item State cuz Character Pool units would have none.
		ArmorTemplate = class'Help'.static.GetItemTemplateFromCosmeticTorso(UnitState.kAppearance.nmTorso);

		if (GetFilterListCheckboxStatus('FilterArmorAppearance') && ArmorTemplateName != ArmorTemplate == none ? '' : ArmorTemplate.DataName)
			return;

		DisplayString = UnitState.GetFullName() @ "|";

		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayString @= ArmorTemplate.FriendlyName;
		}
		else
		{
			DisplayString @= string(LocalArmorTemplateName);
		}

		if (Gender == eGender_Male)
		{
			DisplayString @= "|" @ class'XComCharacterCustomization'.default.Gender_Male;
		}
		else if (Gender == eGender_Female)
		{
			DisplayString @= "|" @ class'XComCharacterCustomization'.default.Gender_Female;
		}
		DisplayString @= "(Current)"; // TODO: Localize

		if (SearchText != "" && InStr(DisplayString, SearchText,, true) == INDEX_NONE) // ignore case
			return;
		
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UpdateDataCheckbox(DisplayString, "", false, SoldierCheckboxChanged, none);
		SpawnedItem.StoredAppearance.Appearance = UnitState.kAppearance;
		SpawnedItem.SetPersonalityTemplate();
		SpawnedItem.UnitState = UnitState;
		//SpawnedItem.SetDisabled(UnitState == ArmoryUnit); // Lock current appearance of current unit
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

simulated private function bool IsUnitSameType(const XComGameState_Unit UnitState)
{	
	if (!class'Help'.static.IsUnrestrictedCustomizationLoaded())
	{	
		// If Unrestricted Customization is not present, then soldier cosmetics should respect
		// per-character-template customization.
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
	local UIMechaListItem	ListItem;
	local bool				bSkip;
	local int Index;
	local int i;

	bCanExitWithoutPopup = false;

	Index = List.GetItemIndex(CheckBox.ParentPanel);
	for (i = 0; i < List.ItemCount; i++)
	{
		// Skip the checkbox that was clicked on
		if (i == Index)
			continue;

		ListItem = UIMechaListItem(List.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none)
			continue;

		bSkip = false;
		switch(ListItem.MCName)
		{
			case 'bShowCharPoolSoldiers':
			case 'bShowBarracksSoldiers':
			case 'bShowDeadSoldiers':
				bSkip = true;
				break;
			default:
				break;
		}
		if (bSkip) 
			continue;
		
		ListItem.Checkbox.SetChecked(false, false);
	}

	CheckBox.SetChecked(true, false);
	if (Index != INDEX_NONE)
	{
		OnUnitSelected(Index);
	}
}

simulated private function SoldierListItemClicked(UIList ContainerList, int ItemIndex)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(List.GetItem(ItemIndex));
	if (ListItem.bDisabled)
		return;

	switch (ListItem.MCName)
	{
		case 'bShowCharPoolSoldiers':
			bShowCharPoolSoldiers = !bShowCharPoolSoldiers;
			default.bShowCharPoolSoldiers = bShowCharPoolSoldiers;
			SaveConfig();
			UpdateSoldierList();
			return;
		case 'bShowUniformSoldiers':
			bShowUniformSoldiers = !bShowUniformSoldiers;
			default.bShowUniformSoldiers = bShowUniformSoldiers;
			SaveConfig();
			UpdateSoldierList();
			return;
		case 'bShowBarracksSoldiers':
			bShowBarracksSoldiers = !bShowBarracksSoldiers;
			default.bShowBarracksSoldiers = bShowBarracksSoldiers;
			SaveConfig();
			UpdateSoldierList();
			return;
		case 'bShowDeadSoldiers':
			bShowDeadSoldiers = !bShowDeadSoldiers;
			default.bShowDeadSoldiers = bShowDeadSoldiers;
			SaveConfig();
			UpdateSoldierList();
			return;
		default:
			break;
	}

	SoldierCheckboxChanged(GetListItem(ItemIndex).Checkbox);
}

simulated function UpdatePawnLocation()
{
	local vector PawnLocation;

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
	bOriginalAppearanceSelected = ListItem.bOriginalAppearance;

	UpdateOptionsList();
	UpdateUnitAppearance();	
}

simulated private function bool ShouldRefreshPawn(const TAppearance NewAppearance)
{
	if (PreviousAppearance.iGender != NewAppearance.iGender)
	{
		return true;
	}
	if (PreviousAppearance.nmWeaponPattern != NewAppearance.nmWeaponPattern)
	{
		return true;
	}
	if (PreviousAppearance.iWeaponTint != NewAppearance.iWeaponTint)
	{
		return true;
	}
	return false;
}

simulated private function UpdateUnitAppearance()
{
	local TAppearance NewAppearance;

	NewAppearance = OriginalAppearance;
	CopyAppearance(NewAppearance, SelectedAppearance);

	PreviousAppearance = ArmoryPawn.m_kAppearance;
	ArmoryUnit.SetTAppearance(NewAppearance);
	ArmoryPawn.SetAppearance(NewAppearance);

	`CPOLOG(PreviousAppearance.nmHelmet @ NewAppearance.nmHelmet);

	//CustomizeManager.OnCategoryValueChange(eUICustomizeCat_WeaponColor, 0, NewAppearance.iWeaponTint);

	`CPOLOG("Calling ApplyChangesToUnitWeapons" @ PreviousAppearance.nmWeaponPattern @ NewAppearance.nmWeaponPattern @ PreviousAppearance.iWeaponTint @ NewAppearance.iWeaponTint);
	ApplyChangesToUnitWeapons(ArmoryUnit, NewAppearance, none);

	if (ShouldRefreshPawn(NewAppearance))
	{
		CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);

		// After ReCreatePawnVisuals, the CustomizeManager.ActorPawn, ArmoryPawn and become 'none'
		// Apparently there's some sort of threading issue at play, so we use a timer to get a reference to the new pawn with a slight delay.
		//OnRefreshPawn();
		SetTimer(0.01f, false, nameof(OnRefreshPawn), self);
	}	
	else
	{
		UpdatePawnAttitudeAnimation(); // OnRefreshPawn() will call this automatically
	}

	
	UpdateHeader();
}

// Can't use an Event Listener in CP, so using a timer (ugh)
simulated final function OnRefreshPawn()
{
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn != none)
	{
		UpdatePawnLocation();
		UpdatePawnAttitudeAnimation();

		`CPOLOG("Calling ApplyChangesToUnitWeapons" @ PreviousAppearance.nmWeaponPattern @ ArmoryPawn.m_kAppearance.nmWeaponPattern @ PreviousAppearance.iWeaponTint @ ArmoryPawn.m_kAppearance.iWeaponTint);
		ApplyChangesToUnitWeapons(ArmoryUnit, ArmoryPawn.m_kAppearance, none);

		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(`SCREENSTACK.GetFirstInstanceOf(class'UIMouseGuard_RotatePawn')).SetActorPawn(CustomizeManager.ActorPawn);
	}
	else
	{
		SetTimer(0.01f, false, nameof(OnRefreshPawn), self);
	}
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
	local TDialogueBoxData kDialogData;

	if (bCanExitWithoutPopup ||
		bOriginalAppearanceSelected || 
		!GetFilterListCheckboxStatus('ApplyToThisUnit') &&
		!GetFilterListCheckboxStatus('ApplyToCharPool') &&
		!GetFilterListCheckboxStatus('ApplyToSquad') &&
		!GetFilterListCheckboxStatus('ApplyToBarracks'))
	{
		CancelChanges();
		ArmoryPawn.SetLocation(OriginalPawnLocation);
		SavePresetCheckboxPositions();
		super.CloseScreen();
	}
	else
	{
		kDialogData.strTitle = "Exit without saving changes?"; // TODO: Localize
		kDialogData.eType = eDialog_Warning;
		kDialogData.strText = "Are you sure?";
		kDialogData.strAccept = "Exit without changes";
		kDialogData.strCancel = "Stay on screen";
		kDialogData.fnCallback = OnCloseScreenDialogCallback;
		`PRESBASE.UIRaiseDialog(kDialogData);
	}

	//if (bOriginalAppearanceSelected)
	//{
	//	CancelChanges();
	//}
	//else
	//{
	//	ApplyChanges();
	//}
}
/*
	var EUIDialogBoxDisplay eType;
	var bool                isShowing;
	var bool                isModal;
	var bool                bMuteAcceptSound;
	var bool                bMuteCancelSound;
	var string              strTitle;
	var string              strText; 
	var string              strAccept;
	var string              strCancel;
	var string              strImagePath;
	var SoundCue            sndIn;
	var SoundCue            sndOut;
	var delegate<ActionCallback> fnCallback;
	var delegate<ActionCallback> fnPreCloseCallback;
	var delegate<ActionCallbackEx> fnCallbackEx;
	var UICallbackData      xUserData;*/

private function OnCloseScreenDialogCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		CancelChanges();
		ArmoryPawn.SetLocation(OriginalPawnLocation);
		SavePresetCheckboxPositions();
		super.CloseScreen();
	}
}

simulated private function SavePresetCheckboxPositions()
{
	local CheckboxPresetStruct	NewStruct;
	local UIMechaListItem		ListItem;
	local int					Index;
	local bool					bFound;
	local int i;

	`CPOLOG(GetFuncName() @ "Options in the list:" @ OptionsList.ItemCount @ "Saved options:" @ CheckboxPresets.Length);

	NewStruct.Preset = CurrentPreset;

	if (Presets.Length > 0)
	{
		i = Presets.Length + 2; // 2 list members above the 0th preset.
	}
	for (i = i; i < OptionsList.ItemCount; i++) // "i = i" bypasses compile error. Just need to have something in there.
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none)
			continue;

		//if (InStr(string(ListItem.MCName), "UIMechaListItem") != INDEX_NONE)
		//	continue;

		`CPOLOG(i @ "List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ "Checked:" @ ListItem.Checkbox.bChecked);

		bFound = false;
		for (Index = 0; Index < CheckboxPresets.Length; Index++)
		{
			if (CheckboxPresets[Index].OptionName == ListItem.MCName &&
				CheckboxPresets[Index].Preset == CurrentPreset)
			{
				CheckboxPresets[Index].bChecked = ListItem.Checkbox.bChecked;
				bFound = true;
				break;
			}
		}

		if (!bFound)
		{
			NewStruct.OptionName = ListItem.MCName;
			NewStruct.bChecked = ListItem.Checkbox.bChecked;
			CheckboxPresets.AddItem(NewStruct);
		}
	}
	
	default.CheckboxPresets = CheckboxPresets; // This is actually necessary
	SaveConfig();
}

simulated private function ApplyPresetCheckboxPositions()
{
	local CheckboxPresetStruct CheckboxPreset;

	foreach CheckboxPresets(CheckboxPreset)
	{
		if (CheckboxPreset.Preset == CurrentPreset)
		{
			`CPOLOG("Setting preset checkbox:" @ CheckboxPreset.OptionName @ CheckboxPreset.bChecked);
			SetCheckbox(CheckboxPreset.OptionName, CheckboxPreset.bChecked);
		}
	}
}


simulated private function bool GetOptionCheckboxPosition(const name OptionName)
{
	local CheckboxPresetStruct CheckboxPreset;

	foreach CheckboxPresets(CheckboxPreset)
	{
		if (CheckboxPreset.Preset == CurrentPreset && CheckboxPreset.OptionName == OptionName)
		{
			return CheckboxPreset.bChecked;
		}
	}
}

simulated private function ApplyChanges()
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local StateObjectReference				SquadUnitRef;
	local array<XComGameState_Unit>			UnitStates;
	local XComGameState_Unit				UnitState;
	local XComGameState						NewGameState;

	// Current Unit
	if (GetFilterListCheckboxStatus('ApplyToThisUnit') && !bOriginalAppearanceSelected)
	{
		ApplyChangesToArmoryUnit();
	}
	else
	{
		CancelChanges();
	}

	// Character Pool
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
			ApplyChangesToUnit(UnitState, NewGameState);
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
			ApplyChangesToUnit(UnitState, NewGameState);
		}
		`GAMERULES.SubmitGameState(NewGameState);
	}
}

simulated private function ApplyChangesToUnit(XComGameState_Unit UnitState, optional XComGameState NewGameState)
{
	local TAppearance	NewAppearance;
	local string		strFirstName;
	local string		strNickname;
	local string		strLastName;

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

	NewAppearance = UnitState.kAppearance;
	CopyAppearance(NewAppearance, SelectedAppearance);

	UnitState.SetTAppearance(NewAppearance);
	UnitState.UpdatePersonalityTemplate();
	UnitState.StoreAppearance();

	ApplyChangesToUnitWeapons(UnitState, NewAppearance, NewGameState);
}

simulated private function ApplyChangesToUnitWeapons(XComGameState_Unit UnitState, TAppearance NewAppearance, XComGameState NewGameState)
{
	local XComGameState_Item		InventoryItem;
	local XComGameState_Item		NewInvenoryItem;
	local array<XComGameState_Item> InventoryItems;
	local X2WeaponTemplate			WeaponTemplate;
	local bool						bSubmit;

	`CPOLOG("Tint:" @ IsCheckboxChecked('iWeaponTint') @ "pattern:" @ IsCheckboxChecked('nmWeaponPattern'));

	// There are two separate tasks: updating weapon appearance in Shell (in CP) and in Armory.
	// In CP this happens automatically, because when we refresh the pawn, the unit's weapons automatically draw their customization from the unit state.
	// So we exit early out of this function.
	if (InShell())
		return;

	// While in Armory, we have to actually update the weapon appearance on Item States, which always requires submitting a Game State.
	// So if a NewGameState wasn't provided, we create our own, ~~with blackjack and hookers~~
	if (NewGameState == none)
	{		
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply weeapon appearance changes");
		bSubmit = true;
	}
	InventoryItems = UnitState.GetAllInventoryItems(NewGameState, true);
	`CPOLOG("Num inventory items:" @ InventoryItems.Length);
	foreach InventoryItems(InventoryItem)
	{
		WeaponTemplate = X2WeaponTemplate(InventoryItem.GetMyTemplate());
		if (WeaponTemplate == none)
			continue;

		`CPOLOG(WeaponTemplate.DataName @ InventoryItem.InventorySlot @ InventoryItem.ObjectID);
		
		NewInvenoryItem = XComGameState_Item(NewGameState.ModifyStateObject(InventoryItem.Class, InventoryItem.ObjectID));
		if (IsCheckboxChecked('iWeaponTint'))
		{
			if (WeaponTemplate.bUseArmorAppearance)
			{
				NewInvenoryItem.WeaponAppearance.iWeaponTint = NewAppearance.iArmorTint;
			}
			else
			{
				NewInvenoryItem.WeaponAppearance.iWeaponTint = NewAppearance.iWeaponTint;
			}
		}
		else
		{
			if (WeaponTemplate.bUseArmorAppearance)
			{
				NewInvenoryItem.WeaponAppearance.iWeaponTint = OriginalAppearance.iArmorTint;
			}
			else
			{
				NewInvenoryItem.WeaponAppearance.iWeaponTint = OriginalAppearance.iWeaponTint;
			}
		}

		if (IsCheckboxChecked('nmWeaponPattern'))
		{
			NewInvenoryItem.WeaponAppearance.nmWeaponPattern = NewAppearance.nmWeaponPattern;
		}
		else
		{
			NewInvenoryItem.WeaponAppearance.nmWeaponPattern = OriginalAppearance.nmWeaponPattern;
		}
		
	}
	if (bSubmit)
	{
		if (NewGameState.GetNumGameStateObjects() > 0)
		{
			`GAMERULES.SubmitGameState(NewGameState);
		}
		else
		{
			History.CleanupPendingGameState(NewGameState);
		}
	}
	// This doesn't seem to do anything.
	//ArmoryPawn.CreateVisualInventoryAttachments(Movie.Pres.GetUIPawnMgr(), UnitState, NewGameState);
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

	ArmoryUnit.StoreAppearance();
	CustomizeManager.SubmitUnitCustomizationChanges();

	if (!InShell())
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Apply appearance changes");
		ArmoryUnit = XComGameState_Unit(NewGameState.ModifyStateObject(ArmoryUnit.Class, ArmoryUnit.ObjectID));
		ArmoryUnit.UpdatePersonalityTemplate();

		ApplyChangesToUnitWeapons(ArmoryUnit, ArmoryPawn.m_kAppearance, NewGameState);
		`GAMERULES.SubmitGameState(NewGameState);
	}
	ArmoryPawn.CustomizationIdleAnim = ArmoryUnit.GetPersonalityTemplate().IdleAnimName;
}

simulated function CancelChanges()
{
	PreviousAppearance = ArmoryPawn.m_kAppearance;
	ArmoryUnit.SetTAppearance(OriginalAppearance);
	ArmoryPawn.SetAppearance(OriginalAppearance);

	if (ShouldRefreshPawn(OriginalAppearance))
	{
		CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);
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
	local bool bGenderChange;

	if (IsCheckboxChecked('iGender'))
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
		if (IsCheckboxChecked('nmHead'))				{NewAppearance.nmHead = UniformAppearance.nmHead; NewAppearance.nmEye = UniformAppearance.nmEye; NewAppearance.nmTeeth = UniformAppearance.nmTeeth; NewAppearance.iRace = UniformAppearance.iRace;}
		//if (IsCheckboxChecked('iRace'))					NewAppearance.iRace = UniformAppearance.iRace;
		if (IsCheckboxChecked('nmHaircut'))				NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
		//if (IsCheckboxChecked('iFacialHair'))			NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
		if (IsCheckboxChecked('nmBeard'))				NewAppearance.nmBeard = UniformAppearance.nmBeard;
		//if (IsCheckboxChecked('iVoice'))				NewAppearance.iVoice = UniformAppearance.iVoice;
		if (IsCheckboxChecked('nmTorso'))				NewAppearance.nmTorso = UniformAppearance.nmTorso;
		if (IsCheckboxChecked('nmArms'))				NewAppearance.nmArms = UniformAppearance.nmArms;
		if (IsCheckboxChecked('nmLegs'))				NewAppearance.nmLegs = UniformAppearance.nmLegs;
		if (IsCheckboxChecked('nmHelmet'))				NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
		if (IsCheckboxChecked('nmFacePropLower'))		NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
		if (IsCheckboxChecked('nmFacePropUpper'))		NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
		if (IsCheckboxChecked('nmVoice'))				NewAppearance.nmVoice = UniformAppearance.nmVoice;
		if (IsCheckboxChecked('nmScars'))				NewAppearance.nmScars = UniformAppearance.nmScars;
		//if (IsCheckboxChecked('nmTorso_Underlay'))		NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
		//if (IsCheckboxChecked('nmArms_Underlay'))		NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
		//if (IsCheckboxChecked('nmLegs_Underlay'))		NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
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
	}

	if (IsCheckboxChecked('iHairColor'))			NewAppearance.iHairColor = UniformAppearance.iHairColor;
	if (IsCheckboxChecked('iSkinColor'))			NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
	if (IsCheckboxChecked('iEyeColor'))				NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
	if (IsCheckboxChecked('nmFlag'))				NewAppearance.nmFlag = UniformAppearance.nmFlag;
	if (IsCheckboxChecked('iAttitude'))				NewAppearance.iAttitude = UniformAppearance.iAttitude;
	//if (IsCheckboxChecked('iArmorDeco'))			NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
	if (IsCheckboxChecked('iArmorTint'))			NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
	if (IsCheckboxChecked('iArmorTintSecondary'))	NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
	if (IsCheckboxChecked('iWeaponTint'))			NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
	if (IsCheckboxChecked('iTattooTint'))			NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
	if (IsCheckboxChecked('nmWeaponPattern'))		NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
	if (IsCheckboxChecked('nmPatterns'))			NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
	//if (IsCheckboxChecked('nmLanguage'))			NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
	if (IsCheckboxChecked('nmTattoo_LeftArm'))		NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
	if (IsCheckboxChecked('nmTattoo_RightArm'))		NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;
	//if (IsCheckboxChecked('bGhostPawn'))			NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;
}

simulated private function bool IsCheckboxChecked(name OptionName)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(OptionsList.GetChildByName(OptionName, false));

	return ListItem != none && ListItem.Checkbox.bChecked;
}

simulated final function SetCheckbox(name OptionName, bool bChecked)
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
	
	// Can't do it here, otherwise the relationship between CurrentPreset and checkboxes will be broken!
	//SavePresetCheckboxPositions();

	OptionsList.ClearItems();

	CreateOptionShowAll();

	// PRESETS
	CreateOptionPresets();

	if (!bShowAllCosmeticOptions && bOriginalAppearanceSelected)
		return;

	// HEAD
	if (MaybeCreateOptionCategory('bShowCategoryHead', class'UICustomize_Menu'.default.m_strEditHead))
	{
		MaybeCreateAppearanceOption('iGender',				OriginalAppearance.iGender,				SelectedAppearance.iGender,				ECosmeticType_GenderInt);
		//MaybeCreateAppearanceOption('iRace',				OriginalAppearance.iRace,				SelectedAppearance.iRace,				ECosmeticType_Int);
		MaybeCreateAppearanceOption('iSkinColor',			OriginalAppearance.iSkinColor,			SelectedAppearance.iSkinColor,			ECosmeticType_Int);
		MaybeCreateAppearanceOption('nmHead',				OriginalAppearance.nmHead,				SelectedAppearance.nmHead,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmHelmet',				OriginalAppearance.nmHelmet,			SelectedAppearance.nmHelmet,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmFacePropUpper',		OriginalAppearance.nmFacePropUpper,		SelectedAppearance.nmFacePropUpper,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmFacePropLower',		OriginalAppearance.nmFacePropLower,		SelectedAppearance.nmFacePropLower,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmHaircut',			OriginalAppearance.nmHaircut,			SelectedAppearance.nmHaircut,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmBeard',				OriginalAppearance.nmBeard,				SelectedAppearance.nmBeard,				ECosmeticType_Name);
		MaybeCreateOptionColorInt('iHairColor',				OriginalAppearance.iHairColor,			SelectedAppearance.iHairColor,			ePalette_HairColor);
		//MaybeCreateAppearanceOption('iFacialHair',			OriginalAppearance.iFacialHair,			SelectedAppearance.iFacialHair,			ECosmeticType_Int);
		MaybeCreateOptionColorInt('iEyeColor',				OriginalAppearance.iEyeColor,			SelectedAppearance.iEyeColor,			ePalette_EyeColor);
		MaybeCreateAppearanceOption('nmScars',				OriginalAppearance.nmScars,				SelectedAppearance.nmScars,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmFacePaint',			OriginalAppearance.nmFacePaint,			SelectedAppearance.nmFacePaint,			ECosmeticType_Name);
		//MaybeCreateAppearanceOption('nmEye',				OriginalAppearance.nmEye,				SelectedAppearance.nmEye,				ECosmeticType_Name);
		//MaybeCreateAppearanceOption('nmTeeth',			OriginalAppearance.nmTeeth,				SelectedAppearance.nmTeeth,				ECosmeticType_Name);
	}
	// BODY
	if (MaybeCreateOptionCategory('bShowCategoryBody', class'UICustomize_Menu'.default.m_strEditBody))
	{
		MaybeCreateAppearanceOption('nmTorso',				OriginalAppearance.nmTorso,				SelectedAppearance.nmTorso,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmTorsoDeco',			OriginalAppearance.nmTorsoDeco,			SelectedAppearance.nmTorsoDeco,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmArms',				OriginalAppearance.nmArms,				SelectedAppearance.nmArms,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmLeftArm',			OriginalAppearance.nmLeftArm,			SelectedAppearance.nmLeftArm,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmLeftArmDeco',		OriginalAppearance.nmLeftArmDeco,		SelectedAppearance.nmLeftArmDeco,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmLeftForearm',		OriginalAppearance.nmLeftForearm,		SelectedAppearance.nmLeftForearm,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmRightArm',			OriginalAppearance.nmRightArm,			SelectedAppearance.nmRightArm,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmRightArmDeco',		OriginalAppearance.nmRightArmDeco,		SelectedAppearance.nmRightArmDeco,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmRightForearm',		OriginalAppearance.nmRightForearm,		SelectedAppearance.nmRightForearm,		ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmLegs',				OriginalAppearance.nmLegs,				SelectedAppearance.nmLegs,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmThighs',				OriginalAppearance.nmThighs,			SelectedAppearance.nmThighs,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmShins',				OriginalAppearance.nmShins,				SelectedAppearance.nmShins,				ECosmeticType_Name);
		//MaybeCreateAppearanceOption('nmTorso_Underlay',		OriginalAppearance.nmTorso_Underlay,	SelectedAppearance.nmTorso_Underlay,	ECosmeticType_Name);
		//MaybeCreateAppearanceOption('nmArms_Underlay',		OriginalAppearance.nmArms_Underlay,		SelectedAppearance.nmArms_Underlay,		ECosmeticType_Name);
		//MaybeCreateAppearanceOption('nmLegs_Underlay',		OriginalAppearance.nmLegs_Underlay,		SelectedAppearance.nmLegs_Underlay,		ECosmeticType_Name);
	}
	// TATTOOS - thanks to Xym for Localize()
	if (MaybeCreateOptionCategory('bShowCategoryTattoos', Localize("UIArmory_Customize", "m_strBaseLabels[eUICustomizeBase_Tattoos]", "XComGame")))
	{
		MaybeCreateAppearanceOption('nmTattoo_LeftArm',		OriginalAppearance.nmTattoo_LeftArm,	SelectedAppearance.nmTattoo_LeftArm,	ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmTattoo_RightArm',	OriginalAppearance.nmTattoo_RightArm,	SelectedAppearance.nmTattoo_RightArm,	ECosmeticType_Name);
		MaybeCreateOptionColorInt('iTattooTint',			OriginalAppearance.iTattooTint,			SelectedAppearance.iTattooTint,			ePalette_ArmorTint);
	}
	// ARMOR PATTERN
	if (MaybeCreateOptionCategory('bShowCategoryArmorPattern', class'UICustomize_Body'.default.m_strArmorPattern))
	{
		MaybeCreateAppearanceOption('nmPatterns',			OriginalAppearance.nmPatterns,			SelectedAppearance.nmPatterns,			ECosmeticType_Name);
		//MaybeCreateAppearanceOption('iArmorDeco',			OriginalAppearance.iArmorDeco,			SelectedAppearance.iArmorDeco,			ECosmeticType_Name);
		MaybeCreateOptionColorInt('iArmorTint',				OriginalAppearance.iArmorTint,			SelectedAppearance.iArmorTint,			ePalette_ArmorTint);
		MaybeCreateOptionColorInt('iArmorTintSecondary',	OriginalAppearance.iArmorTintSecondary, SelectedAppearance.iArmorTintSecondary, ePalette_ArmorTint, false);
	}
	// WEAPON PATTERN
	if (MaybeCreateOptionCategory('bShowCategoryWeaponPattern', class'UICustomize_Weapon'.default.m_strWeaponPattern))
	{
		MaybeCreateAppearanceOption('nmWeaponPattern',		OriginalAppearance.nmWeaponPattern,		SelectedAppearance.nmWeaponPattern,		ECosmeticType_Name);
		MaybeCreateOptionColorInt('iWeaponTint',			OriginalAppearance.iWeaponTint,			SelectedAppearance.iWeaponTint,			ePalette_ArmorTint);	
	}
	// PERSONALITY
	if (MaybeCreateOptionCategory('bShowCategoryPersonality', Localize("UIArmory_Customize", "m_strBaseLabels[eUICustomizeBase_Personality]", "XComGame")))
	{
		MaybeCreateOptionAttitude();
		MaybeCreateAppearanceOption('nmVoice',				OriginalAppearance.nmVoice,				SelectedAppearance.nmVoice,				ECosmeticType_Name);
		//MaybeCreateAppearanceOption('nmLanguage',			OriginalAppearance.nmLanguage,			SelectedAppearance.nmLanguage,			ECosmeticType_Name);
		MaybeCreateAppearanceOption('nmFlag',				OriginalAppearance.nmFlag,				SelectedAppearance.nmFlag,				ECosmeticType_Name);
		MaybeCreateAppearanceOption('FirstName',			ArmoryUnit.GetFirstName(),				SelectedUnit.GetFirstName(),			ECosmeticType_Name);
		MaybeCreateAppearanceOption('LastName',				ArmoryUnit.GetLastName(),				SelectedUnit.GetLastName(),				ECosmeticType_Name);
		MaybeCreateAppearanceOption('Nickname',				ArmoryUnit.GetNickName(),				SelectedUnit.GetNickName(),				ECosmeticType_Name);
		MaybeCreateAppearanceOption('Biography',			ArmoryUnit.GetBackground(),				SelectedUnit.GetBackground(),			ECosmeticType_Biography);
	}
	//LogAllOptions();

	//ActivatePreset();
}

simulated private function LogAllOptions()
{
	local UIMechaListItem		ListItem;
	local int i;

	`CPOLOG(GetFuncName() @  OptionsList.ItemCount);
	`CPOLOG("----------------------------------------------------------");

	for (i = 0; i < OptionsList.ItemCount; i++)
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none)
			continue;
			
		`CPOLOG("List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ ListItem.Checkbox != none);
	}
	`CPOLOG("----------------------------------------------------------");
}

simulated private function CreateOptionPresets()
{
	local string strFriendlyPresetName;
	local UIMechaListItem SpawnedItem;
	local int i;

	if (Presets.Length == 0)
		return;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(); 
	SpawnedItem.SetDisabled(true);
	SpawnedItem.UpdateDataDescription(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset));

	`CPOLOG(GetFuncName() @ `showvar(CurrentPreset));

	for (i = 0; i < Presets.Length; i++)
	{
		strFriendlyPresetName = Localize("UICustomize_CPExtended", string(Presets[i]), "WOTCCharacterPoolExtended");
		if (strFriendlyPresetName == "")
			strFriendlyPresetName = string(Presets[i]);

		CreateOptionPreset(Presets[i], strFriendlyPresetName, "", CurrentPreset == Presets[i]);
	}
}


simulated private function MaybeCreateAppearanceOption(name OptionName, coerce string CurrentCosmetic, coerce string NewCosmetic, ECosmeticType CosmeticType)
{	
	local UIMechaListItem_Button	SpawnedItem;
	local string					strDesc;
	local bool						bChecked;
	local bool						bDisabled;
	local bool						bNewIsSameAsCurrent;

	`CPOLOG(`showvar(OptionName) @ `showvar(CurrentCosmetic) @ `showvar(NewCosmetic));

	// Don't create the cosmetic option if both the current appearance and selected appearance are the same or empty.
	switch (CosmeticType)
	{
		case ECosmeticType_Int:
		case ECosmeticType_GenderInt:
			bNewIsSameAsCurrent = int(CurrentCosmetic) == int(NewCosmetic);
			break;
		case ECosmeticType_Name:
			if (CurrentCosmetic == NewCosmetic || class'Help'.static.IsCosmeticEmpty(CurrentCosmetic) && class'Help'.static.IsCosmeticEmpty(NewCosmetic))
			{
				bNewIsSameAsCurrent = true;
			}
			break;
		case ECosmeticType_Biography:
			bNewIsSameAsCurrent = CurrentCosmetic == NewCosmetic;
			break;
		default:
			`CPOLOG("WARNING, unknown cosmetic type!" @ CosmeticType); // Shouldn't ever happen, really
			return;
	}
	
	if (bNewIsSameAsCurrent && !bShowAllCosmeticOptions)
		return;

	`CPOLOG("Creating option");

	SpawnedItem = Spawn(class'UIMechaListItem_Button', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	// If this option doesn't care about gender, then we load the saved preset for it.
	if (IsOptionGenderAgnostic(OptionName))
	{
		bChecked = GetOptionCheckboxPosition(OptionName);
	}
	else if (OriginalAppearance.iGender != SelectedAppearance.iGender) // Is gender change required?
	{
		// Disallow toggling the checkbox if the option cares about gender and we're changing either from non-empty or to non-empty.
		bDisabled = CosmeticType == ECosmeticType_Name && (!class'Help'.static.IsCosmeticEmpty(CurrentCosmetic) || class'Help'.static.IsCosmeticEmpty(NewCosmetic));

		if (IsCheckboxChecked('iGender')) // Are we doing gender change?
		{
			bChecked = true;
		}
		else
		{
			bChecked = false;
		}
	}

	switch (CosmeticType)
	{
		case ECosmeticType_Int:
			if (bNewIsSameAsCurrent)
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ CurrentCosmetic;
			else
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ CurrentCosmetic @ "->" @ NewCosmetic;
			SpawnedItem.UpdateDataCheckbox(strDesc, "", bChecked, OptionCheckboxChanged, none);
			break;
		case ECosmeticType_Name:
			if (bNewIsSameAsCurrent)
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetBodyPartFriendlyName(OptionName, CurrentCosmetic);
			else
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetBodyPartFriendlyName(OptionName, CurrentCosmetic) @ "->" @ GetBodyPartFriendlyName(OptionName, NewCosmetic);
			
			SpawnedItem.UpdateDataCheckbox(strDesc, "", bChecked, OptionCheckboxChanged, none);

			break;
		case ECosmeticType_GenderInt:
			if (bNewIsSameAsCurrent)
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetFriendlyGender(int(CurrentCosmetic));
			else
				strDesc = GetOptionFriendlyName(OptionName) $ ":" @ GetFriendlyGender(int(CurrentCosmetic)) @ "->" @ GetFriendlyGender(int(NewCosmetic));

			SpawnedItem.UpdateDataCheckbox(strDesc, "", bChecked, OptionCheckboxChanged, none);
			break;
		case ECosmeticType_Biography:
			strDesc = class'UICustomize_Info'.default.m_strEditBiography;	
			SpawnedItem.UpdateDataCheckbox(strDesc, "", bChecked, OptionCheckboxChanged, none);
			SpawnedItem.UpdateDataButton(strDesc, "Preview", OnPreviewBiographyButtonClicked); // TODO: Localize		
			break;
		default:
			break;
	}

	//SpawnedItem.UpdateDataCheckbox(strDesc, "", bChecked, OptionCheckboxChanged, none);

	SpawnedItem.SetDisabled(!bShowAllCosmeticOptions && bDisabled); // Have to do this after checkbox has been assigned to the list item.
}

simulated private function MaybeCreateOptionColorInt(name OptionName, int iValue, int iNewValue, EColorPalette PaletteType, optional bool bPrimary = true)
{
	local UIMechaListItem_Color		SpawnedItem;
	local XComLinearColorPalette	Palette;
	local LinearColor				ParamColor;
	local LinearColor				NewParamColor;

	if (!bShowAllCosmeticOptions && iValue == iNewValue)
		return;

	SpawnedItem = Spawn(class'UIMechaListItem_Color', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName), 
			"",
			GetOptionCheckboxPosition(OptionName),
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

simulated private function bool IsOptionGenderAgnostic(const name OptionName)
{
	switch (OptionName)
	{
	// Gender agnostic
	case 'iGender': return true; // Counter-intuitive, but we need to return 'true' here so that this option itself is not disabled.
	case 'iHairColor': return true;
	case 'iSkinColor': return true;
	case 'iEyeColor': return true;
	case 'nmFlag': return true;
	//case 'iVoice': return true;
	case 'iAttitude': return true;
	case 'iArmorTint': return true;
	case 'iArmorTintSecondary': return true;
	case 'iWeaponTint': return true;
	case 'iTattooTint': return true;
	case 'nmTattoo_LeftArm': return true;
	case 'nmTattoo_RightArm': return true;
	case 'nmWeaponPattern': return true;
	case 'nmPatterns': return true;
	//case 'nmLanguage': return true;
	case 'FirstName': return true;
	case 'LastName': return true;
	case 'Nickname': return true;

	//Gender specific
	case 'iRace': return false;
	case 'nmHead': return false;
	case 'nmHaircut': return false;
	//case 'iFacialHair': return false;
	case 'nmBeard': return false;
	//case 'iArmorDeco': return false;
	case 'nmPawn': return false;
	case 'nmTorso': return false;
	case 'nmArms': return false;
	case 'nmLegs': return false;
	case 'nmHelmet': return false;
	case 'nmEye': return false;
	case 'nmTeeth': return false;
	case 'nmFacePropLower': return false;
	case 'nmFacePropUpper': return false;
	case 'nmVoice': return false;
	case 'nmScars': return false;
	case 'nmTorso_Underlay': return false;
	case 'nmArms_Underlay': return false;
	case 'nmLegs_Underlay': return false;
	case 'nmFacePaint': return false;
	case 'nmLeftArm': return false;
	case 'nmRightArm': return false;
	case 'nmLeftArmDeco': return false;
	case 'nmRightArmDeco': return false;
	case 'nmLeftForearm': return false;
	case 'nmRightForearm': return false;
	case 'nmThighs': return false;
	case 'nmShins': return false;
	case 'nmTorsoDeco': return false;
	//case 'bGhostPawn': return false;

	default:
		return true;
	}
}

simulated private function OnPreviewBiographyButtonClicked(UIButton ButtonSource)
{
	local UIScreen_Biography BioScreen;

	SavePresetCheckboxPositions();
	BioScreen = Movie.Pres.Spawn(class'UIScreen_Biography', self);
	Movie.Pres.ScreenStack.Push(BioScreen);
	BioScreen.ShowText(ArmoryUnit.GetBackground(), SelectedUnit.GetBackground());
}

simulated private function MaybeCreateOptionAttitude()
{
	local UIMechaListItem SpawnedItem;

	if (OriginalAppearance.iAttitude == SelectedAppearance.iAttitude)
		return;
	
	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('iAttitude');
									 
	SpawnedItem.UpdateDataCheckbox(class'UICustomize_Info'.default.m_strAttitude $ ":" @ OriginalAttitude.FriendlyName @ "->" @ SelectedAttitude.FriendlyName, 
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

simulated function OptionCheckboxChanged(UICheckbox CheckBox)
{
	SavePresetCheckboxPositions();

	`CPOLOG(CheckBox.GetParent(class'UIMechaListItem_Button').MCName);

	bCanExitWithoutPopup = false;

	switch (CheckBox.GetParent(class'UIMechaListItem_Button').MCName)
	{
		case 'iGender':
			UpdateOptionsList();
			break;
		case 'bShowAllCosmeticOptions':
			bShowAllCosmeticOptions = !bShowAllCosmeticOptions;
			default.bShowAllCosmeticOptions = bShowAllCosmeticOptions;
			SaveConfig();
			UpdateOptionsList();
			return;
		default:
			break;
	}

	UpdateUnitAppearance();
}

simulated private function bool MaybeCreateOptionCategory(name CategoryName, string strText)
{
	local UIMechaListItem SpawnedItem;
	local bool bChecked;

	if (bShowAllCosmeticOptions || ShouldShowCategoryOption(CategoryName))
	{
		SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem(CategoryName); 
		//SpawnedItem.SetDisabled(true);

		bChecked = bShowAllCosmeticOptions || GetOptionCategoryCheckboxStatus(CategoryName);

		SpawnedItem.UpdateDataCheckbox(class'UIUtilities_Text'.static.GetColoredText(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(strText), eUIState_Warning),
			"", bChecked, OptionCategoryCheckboxChanged, none);

		SpawnedItem.SetDisabled(bShowAllCosmeticOptions);

		return bChecked || bShowAllCosmeticOptions;
	}
	return bShowAllCosmeticOptions;
}

simulated private function bool ShouldShowCategoryOption(name CategoryName)
{
	switch (CategoryName)
	{
		case 'bShowCategoryHead': return ShouldShowHeadCategory();
		case 'bShowCategoryBody': return ShouldShowBodyCategory();
		case 'bShowCategoryTattoos': return ShouldShowTattooCategory();
		case 'bShowCategoryArmorPattern': return ShouldShowArmorPatternCategory();
		case 'bShowCategoryWeaponPattern': return ShouldShowWeaponPatternCategory();
		case 'bShowCategoryPersonality': return ShouldShowPersonalityCategory();
		default:
			return false;
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
			//OriginalAppearance.iFacialHair != SelectedAppearance.iFacialHair ||
			OriginalAppearance.iEyeColor != SelectedAppearance.iEyeColor ||
			OriginalAppearance.nmScars != SelectedAppearance.nmScars || 
			OriginalAppearance.nmFacePaint != SelectedAppearance.nmFacePaint/*  ||
			OriginalAppearance.nmEye != SelectedAppearance.nmEye||
			OriginalAppearance.nmTeeth != SelectedAppearance.nmTeeth*/;
}

simulated private function bool ShouldShowBodyCategory()
{	
	return  OriginalAppearance.nmTorso != SelectedAppearance.nmTorso ||
			OriginalAppearance.nmArms != SelectedAppearance.nmArms ||				
			OriginalAppearance.nmLegs != SelectedAppearance.nmLegs ||					
			//OriginalAppearance.nmTorso_Underlay != SelectedAppearance.nmTorso_Underlay ||
			//OriginalAppearance.nmArms_Underlay != SelectedAppearance.nmArms_Underlay ||
			OriginalAppearance.nmLeftArm != SelectedAppearance.nmLeftArm ||
			OriginalAppearance.nmRightArm != SelectedAppearance.nmRightArm ||
			OriginalAppearance.nmLeftArmDeco != SelectedAppearance.nmLeftArmDeco ||
			OriginalAppearance.nmRightArmDeco != SelectedAppearance.nmRightArmDeco ||		
			OriginalAppearance.nmLeftForearm != SelectedAppearance.nmLeftForearm ||	
			OriginalAppearance.nmRightForearm != SelectedAppearance.nmRightForearm ||		
			//OriginalAppearance.nmLegs_Underlay != SelectedAppearance.nmLegs_Underlay ||	
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
			!class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmTattoo_LeftArm) &&
			!class'Help'.static.IsCosmeticEmpty(SelectedAppearance.nmTattoo_RightArm);
}

simulated private function bool ShouldShowArmorPatternCategory()
{	
	return OriginalAppearance.nmPatterns != SelectedAppearance.nmPatterns ||		
		  // OriginalAppearance.iArmorDeco != SelectedAppearance.iArmorDeco ||				
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
			//OriginalAppearance.nmLanguage != SelectedAppearance.nmLanguage ||
			ArmoryUnit.GetFirstName() == SelectedUnit.GetFirstName() ||
			ArmoryUnit.GetLastName() == SelectedUnit.GetLastName() ||
			ArmoryUnit.GetNickName() == SelectedUnit.GetNickName() ||
			ArmoryUnit.GetBackground() == SelectedUnit.GetBackground();				
}

simulated private function bool GetOptionCategoryCheckboxStatus(name CategoryName)
{
	switch (CategoryName)
	{
		case 'bShowCategoryHead': return bShowCategoryHead;
		case 'bShowCategoryBody': return bShowCategoryBody;
		case 'bShowCategoryTattoos': return bShowCategoryTattoos;
		case 'bShowCategoryArmorPattern': return bShowCategoryArmorPattern;
		case 'bShowCategoryWeaponPattern': return bShowCategoryWeaponPattern;
		case 'bShowCategoryPersonality': return bShowCategoryPersonality;
		default:
			return false;
	}
}

simulated private function SetOptionCategoryCheckboxStatus(name CategoryName, bool bNewValue)
{
	switch (CategoryName)
	{
		case 'bShowCategoryHead': bShowCategoryHead = bNewValue; break;
		case 'bShowCategoryBody': bShowCategoryBody = bNewValue; break;
		case 'bShowCategoryTattoos': bShowCategoryTattoos = bNewValue; break;
		case 'bShowCategoryArmorPattern': bShowCategoryArmorPattern = bNewValue; break;
		case 'bShowCategoryWeaponPattern': bShowCategoryWeaponPattern = bNewValue; break;
		case 'bShowCategoryPersonality': bShowCategoryPersonality = bNewValue; break;
		default:
			return;
	}
}

simulated private function OptionCategoryCheckboxChanged(UICheckbox CheckBox)
{
	SetOptionCategoryCheckboxStatus(CheckBox.GetParent(class'UIMechaListItem').MCName, CheckBox.bChecked);
	UpdateOptionsList();
}

simulated function CreateOptionShowAll()
{
	local UIMechaListItem_Button SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem_Button', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('bShowAllCosmeticOptions'); 
	//SpawnedItem.SetDisabled(true);
	SpawnedItem.UpdateDataCheckbox("SHOW ALL OPTIONS", "", bShowAllCosmeticOptions, OptionCheckboxChanged, none);  // TODO: Localize
}

simulated private function string GetHTMLColor(LinearColor ParamColor)
{
	local string ColorString;

	ColorString = Right(ToHex(int(ParamColor.R * 255.0f)), 2) $ Right(ToHex(int(ParamColor.G * 255.0f)), 2)  $ Right(ToHex(int(ParamColor.B * 255.0f)), 2);
	
	return ColorString;
}


simulated private function CreateOptionPreset(name OptionName, string strText, string strTooltip, optional bool bChecked)
{
	local UIMechaListItem_Button SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem_Button', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	SpawnedItem.UpdateDataCheckbox(strText, strTooltip, bChecked, OptionPresetCheckboxChanged, none);

	`CPOLOG(`showvar(CurrentPreset) @ OptionName @ bChecked);

	if (OptionName != 'PresetDefault')
	{
		SpawnedItem.UpdateDataButton(strText, "Copy Preset", // TODO: Localize
			OnCopyPresetButtonClicked);
	}
}

simulated private function OnCopyPresetButtonClicked(UIButton ButtonSource)
{
	local CheckboxPresetStruct	NewPresetStruct;
	local name					CopyPreset;
	local int i;

	bCanExitWithoutPopup = false;

	CopyPreset = ButtonSource.GetParent(class'UIMechaListItem_Button').MCName;

	//`CPOLOG(`showvar(CurrentPreset) @ `showvar(CopyPreset));

	for (i = CheckboxPresets.Length - 1; i >= 0; i--)
	{
		if (CheckboxPresets[i].Preset == CurrentPreset)
		{
			//`CPOLOG(i @ "removing entry for current preset" @ CheckboxPresets[i].OptionName @ CheckboxPresets[i].bChecked);
			CheckboxPresets.Remove(i, 1);
		}
	}
	for (i = CheckboxPresets.Length - 1; i >= 0; i--)
	{
		if (CheckboxPresets[i].Preset == CopyPreset)
		{
			//`CPOLOG(i @ "creating a copy of the preset:" @ CheckboxPresets[i].OptionName @ CheckboxPresets[i].bChecked);
			NewPresetStruct = CheckboxPresets[i];
			NewPresetStruct.Preset = CurrentPreset;
			CheckboxPresets.AddItem(NewPresetStruct);
		}
	}

	default.CheckboxPresets = CheckboxPresets;
	SaveConfig();

	UpdateOptionsList();
	ActivatePreset();
	UpdateUnitAppearance();
}

simulated private function OptionPresetCheckboxChanged(UICheckbox CheckBox)
{
	local UIMechaListItem_Button ListItem;
	local name PresetName;

	PresetName = CheckBox.GetParent(class'UIMechaListItem_Button').MCName;
	if (Presets.Find(PresetName) != INDEX_NONE)
	{
		bCanExitWithoutPopup = false;
		SavePresetCheckboxPositions();
		CurrentPreset = PresetName;
	
		ActivatePreset();
		UpdateUnitAppearance();

		// If currently selected preset is not the default one, lock the "Copy Preset" buttons so that the player can't accidentally ruin them.
		foreach Presets(PresetName)
		{
			ListItem = UIMechaListItem_Button(OptionsList.GetChildByName(PresetName));
			if (ListItem != none && ListItem.Button != none)
			{
				ListItem.Button.SetDisabled(CurrentPreset != 'PresetDefault');
			}
		}
	}
}

simulated function ActivatePreset()
{
	local name Preset;

	`CPOLOG(GetFuncName() @ `showvar(CurrentPreset));
	
	foreach Presets(Preset)
	{
		SetCheckbox(Preset, Preset == CurrentPreset);
	}
	ApplyPresetCheckboxPositions();
}

simulated function OptionsListItemClicked(UIList ContainerList, int ItemIndex)
{
	local UIMechaListItem ListItem;

	bCanExitWithoutPopup = false;

	// Exit early if the player clicked on the first two members in the list, or anywhere below the presets.
	if (ItemIndex < 2 || ItemIndex >= Presets.Length + 2) // +2 members above the first preset in the list
		return;
	
	ListItem = UIMechaListItem(OptionsList.GetItem(ItemIndex));
	if (ListItem != none)
	{
		OptionPresetCheckboxChanged(ListItem.Checkbox);
	}
}

// ================================================================================================================================================
// LOCALIZATION HELPERS

simulated private function string GetBodyPartFriendlyName(name OptionName, coerce string Cosmetic)
{
	local name					CosmeticTemplateName;
	local X2BodyPartTemplate	BodyPartTemplate;
	local string				PartType;

	if (class'Help'.static.IsCosmeticEmpty(Cosmetic))
		return class'UIPhotoboothBase'.default.m_strEmptyOption; // "none"

	if (OptionName == 'nmFlag')
		return GetFriendlyCountryName(Cosmetic);

	PartType = GetPartType(OptionName);
	CosmeticTemplateName = name(Cosmetic);
	if (PartType != "" && CosmeticTemplateName != '')
	{
		BodyPartTemplate = BodyPartMgr.FindUberTemplate(PartType, CosmeticTemplateName);
	}

	//if (BodyPartTemplate != none && BodyPartTemplate.DisplayName == "")
	//	`CPOLOG("No localized name for template:" @ BodyPartTemplate.DataName @ PartType @ OptionName);

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
	//case'nmLanguage': return "";
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

simulated private function string GetFriendlyCountryName(coerce name CountryTemplateName)
{
	local X2CountryTemplate	CountryTemplate;

	CountryTemplate = X2CountryTemplate(StratMgr.FindStrategyElementTemplate(CountryTemplateName));

	return CountryTemplate != none ? CountryTemplate.DisplayName : string(CountryTemplateName);
}

simulated private function string GetFriendlyGender(int iGender)
{
	local EGender EnumGender;

	EnumGender = EGender(iGender);

	switch (EnumGender)
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
	//case'iFacialHair': return class'UICustomize_Head'.default.m_strFacialHair;
	case'iSkinColor': return class'UICustomize_Head'.default.m_strSkinColor;
	case'iEyeColor': return class'UICustomize_Head'.default.m_strEyeColor;
	case'iAttitude': return class'UICustomize_Info'.default.m_strAttitude;
	//case'iArmorDeco': return class'UICustomize_Body'.default.m_strMainColor;
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
	//case'nmLanguage': return "Language";
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
	case'FirstName': return class'UICustomize_Info'.default.m_strFirstNameLabel;
	case'LastName': return class'UICustomize_Info'.default.m_strLastNameLabel;
	case'Nickname': return class'UICustomize_Info'.default.m_strNicknameLabel;
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
		if (CheckboxPreset.OptionName == UniformPiece &&
			CheckboxPreset.Preset == PresetName)
		{
			return CheckboxPreset.bChecked;
		}
	}
	return false;
}

static final function CopyAppearance_Static(out TAppearance NewAppearance, const TAppearance UniformAppearance, const name PresetName)
{
	local bool bGenderChange;

	if (ShouldCopyUniformPiece('iGender', PresetName))
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
		if (ShouldCopyUniformPiece('nmHead', PresetName)) {NewAppearance.nmHead = UniformAppearance.nmHead; NewAppearance.nmEye = UniformAppearance.nmEye; NewAppearance.nmTeeth = UniformAppearance.nmTeeth; NewAppearance.iRace = UniformAppearance.iRace;}
		//if (ShouldCopyUniformPiece('iRace', PresetName)) NewAppearance.iRace = UniformAppearance.iRace;
		if (ShouldCopyUniformPiece('nmHaircut', PresetName)) NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
		//if (ShouldCopyUniformPiece('iFacialHair', PresetName)) NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
		if (ShouldCopyUniformPiece('nmBeard', PresetName)) NewAppearance.nmBeard = UniformAppearance.nmBeard;
		//if (ShouldCopyUniformPiece('iVoice', PresetName)) NewAppearance.iVoice = UniformAppearance.iVoice;
		if (ShouldCopyUniformPiece('nmTorso', PresetName)) NewAppearance.nmTorso = UniformAppearance.nmTorso;
		if (ShouldCopyUniformPiece('nmArms', PresetName)) NewAppearance.nmArms = UniformAppearance.nmArms;
		if (ShouldCopyUniformPiece('nmLegs', PresetName)) NewAppearance.nmLegs = UniformAppearance.nmLegs;
		if (ShouldCopyUniformPiece('nmHelmet', PresetName)) NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
		if (ShouldCopyUniformPiece('nmFacePropLower', PresetName)) NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
		if (ShouldCopyUniformPiece('nmFacePropUpper', PresetName)) NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
		if (ShouldCopyUniformPiece('nmVoice', PresetName)) NewAppearance.nmVoice = UniformAppearance.nmVoice;
		if (ShouldCopyUniformPiece('nmScars', PresetName)) NewAppearance.nmScars = UniformAppearance.nmScars;
		//if (ShouldCopyUniformPiece('nmTorso_Underlay', PresetName)) NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
		//if (ShouldCopyUniformPiece('nmArms_Underlay', PresetName)) NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
		//if (ShouldCopyUniformPiece('nmLegs_Underlay', PresetName)) NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
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
	}
	if (ShouldCopyUniformPiece('iHairColor', PresetName)) NewAppearance.iHairColor = UniformAppearance.iHairColor;
	if (ShouldCopyUniformPiece('iSkinColor', PresetName)) NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
	if (ShouldCopyUniformPiece('iEyeColor', PresetName)) NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
	if (ShouldCopyUniformPiece('nmFlag', PresetName)) NewAppearance.nmFlag = UniformAppearance.nmFlag;
	if (ShouldCopyUniformPiece('iAttitude', PresetName)) NewAppearance.iAttitude = UniformAppearance.iAttitude;
	//if (ShouldCopyUniformPiece('iArmorDeco', PresetName)) NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
	if (ShouldCopyUniformPiece('iArmorTint', PresetName)) NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
	if (ShouldCopyUniformPiece('iArmorTintSecondary', PresetName)) NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
	if (ShouldCopyUniformPiece('iWeaponTint', PresetName)) NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
	if (ShouldCopyUniformPiece('iTattooTint', PresetName)) NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
	if (ShouldCopyUniformPiece('nmWeaponPattern', PresetName)) NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
	if (ShouldCopyUniformPiece('nmPatterns', PresetName)) NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
	//if (ShouldCopyUniformPiece('nmLanguage', PresetName)) NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
	if (ShouldCopyUniformPiece('nmTattoo_LeftArm', PresetName)) NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
	if (ShouldCopyUniformPiece('nmTattoo_RightArm', PresetName)) NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;
	//if (ShouldCopyUniformPiece('bGhostPawn', PresetName)) NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;
}

final function string GetGenderArmorTemplate()
{
	return ArmorTemplateName $ ArmoryUnit.kAppearance.iGender;
}


static final function SetInitialSoldierListSettings()
{
	local UICustomize_CPExtended CDO;

	if (!default.bInitComplete)
	{
		CDO = UICustomize_CPExtended(class'XComEngine'.static.GetClassDefaultObject(class'UICustomize_CPExtended'));

		CDO.bInitComplete = true;
		CDO.bShowCharPoolSoldiers = class'WOTCCharacterPoolExtended_Defaults'.default.bShowCharPoolSoldiers_DEFAULT;
		CDO.bShowUniformSoldiers = class'WOTCCharacterPoolExtended_Defaults'.default.bShowUniformSoldiers_DEFAULT;		
		CDO.bShowBarracksSoldiers = class'WOTCCharacterPoolExtended_Defaults'.default.bShowBarracksSoldiers_DEFAULT;
		CDO.bShowDeadSoldiers = class'WOTCCharacterPoolExtended_Defaults'.default.bShowDeadSoldiers_DEFAULT;
		CDO.bShowAllCosmeticOptions = class'WOTCCharacterPoolExtended_Defaults'.default.bShowAllCosmeticOptions_DEFAULT;
		CDO.Presets = class'WOTCCharacterPoolExtended_Defaults'.default.Presets_DEFAULT;
		CDO.CheckboxPresets = class'WOTCCharacterPoolExtended_Defaults'.default.CheckboxPresetsDefaults;
		CDO.SaveConfig();
	}
}

defaultproperties
{
	CurrentPreset = "PresetDefault"
	bCanExitWithoutPopup = true

	bShowCategoryHead = true
	bShowCategoryBody = true
	bShowCategoryTattoos = true
	bShowCategoryArmorPattern = true
	bShowCategoryWeaponPattern = true
	bShowCategoryPersonality = true
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

/*
simulated private function LoadPresetCheckboxPositions()
{
	local UIMechaListItem		ListItem;
	local int					Index;
	local int i;

	`CPOLOG(GetFuncName() @ "Options in the list:" @ OptionsList.ItemCount @ "Saved options:" @ CheckboxPresets.Length);

	if (Presets.Length > 0)
	{
		i = Presets.Length + 1;
	}
	for (i = i; i < OptionsList.ItemCount; i++) 
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none)
			continue;

		`CPOLOG(i @ "List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ "Checked:" @ ListItem.Checkbox.bChecked);

		for (Index = 0; Index < CheckboxPresets.Length; Index++)
		{
			if (CheckboxPresets[Index].OptionName == ListItem.MCName &&
				CheckboxPresets[Index].Preset == CurrentPreset)
			{
				ListItem.Checkbox.SetChecked(CheckboxPresets[Index].bChecked, false);
				`CPOLOG(i @ "Found non-default entry:" @ CheckboxPresets[Index].bChecked);
				break;
			}
		}
	}
	//SavePresetCheckboxPositions();
}*/

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

		UnitName = class'CharacterPoolManagerExtended'.static.GetUnitFullNameExtraData_UnitState_Static(CheckUnit);
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

		UnitName = class'CharacterPoolManagerExtended'.static.GetUnitFullNameExtraData_UnitState_Static(CheckUnit);
		SpawnedItem = Spawn(class'UIMechaListItem_Soldier', List.ItemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
		SpawnedItem.UpdateDataCheckbox(UnitName, "", false, SoldierCheckboxChanged, none);
		SpawnedItem.UnitState = CheckUnit;
	}
}*/