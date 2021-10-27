class UISL_CPExtended extends UIScreenListener;

// This UISL adds a few buttons to UICustomize_Menu screens.

var localized string strUniform;

`include(WOTCCharacterPoolExtended\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

event OnInit(UIScreen Screen)
{
	//local UIAvengerHUD AvengerHud;
	//local UIAvengerShortcutSubMenuItem MenuItem;

	if (UICustomize_Menu(Screen) != none)
	{	 
		// When screen is initialized, list has no items yet, and our changes to it don't work right.
		Screen.SetTimer(0.05f, false, nameof(AddButtons), self);
	}

	// Enter Character Pool from the Armory.
	//AvengerHud = UIAvengerHUD(Screen);
	//if (AvengerHud == none) return;

	//MenuItem.Id = 'IRI_Armory_EnterCharacterPool';
	//MenuItem.Message.Label = "Character Pool";
	//MenuItem.Message.Description = "Enter Character Pool";
	//MenuItem.Message.OnItemClicked = OnCharacterPoolButtonClicked;

	//AvengerHud.Shortcuts.AddSubMenu(eUIAvengerShortcutCat_Barracks, MenuItem);
}

event OnReceiveFocus(UIScreen Screen)
{
	OnInit(Screen);
}

simulated function AddButtons()
{
	local UICustomize_Menu	CustomizeScreen;;
	local UIMechaListItem	ListItem;
	local bool				bListItemAlreadyExists;
	local bool				bUnitIsUniform;
	local int i;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
	{
		//`CPOLOG("Stopping timer cuz of wrong screen");
		return;
	}

	//`CPOLOG("List has items:" @ CustomizeScreen.List.ItemCount);

	if (CustomizeScreen.List.ItemCount != 0)
	{
		for (i = CustomizeScreen.List.ItemCount - 1; i >= 0; i--)
		{
			ListItem = UIMechaListItem(CustomizeScreen.List.GetItem(i));
			//`CPOLOG(i @ ListItem.MCName);
			if (ListItem.MCName == 'CPExtended_ManageAppearance_Button')
			{
				//`CPOLOG("Item already exists, breaking");
				CustomizeScreen.ShowListItems();
				bListItemAlreadyExists = true;
				break;
			}
		}

		bUnitIsUniform = `CHARACTERPOOLMGRXTD.IsUnitUniform(CustomizeScreen.GetUnit());

		`CPOLOG(CustomizeScreen.GetUnit().GetFullName() @ "Is uniform:" @ bUnitIsUniform);

		if (!bListItemAlreadyExists)
		{	
			//`CPOLOG("Adding list items");
			ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
			ListItem.bAnimateOnInit = false;
			ListItem.InitListItem('CPExtended_ManageAppearance_Button');
			ListItem.UpdateDataDescription("Manage Appearance", OnManageAppearanceButtonClicked); // TODO: Localize

			if (bUnitIsUniform)
			{
				ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
				ListItem.bAnimateOnInit = false;
				ListItem.InitListItem('CPExtended_ConfigureUniform_Button');
				ListItem.UpdateDataDescription("Configure Uniform", OnConfigureUniformButtonClicked); // TODO: Localize
			}			

			if (!CustomizeScreen.bInArmory)
			{
				ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
				ListItem.bAnimateOnInit = false;
				ListItem.InitListItem();
				ListItem.UpdateDataDescription("Loadout", OnLoadoutButtonClicked);  // TODO: Localize

				ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
				ListItem.bAnimateOnInit = false;
				ListItem.InitListItem('ConvertUniformSoldier');

				if (bUnitIsUniform)
					ListItem.UpdateDataButton("Convert to Soldier", "Convert", OnSoldierButtonClicked); // TODO: Localize
				else
					ListItem.UpdateDataButton("Convert to Uniform", "Convert", OnUniformButtonClicked); // TODO: Localize
			}
			// Add validate appearance button if we're skipping appearance validation
			if (!`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_DEBUG) || 
				`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_REVIEW))
			{
				ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
				ListItem.bAnimateOnInit = false;
				ListItem.InitListItem();
				ListItem.UpdateDataButton("Validate Appearance", "Validate", OnValidateButtonClicked); // TODO: Localize
			}
		
			ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
			ListItem.bAnimateOnInit = false;
			ListItem.InitListItem();
			ListItem.UpdateDataDescription("Appearance Store", OnAppearanceStoreButtonClicked);
		
			//if (!CustomizeScreen.bInArmory)
			//{
			//	ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
			//	ListItem.bAnimateOnInit = false;
			//	ListItem.InitListItem();
			//	ListItem.UpdateDataDescription("Photobooth", OnPhotboothButtonClicked);
			//}

			CustomizeScreen.ShowListItems();
		}

		UpdateCustomizeMenuList(CustomizeScreen.List, bUnitIsUniform);
	}
	CustomizeScreen.SetTimer(0.25f, false, nameof(AddButtons), self);
}

