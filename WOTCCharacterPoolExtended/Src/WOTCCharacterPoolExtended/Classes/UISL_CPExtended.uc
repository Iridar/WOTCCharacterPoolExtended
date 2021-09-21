class UISL_CPExtended extends UIScreenListener;

// This UISL adds a "LOADOUT" button to the character customization screen while in Character Pool.

event OnInit(UIScreen Screen)
{
	local UICustomize_Menu CustomizeScreen;

	//`LOG("Screen init:" @ Screen.Class.Name,, 'IRITEST');

	CustomizeScreen = UICustomize_Menu(Screen);
	if (CustomizeScreen == none || CustomizeScreen.bInArmory)
		return;

	//`LOG(GetFuncName() @ "Adding button into list of members:" @ CustomizeScreen.List.ItemCount,, 'IRITEST');

	AddMenuItem();
}

event OnReceiveFocus(UIScreen Screen)
{
	//`LOG(GetFuncName() @ Screen.Class.Name,, 'IRITEST');

	OnInit(Screen);
}

simulated function AddMenuItem()
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
		NewListItem.UpdateDataDescription(class'UIArmory_MainMenu'.default.m_strLoadout, OnLoadout);
		CustomizeScreen.ShowListItems();
	}

	CustomizeScreen.SetTimer(0.1f, false, nameof(AddMenuItem), self);
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
