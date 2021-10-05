class UISL_CPExtended extends UIScreenListener;

// This UISL adds a "LOADOUT" button to the character customization screen while in Character Pool.

var localized string strUniform;

event OnInit(UIScreen Screen)
{
	local UICustomize_Menu	CustomizeMenuScreen;
	local UICustomize		CustomizeScreen;

	//`LOG("Screen init:" @ Screen.Class.Name,, 'IRITEST');

	CustomizeScreen = UICustomize(Screen);
	if (CustomizeScreen == none || CustomizeScreen.Class == class'UICustomize_CPExtended')
		return;
		
	if (CustomizeScreen.bInArmory)
	{
		AddNavHelpButtons();
		return;
	}

	CustomizeMenuScreen = UICustomize_Menu(Screen);
	if (CustomizeMenuScreen != none)
	{
		AddLoadoutButton();
	}
	//`LOG(GetFuncName() @ "Adding button into list of members:" @ CustomizeScreen.List.ItemCount,, 'IRITEST');

}

event OnReceiveFocus(UIScreen Screen)
{
	//`LOG(GetFuncName() @ Screen.Class.Name,, 'IRITEST');

	OnInit(Screen);
}

simulated function AddNavHelpButtons()
{
	local UICustomize CustomizeScreen;

	CustomizeScreen = UICustomize(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none || CustomizeScreen.Class == class'UICustomize_CPExtended')
		return;

	if (CustomizeScreen.NavHelp.m_arrButtonClickDelegates.Find(OnImportUnitButtonClicked) == INDEX_NONE)
	{
		CustomizeScreen.NavHelp.AddRightHelp("CPE IMPORT",			
				class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RT_R2, 
				OnImportUnitButtonClicked,
				false,
				"Tooltip placeholder",
				class'UIUtilities'.const.ANCHOR_BOTTOM_CENTER);
	}
	CustomizeScreen.SetTimer(0.1f, false, nameof(AddNavHelpButtons), self);
}

simulated private function OnImportUnitButtonClicked()
{
	local UICustomize_CPExtended	CustomizeScreen;
	local XComHQPresentationLayer	HQPresLayer;
	
	HQPresLayer = `HQPRES;
	if (HQPresLayer == none || HQPresLayer.ScreenStack == none)
		return;

	CustomizeScreen = HQPresLayer.Spawn(class'UICustomize_CPExtended', HQPresLayer);
	HQPresLayer.ScreenStack.Push(CustomizeScreen);
	CustomizeScreen.UpdateData();
}

simulated function AddLoadoutButton()
{
	local UICustomize_Menu	CustomizeScreen;
	local bool				bItemAlreadyExists;
	local UIMechaListItem	NewListItem;
	local int i;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	for (i = 0; i < CustomizeScreen.List.ItemCount; i++)
	{
		NewListItem = UIMechaListItem(CustomizeScreen.List.GetItem(i));
		//`LOG(i @ string(NewListItem.OnClickDelegate),, 'IRITEST');
		if (string(NewListItem.OnClickDelegate) ~= string(OnLoadout))
		{
			//`LOG(GetFuncName() @ "item already exists, exiting",, 'IRITEST');
			bItemAlreadyExists = true;
			CustomizeScreen.ShowListItems();
			break;
		}
	}
	if (!bItemAlreadyExists)
	{
		NewListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
		NewListItem.bAnimateOnInit = false;
		NewListItem.InitListItem();
		NewListItem.UpdateDataButton("Convert to a Uniform", "Convert", OnUniformButtonClicked);
		CustomizeScreen.ShowListItems();

		NewListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
		NewListItem.bAnimateOnInit = false;
		NewListItem.InitListItem();
		NewListItem.UpdateDataDescription(class'UIArmory_MainMenu'.default.m_strLoadout, OnLoadout);
	}

	CustomizeScreen.SetTimer(0.1f, false, nameof(AddLoadoutButton), self);
}

simulated private function OnUniformButtonClicked(UIButton ButtonSource)
{
	local UICustomize_Menu CustomizeScreen;

	CustomizeScreen = UICustomize_Menu(`SCREENSTACK.GetCurrentScreen());
	if (CustomizeScreen == none)
		return;

	CustomizeScreen.CustomizeManager.UpdatedUnitState.SetCharacterName(strUniform, "", "");
	CustomizeScreen.CustomizeManager.UpdatedUnitState.kAppearance.iAttitude = 0; // Set by the Book attitude so the soldier stops squirming.
	CustomizeScreen.CustomizeManager.UpdatedUnitState.UpdatePersonalityTemplate();
	CustomizeScreen.CustomizeManager.CommitChanges();
	CustomizeScreen.CustomizeManager.SubmitUnitCustomizationChanges();
	CustomizeScreen.CustomizeManager.ReCreatePawnVisuals(CustomizeScreen.CustomizeManager.ActorPawn, true);
	CustomizeScreen.UpdateData();
}

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

	`LOG("Opening loadout screen for unit:" @ UnitState.GetFullName(),, 'IRITEST');

	ArmoryScreen = UIArmory_Loadout_CPExtended(ScreenStack.Push(Pres.Spawn(class'UIArmory_Loadout_CPExtended', Pres), Pres.Get3DMovie()));
	ArmoryScreen.CustomizationManager = Pres.GetCustomizeManager();
	//ArmoryScreen.CannotEditSlotsList = CannotEditSlots;
	ArmoryScreen.InitArmory(UnitState.GetReference());

	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
}