simulated private function OnUseForAllClassesCheckboxChanged(UICheckbox CheckBox)
{
	local UICustomize_Menu CustomizeScreen;

	CustomizeScreen = UICustomize_Menu(CheckBox.Screen);

	`CHARACTERPOOLMGRXTD.SetIsUnitAnyClassUniform(CustomizeScreen.GetUnit(), CheckBox.bChecked);
	
	`CPOLOG("Got screen" @ CustomizeScreen != none @ CustomizeScreen.CustomizeManager.UpdatedUnitState.GetFullName());
}

simulated private function OnAppearanceStoreButtonClicked()
{
	local UICustomize_AppearanceStore	CustomizeScreen;
	local XComPresentationLayerBase		Pres;
	
	Pres = `PRESBASE;
	if (Pres == none || Pres.ScreenStack == none)
	{
		`CPOLOG("No pres:" @ Pres == none @ "or screenstack:" @  Pres.ScreenStack == none);
		return;
	}

	CustomizeScreen = Pres.Spawn(class'UICustomize_AppearanceStore', Pres);
	Pres.ScreenStack.Push(CustomizeScreen);
	CustomizeScreen.UpdateData();
}

simulated private function OnManageAppearanceButtonClicked()
{
	local UICustomize_CPExtended	CustomizeScreen;
	local XComPresentationLayerBase	Pres;
	
	Pres = `PRESBASE;
	if (Pres == none || Pres.ScreenStack == none)
	{
		`CPOLOG("No pres:" @ Pres == none @ "or screenstack:" @  Pres.ScreenStack == none);
		return;
	}

	CustomizeScreen = Pres.Spawn(class'UICustomize_CPExtended', Pres);
	Pres.ScreenStack.Push(CustomizeScreen);
	CustomizeScreen.UpdateData();
}

simulated private function OnConfigureUniformButtonClicked()
{
	local UICustomize_CPExtended_ConfigureUniform CustomizeScreen;
	local XComPresentationLayerBase	Pres;
	
	Pres = `PRESBASE;
	if (Pres == none || Pres.ScreenStack == none)
	{
		`CPOLOG("No pres:" @ Pres == none @ "or screenstack:" @  Pres.ScreenStack == none);
		return;
	}

	CustomizeScreen = Pres.Spawn(class'UICustomize_CPExtended_ConfigureUniform', Pres);
	Pres.ScreenStack.Push(CustomizeScreen);
	CustomizeScreen.UpdateData();
}


simulated private function OnSoldierButtonClicked(UIButton ButtonSource)
{
	local UICustomize_Menu		CustomizeScreen;
	local XComGameState_Unit	UnitState;
	local X2CharacterTemplate	CharacterTemplate;
	local XGCharacterGenerator	CharGen;
	local string				strFirstName;
	local string				strLastName;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	UnitState = CustomizeScreen.CustomizeManager.UpdatedUnitState;
	if (UnitState == none)
		return;

	CharacterTemplate = UnitState.GetMyTemplate();
	if (CharacterTemplate == none)
		return;

	CharGen = `XCOMGRI.Spawn(CharacterTemplate.CharacterGeneratorClass);	
	if (CharGen == none)
		return;
	
	// Give soldier an appropriate random name
	CharGen.GenerateName(UnitState.kAppearance.iGender, UnitState.kAppearance.nmFlag, strFirstName, strLastName, UnitState.kAppearance.iRace);

	// Firaxis noodle code makes it necessary
	if (strFirstName == "")
		strFirstName = CharGen.kSoldier.strFirstName;

	if (strLastName == "")
		strLastName = CharGen.kSoldier.strLastName;

	UnitState.SetCharacterName(strFirstName, strLastName, CharGen.kSoldier.strNickName);
	CustomizeScreen.CustomizeManager.CommitChanges();
	CustomizeScreen.UpdateData();

	`CHARACTERPOOLMGRXTD.SetIsUnitUniform(UnitState, false);
	
	UpdateCustomizeMenuList(CustomizeScreen.List, false);
}

