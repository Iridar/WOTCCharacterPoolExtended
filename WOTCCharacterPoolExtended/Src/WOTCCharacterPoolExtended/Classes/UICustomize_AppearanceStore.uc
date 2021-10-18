class UICustomize_AppearanceStore extends UICustomize;

// This screen lists unit's AppearanceStore elements, allows to preview and delete them.

var private X2ItemTemplateManager	ItemMgr;
var private XComGameState_Unit		UnitState;
var private TAppearance				OriginalAppearance;
var private TAppearance				SelectedAppearance;
var private XComHumanPawn			ArmoryPawn;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	UnitState = CustomizeManager.UpdatedUnitState;
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	OriginalAppearance = ArmoryPawn.m_kAppearance;
	List.OnSelectionChanged = OnListItemSelected;

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

simulated function UpdateData()
{
	local AppearanceInfo	StoredAppearance;
	local X2ItemTemplate	ArmorTemplate;
	local EGender			Gender;
	local name				ArmorTemplateName;
	local string			DisplayName;
	local int i;

	super.UpdateData();
	if (UnitState == none)
		return;

	foreach UnitState.AppearanceStore(StoredAppearance)
	{
		Gender = EGender(int(Right(StoredAppearance.GenderArmorTemplate, 1)));
		ArmorTemplateName = name(Left(StoredAppearance.GenderArmorTemplate, Len(StoredAppearance.GenderArmorTemplate) - 1));
		ArmorTemplate = ItemMgr.FindItemTemplate(ArmorTemplateName);

		if (ArmorTemplate != none && ArmorTemplate.FriendlyName != "")
		{
			DisplayName = ArmorTemplate.FriendlyName;
		}
		else
		{
			DisplayName = string(ArmorTemplateName);
		}

		if (Gender == eGender_Male)
		{
			DisplayName @= "|" @ class'XComCharacterCustomization'.default.Gender_Male;
		}
		else if (Gender == eGender_Female)
		{
			DisplayName @= "|" @ class'XComCharacterCustomization'.default.Gender_Female;
		}

		if (class'Help'.static.IsAppearanceCurrent(StoredAppearance.Appearance, OriginalAppearance))
		{
			DisplayName @= "(Current)"; // TODO: Localize
			GetListItem(i++).UpdateDataDescription(DisplayName); // Deleting current appearance may not work as people expect it to.
		}
		else
		{
			GetListItem(i++).UpdateDataButton(DisplayName, "Delete", OnDeleteButtonClicked); // TODO: Localize
		}
	}
}

simulated private function OnListItemSelected(UIList ContainerList, int ItemIndex)
{
	local TAppearance StoredAppearance;

	if (UnitState == none || ItemIndex == INDEX_NONE)
		return;

	StoredAppearance = UnitState.AppearanceStore[ItemIndex].Appearance;
	SetPawnAppearance(StoredAppearance);
}

simulated private function SetPawnAppearance(TAppearance NewAppearance)
{
	//local bool bRefreshPawn;

	//bRefreshPawn = ArmoryPawn.m_kAppearance.iGender != NewAppearance.iGender;

	// Have to update appearance in the unit state as well, since it will be used to recreate the pawn.
	UnitState.SetTAppearance(NewAppearance);
	ArmoryPawn.SetAppearance(NewAppearance);
		
	// Have to recreate unit's pawn on a gender change. See more comments in 'UICustomize_CPExtended' for the same situation.
	// Addendum: Have to refresh pawn every time, not sure how to otherwise get rid of WAR Suit's exo attachments.
	//if (bRefreshPawn)
	//{
		CustomizeManager.ReCreatePawnVisuals(CustomizeManager.ActorPawn, true);
		SetTimer(0.1f, false, nameof(OnRefreshPawn), self);
	//}
}

// Can't use an Event Listener in CP, so using a timer (ugh)
simulated final function OnRefreshPawn()
{
	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn != none)
	{
		// Assign the actor pawn to the mouse guard so the pawn can be rotated by clicking and dragging
		UIMouseGuard_RotatePawn(`SCREENSTACK.GetFirstInstanceOf(class'UIMouseGuard_RotatePawn')).SetActorPawn(CustomizeManager.ActorPawn);
	}
	else
	{
		SetTimer(0.1f, false, nameof(OnRefreshPawn), self);
	}
}

simulated function CloseScreen()
{	
	SetPawnAppearance(OriginalAppearance);
	super.CloseScreen();
}

simulated private function OnDeleteButtonClicked(UIButton ButtonSource)
{
	local int Index;

	SetPawnAppearance(OriginalAppearance);
	Index = List.GetItemIndex(ButtonSource);
	UnitState.AppearanceStore.Remove(Index, 1);
	CustomizeManager.CommitChanges(); // This will submit a Game State with appearance store changes.
	List.ClearItems();
	UpdateData();
}
