class UICustomize_Menu_CPExtended extends UICustomize_Menu;

simulated function UpdateData()
{
	local int i;
	local int currentSel;
	local bool bBasicSoldierClass;
	currentSel = List.SelectedIndex;

	super(UICustomize).UpdateData();

	// Hide all existing options since the number of options can change if player switches genders
	HideListItems();

	CustomizeManager.UpdateBodyPartFilterForNewUnit(CustomizeManager.Unit);

	// INFO
	//-----------------------------------------------------------------------------------------
	GetListItem(i++).UpdateDataDescription(CustomizeManager.CheckForAttentionIcon(eUICustomizeCat_FirstName)$ m_strEditInfo, OnCustomizeInfo);

	// HEAD
	//-----------------------------------------------------------------------------------------
	GetListItem(i++).UpdateDataDescription(CustomizeManager.CheckForAttentionIcon(eUICustomizeCat_NickName)$ m_strEditHead, OnCustomizeHead);

	// BODY
	//-----------------------------------------------------------------------------------------
	GetListItem(i++).UpdateDataDescription(CustomizeManager.CheckForAttentionIcon(eUICustomizeCat_NickName)$ m_strEditBody, OnCustomizeBody);

	// WEAPON
	//-----------------------------------------------------------------------------------------
	GetListItem(i++).UpdateDataDescription(CustomizeManager.CheckForAttentionIcon(eUICustomizeCat_NickName)$ m_strEditWeapon, OnCustomizeWeapon);

	//  CHARACTER POOL OPTIONS
	//-----------------------------------------------------------------------------------------
	//If in the armory, allow exporting character to the pool
	if (bInArmory) 
	{
		GetListItem(i++).UpdateDataDescription(m_strExportCharacter, OnExportSoldier);
	}
	else //Otherwise, allow customizing their potential appearances
	{
		if(!bInMP)
		{
			if (Unit.IsSoldier())
			{
				GetListItem(i++).UpdateDataValue(m_strCustomizeClass,
					CustomizeManager.FormatCategoryDisplay(eUICustomizeCat_Class, eUIState_Normal, FontSize), CustomizeClass, true);

				bBasicSoldierClass = (Unit.GetSoldierClassTemplate().RequiredCharacterClass == '');
				GetListItem(i++, !bBasicSoldierClass, m_strNoClassVariants).UpdateDataValue(m_strViewClass,
					CustomizeManager.FormatCategoryDisplay(eUICustomizeCat_ViewClass, bBasicSoldierClass ? eUIState_Normal : eUIState_Disabled, FontSize), CustomizeViewClass, true);
			}
			
			GetListItem(i++).UpdateDataCheckbox(m_strAllowTypeSoldier, m_strAllowed, CustomizeManager.UpdatedUnitState.bAllowedTypeSoldier, OnCheckbox_Type_Soldier);
			GetListItem(i++).UpdateDataCheckbox(m_strAllowTypeVIP, m_strAllowed, CustomizeManager.UpdatedUnitState.bAllowedTypeVIP, OnCheckbox_Type_VIP);
			GetListItem(i++).UpdateDataCheckbox(m_strAllowTypeDarkVIP, m_strAllowed, CustomizeManager.UpdatedUnitState.bAllowedTypeDarkVIP, OnCheckbox_Type_DarkVIP);

			// ADDED
			GetListItem(i++).UpdateDataDescription(class'UIArmory_MainMenu'.default.m_strLoadout, OnLoadout);
			// END OF ADDED

			GetListItem(i).UpdateDataDescription(m_strTimeAdded @ CustomizeManager.UpdatedUnitState.PoolTimestamp, None);
			GetListItem(i++).SetDisabled(true);
		}
	}
	
	List.OnItemClicked = OnListOptionClicked;

	Navigator.SetSelected(List);
	
	if (currentSel > -1 && currentSel < List.ItemCount)
	{
		//Don't use GetItem(..), because it overwrites enable.disable option indiscriminately. 
		List.Navigator.SetSelected(List.GetItem(currentSel));
	}
	else
	{
		//Don't use GetItem(..), because it overwrites enable.disable option indiscriminately. 
		List.Navigator.SelectFirstAvailable();
	}
	//-----------------------------------------------------------------------------------------
}

simulated function OnLoadout()
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

	`LOG("Opening loadout screen for unit:" @ UnitState.GetFullName(),, 'IRITEST');

	ArmoryScreen = UIArmory_Loadout_CPExtended(ScreenStack.Push(Pres.Spawn(class'UIArmory_Loadout_CPExtended', Pres), Pres.Get3DMovie()));
	ArmoryScreen.CustomizationManager = Pres.GetCustomizeManager();
	//ArmoryScreen.CannotEditSlotsList = CannotEditSlots;
	ArmoryScreen.InitArmory(UnitState.GetReference());

	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
}