// TODO: Add a popup with confirmation prompt here
simulated private function OnUniformButtonClicked(UIButton ButtonSource)
{
	local UICustomize_Menu		CustomizeScreen;
	local XComGameState_Unit	UnitState;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	UnitState = CustomizeScreen.CustomizeManager.UpdatedUnitState;

	UnitState.SetCharacterName(strUniform, GetFriendlyGender(UnitState.kAppearance.iGender), "");
	UnitState.kAppearance.iAttitude = 0; // Set by the Book attitude so the soldier stops squirming.
	UnitState.UpdatePersonalityTemplate();
	UnitState.bAllowedTypeSoldier = false;
	UnitState.bAllowedTypeVIP = false;
	UnitState.bAllowedTypeDarkVIP = false;
	CustomizeScreen.CustomizeManager.CommitChanges();
	CustomizeScreen.CustomizeManager.ReCreatePawnVisuals(CustomizeScreen.CustomizeManager.ActorPawn, true);
	CustomizeScreen.UpdateData();

	`CHARACTERPOOLMGRXTD.SetIsUnitUniform(UnitState, true);
	
	UpdateCustomizeMenuList(CustomizeScreen.List, true);
}

simulated private function UpdateCustomizeMenuList(UIList List, bool bUnitIsUniform)
{
	local UIMechaListItem ListItem;
	local int i;

	//`CPOLOG(`showvar(bUnitIsUniform));

	if (bUnitIsUniform)
	{
		for (i = List.ItemCount - 1; i >= 0; i--)
		{
			ListItem = UIMechaListItem(List.GetItem(i));
			if (ListItem.Desc.htmlText == class'UICustomize_Menu'.default.m_strAllowTypeSoldier)
			{
				ListItem.UpdateDataCheckbox("Use for all classes", "", `CHARACTERPOOLMGRXTD.IsUnitAnyClassUniform(UICustomize_Menu(List.Screen).GetUnit()), OnUseForAllClassesCheckboxChanged, none); // TODO: Unnoodle this.
			}

			if (ListItem.Desc.htmlText == class'UICustomize_Menu'.default.m_strAllowTypeVIP)
			{
				ListItem.Checkbox.SetChecked(false, false);
				ListItem.SetDisabled(true);
			}

			if (ListItem.Desc.htmlText == class'UICustomize_Menu'.default.m_strAllowTypeDarkVIP)
			{
				ListItem.Checkbox.SetChecked(false, false);
				ListItem.SetDisabled(true);
			}

			if (ListItem.MCName == 'ConvertUniformSoldier' && ListItem.Desc.htmlText != "Convert to Soldier")
			{
				ListItem.UpdateDataButton("Convert to Soldier", "Convert", OnSoldierButtonClicked); // TODO: Localize
			}
		}	
	}
	else
	{
		for (i = List.ItemCount - 1; i >= 0; i--)
		{
			ListItem = UIMechaListItem(List.GetItem(i));
			if (ListItem.MCName == 'ConvertUniformSoldier' && ListItem.Desc.htmlText != "Convert to Uniform")
			{
				ListItem.UpdateDataButton("Convert to Uniform", "Convert", OnUniformButtonClicked); // TODO: Localize
			}
		}
	}
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
		return "";
	}
}

simulated private function OnValidateButtonClicked(UIButton ButtonSource)
{
	local XComGameState_Unit			UnitState;
	local UICustomize_Menu				CustomizeScreen;
	local CharacterPoolManagerExtended	CharPool;
	local XComGameState_Item			ItemState;
	local TAppearance					FixAppearance;
	local int i;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	UnitState = CustomizeScreen.CustomizeManager.UpdatedUnitState;
	if (UnitState == none)
		return;

	`CPOLOG(UnitState.GetFullName());

	CharPool = CharacterPoolManagerExtended(`CHARACTERPOOLMGR);
	if (CharPool == none)
		return;

	// Validate current appearance
	CharPool.ValidateUnitAppearance(CustomizeScreen.CustomizeManager.UpdatedUnitState);	

	// Validate appearance store, remove entries that could not be validated
	for (i = UnitState.AppearanceStore.Length - 1; i >= 0; i--)
	{
		FixAppearance = UnitState.AppearanceStore[i].Appearance;
		if (CharPool.FixAppearanceOfInvalidAttributes(FixAppearance))
		{
			`CPOLOG(i @ "Successfully validated Appearance Store entry. It required no changes:" @ FixAppearance == UnitState.AppearanceStore[i].Appearance);
			UnitState.AppearanceStore[i].Appearance = FixAppearance;
		}
		else
		{
			`CPOLOG(i @ "Failed to validate Appearance Store entry, removing it");
			UnitState.AppearanceStore.Remove(i, 1);
		}
	}

	ItemState = CustomizeScreen.CustomizeManager.UpdatedUnitState.GetItemInSlot(eInvSlot_Armor);
	if (ItemState != none)
	{
		CustomizeScreen.CustomizeManager.UpdatedUnitState.StoreAppearance(, ItemState.GetMyTemplateName());
	}
	else CustomizeScreen.CustomizeManager.UpdatedUnitState.StoreAppearance();

	CustomizeScreen.CustomizeManager.CommitChanges();
	CustomizeScreen.CustomizeManager.ReCreatePawnVisuals(CustomizeScreen.CustomizeManager.ActorPawn, true);
	CustomizeScreen.UpdateData();
}


