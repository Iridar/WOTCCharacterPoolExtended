class UISL_CPExtended extends UIScreenListener;

/*
event OnInit(UIScreen Screen)
{
	local UICustomize_Menu				CustomizeScreen;
	local UICustomize_Menu_CPExtended	NewCustomizeScreen;
	local XComPresentationlayerBase		Pres;

	CustomizeScreen = UICustomize_Menu(Screen);
	if (CustomizeScreen != none && !CustomizeScreen.bInArmory && CustomizeScreen.Class != class'UICustomize_Menu_CPExtended')
	{
		Pres = CustomizeScreen.Movie.Pres;
		NewCustomizeScreen = Pres.Spawn(class'UICustomize_Menu_CPExtended', Pres);

		NewCustomizeScreen.CustomizeManager = CustomizeScreen.CustomizeManager;
		NewCustomizeScreen.UnitRef = CustomizeScreen.UnitRef;
		NewCustomizeScreen.Unit = CustomizeScreen.Unit;
		NewCustomizeScreen.bInArmory = CustomizeScreen.bInArmory;
		NewCustomizeScreen.bInMP = CustomizeScreen.bInMP;
		NewCustomizeScreen.IdleAnimName = CustomizeScreen.IdleAnimName;
		NewCustomizeScreen.bUsePersonalityAnim = CustomizeScreen.bUsePersonalityAnim;
		NewCustomizeScreen.NavHelp = CustomizeScreen.NavHelp;
		NewCustomizeScreen.ListBG = CustomizeScreen.ListBG;
		NewCustomizeScreen.List = CustomizeScreen.List;
		NewCustomizeScreen.Header = CustomizeScreen.Header;
		NewCustomizeScreen.CameraTag = CustomizeScreen.CameraTag;
		NewCustomizeScreen.DisplayTag = CustomizeScreen.DisplayTag;
		NewCustomizeScreen.FontSize = CustomizeScreen.FontSize;
		NewCustomizeScreen.bDisableVeteranOptions = CustomizeScreen.bDisableVeteranOptions;
		NewCustomizeScreen.bIsSuperSoldier = CustomizeScreen.bIsSuperSoldier;
		NewCustomizeScreen.bIsXPACSoldier = CustomizeScreen.bIsXPACSoldier;

		Pres.ScreenStack.Pop(CustomizeScreen);
		Pres.ScreenStack.Push(NewCustomizeScreen, Pres.Get3DMovie());
	}
}
*/
event OnInit(UIScreen Screen)
{
	local UICustomize_Menu CustomizeScreen;

	`LOG("Screen init:" @ Screen.Class.Name,, 'IRITEST');

	CustomizeScreen = UICustomize_Menu(Screen);
	if (CustomizeScreen == none || CustomizeScreen.bInArmory)
		return;

	`LOG(GetFuncName() @ "Adding button into list of members:" @ CustomizeScreen.List.ItemCount,, 'IRITEST');

	AddMenuItem();
}

event OnReceiveFocus(UIScreen Screen)
{
	`LOG(GetFuncName() @ Screen.Class.Name,, 'IRITEST');

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
		if (string(UIMechaListItem(CustomizeScreen.List.GetItem(i)).OnClickDelegate) ~= string(OnLoadout))
		{
			`LOG(GetFuncName() @ "item already exists, exiting",, 'IRITEST');
			bItemAlreadyExists = true;
			break;
		}
	}
	if (!bItemAlreadyExists)
	{
		NewListItem = CustomizeScreen.Spawn(class'UIMechaListItem', CustomizeScreen.List.ItemContainer);
		NewListItem.bAnimateOnInit = false;
		NewListItem.InitListItem();
		NewListItem.UpdateDataDescription(class'UIArmory_MainMenu'.default.m_strLoadout, OnLoadout);
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