simulated private function OnLoadoutButtonClicked()
{
	local UICustomize_Menu				CustomizeScreen;
	local XComPresentationLayerBase		Pres;
	local UIArmory_Loadout_CPExtended	ArmoryScreen;
	local XComGameState_Unit			UnitState;

	//`CPOLOG("PRES:" @ `PRES != none @ "PRESBASE:" @ `PRESBASE != none @ "HQPRES:" @ `HQPRES != none);
	
	Pres = `PRESBASE;
	if (Pres == none || Pres.ScreenStack == none)
	{
		`CPOLOG("No pres:" @ Pres == none @ "or screenstack:" @  Pres.ScreenStack == none $ ", exiting");
		return;
	}
	CustomizeScreen = UICustomize_Menu(Pres.ScreenStack.GetCurrentScreen());
	if (CustomizeScreen == none)
	{
		`CPOLOG("No customize screen, exiting");
		return;
	}
	UnitState = CustomizeScreen.GetUnit(); 

	`CPOLOG("Opening loadout screen for Character Pool unit:" @ UnitState.GetFullName());

	ArmoryScreen = Pres.Spawn(class'UIArmory_Loadout_CPExtended', Pres);
	Pres.ScreenStack.Push(ArmoryScreen);
	ArmoryScreen.CustomizationManager = Pres.GetCustomizeManager();
	ArmoryScreen.InitArmory(UnitState.GetReference());
}


/*
simulated private function OnLoadout()
{
	local UICustomize_Menu				CustomizeScreen;
	local UIScreenStack					ScreenStack;
	local UIArmory_Loadout_CPExtended	ArmoryScreen;
	local XComShellPresentationLayer	Pres;
	local XComGameState_Unit			UnitState;

	ScreenStack = `SCREENSTACK;

	CustomizeScreen = UICustomize_Menu(ScreenStack.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	Pres = XComShellPresentationLayer(CustomizeScreen.Movie.Pres);
	UnitState = CustomizeScreen.GetUnit(); 

	`CPOLOG("Opening loadout screen for Character Pool unit:" @ UnitState.GetFullName());

	ArmoryScreen = UIArmory_Loadout_CPExtended(ScreenStack.Push(Pres.Spawn(class'UIArmory_Loadout_CPExtended', Pres), Pres.Get3DMovie()));
	ArmoryScreen.CustomizationManager = Pres.GetCustomizeManager();
	ArmoryScreen.InitArmory(UnitState.GetReference());

	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
}
*/
/*
simulated function AddNavHelpButtons()
{
	local UICustomize CustomizeScreen;

	CustomizeScreen = UICustomize(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none || CustomizeScreen.Class == class'UICustomize_CPExtended')
		return;

	if (CustomizeScreen.NavHelp.m_arrButtonClickDelegates.Find(OnImportFromCharacterPoolButtonClicked) == INDEX_NONE)
	{
		CustomizeScreen.NavHelp.AddRightHelp("CPE IMPORT",			
				class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RT_R2, 
				OnImportFromCharacterPoolButtonClicked,
				false,
				"Tooltip placeholder",
				class'UIUtilities'.const.ANCHOR_BOTTOM_CENTER);
	}
	CustomizeScreen.SetTimer(0.1f, false, nameof(AddNavHelpButtons), self);
}
*/
/*
simulated private function OnManageAppearanceButtonClicked()
{
	local UICustomize_CPExtended	CustomizeScreen;
	local XComHQPresentationLayer	HQPresLayer;
	
	HQPresLayer = `HQPRES;
	if (HQPresLayer == none || HQPresLayer.ScreenStack == none)
		return;

	CustomizeScreen = HQPresLayer.Spawn(class'UICustomize_CPExtended', HQPresLayer);
	HQPresLayer.ScreenStack.Push(CustomizeScreen);
	CustomizeScreen.UpdateData();
}*/

/*
simulated function AddManageAppearanceButton()
{
	local UICustomize_Menu	CustomizeScreen;;
	local UIMechaListItem	ListItem;
	local bool				bListItemAlreadyExists;
	local int i;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	for (i = CustomizeScreen.List.ItemCount - 1; i >= 0; i--)
	{
		ListItem = UIMechaListItem(CustomizeScreen.List.GetItem(i));
		if (string(ListItem.OnClickDelegate) == string(OnManageAppearanceButtonClicked))
		{
			ListItem.Show();
			bListItemAlreadyExists = true;
			break;
		}
	}
	if (!bListItemAlreadyExists)
	{	
		ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
		ListItem.bAnimateOnInit = false;
		ListItem.InitListItem();
		ListItem.UpdateDataDescription("Manage Appearance", OnManageAppearanceButtonClicked); // TODO: Localize

		// TODO: Maybe add "reskin armor" button here?
	}
	CustomizeScreen.SetTimer(0.1f, false, nameof(AddManageAppearanceButton), self);
}*/
/*
simulated function AddLoadoutButton()
{
	local UICustomize_Menu	CustomizeScreen;
	local bool				bListItemAlreadyExists;
	local UIMechaListItem	ListItem;
	local int i;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	for (i = 0; i < CustomizeScreen.List.ItemCount; i++)
	{
		ListItem = UIMechaListItem(CustomizeScreen.List.GetItem(i));
		if (string(ListItem.OnClickDelegate) ~= string(OnLoadoutButtonClicked))
		{
			bListItemAlreadyExists = true;
			CustomizeScreen.ShowListItems();
			break;
		}
	}
	if (!bListItemAlreadyExists)
	{
		ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
		ListItem.bAnimateOnInit = false;
		ListItem.InitListItem();
		ListItem.UpdateDataButton("Convert to a Uniform", "Convert", OnUniformButtonClicked); // TODO: Localize
		CustomizeScreen.ShowListItems();

		// Add validate appearance button if we're skipping appearance validation
		if (!`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_DEBUG) || 
			`XENGINE.bReviewFlagged && `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_REVIEW))
		{
			ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
			ListItem.bAnimateOnInit = false;
			ListItem.InitListItem();
			ListItem.UpdateDataButton("Validate Appearance", "Validate", OnValidateButtonClicked); // TODO: Localize
			CustomizeScreen.ShowListItems();
		}
		ListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
		ListItem.bAnimateOnInit = false;
		ListItem.InitListItem();
		ListItem.UpdateDataDescription(class'UIArmory_MainMenu'.default.m_strLoadout, OnLoadoutButtonClicked);
	}

	CustomizeScreen.SetTimer(0.1f, false, nameof(AddLoadoutButton), self);
}

simulated private function OnCharacterPoolButtonClicked(optional StateObjectReference Facility)
{
	local XComPresentationLayerBase	Pres;
	
	Pres = `PRESBASE;
	if (Pres == none || Pres.ScreenStack == none)
	{
		`CPOLOG("No pres:" @ Pres == none @ "or screenstack:" @  Pres.ScreenStack == none);
		return;
	}

	Pres.ScreenStack.Push(Pres.Spawn(class'UICharacterPool_CPExtended', Pres));
}

simulated private function OnPhotboothButtonClicked()
{
	local UICustomize_Menu			CustomizeScreen;
	local XComPresentationLayerBase	Pres;
	local XComGameState				NewGameState;
	local UIArmory_Photobooth		ArmoryScreen;
	
	Pres = `PRESBASE;
	if (Pres == none || Pres.ScreenStack == none)
	{
		`CPOLOG("No pres:" @ Pres == none @ "or screenstack:" @  Pres.ScreenStack == none);
		return;
	}

	CustomizeScreen = UICustomize_Menu(Pres.ScreenStack.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Trigger Event: View Photobooth");
	`XEVENTMGR.TriggerEvent('OnViewPhotobooth', , , NewGameState);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	if (Pres.ScreenStack.IsNotInStack(class'UIArmory_Photobooth_CPExtended'))
	{
		ArmoryScreen = UIArmory_Photobooth(Pres.ScreenStack.Push(Pres.Spawn(class'UIArmory_Photobooth_CPExtended', Pres)));
		ArmoryScreen.InitPropaganda(CustomizeScreen.GetUnit().GetReference());
	}
}
*/