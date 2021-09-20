class UIArmory_Loadout_CPExtended extends UIArmory_Loadout;

var XComCharacterCustomization	CustomizationManager;
var CharacterPoolManager		CharPoolMgr;

simulated function InitArmory(StateObjectReference UnitRef, optional name DispEvent, optional name SoldSpawnEvent, optional name NavBackEvent, optional name HideEvent, optional name RemoveEvent, optional bool bInstant = false, optional XComGameState InitCheckGameState)
{
	super.InitArmory(UnitRef, DispEvent, SoldSpawnEvent, NavBackEvent, HideEvent, RemoveEvent, bInstant, InitCheckGameState);

	CharPoolMgr = CharacterPoolManager(`XENGINE.GetCharacterPoolManager());
}

simulated function XComGameState_Unit GetUnit()
{
	if (CustomizationManager.UpdatedUnitState != none)
		return CustomizationManager.UpdatedUnitState;
	else
		return CustomizationManager.Unit;
}

simulated function UpdateLockerList()
{
	local XComGameState_Item	Item;
	local EInventorySlot		SelectedSlot;
	local array<TUILockerItem>	LockerItems;
	local TUILockerItem			LockerItem;

	local X2ItemTemplateManager			ItemMgr;
	local array<X2EquipmentTemplate>	ArmorTemplates;
	local X2EquipmentTemplate			ArmorTemplate;

	local XComGameStateHistory					History;	
	local XComGameState							TempGameState;
	local XComGameStateContext_ChangeContainer	TempContainer;

	SelectedSlot = GetSelectedSlot();
	LocTag.StrValue0 = class'CHItemSlot'.static.SlotGetName(SelectedSlot);
	MC.FunctionString("setRightPanelTitle", `XEXPAND.ExpandString(m_strLockerTitle));
		
	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	ArmorTemplates = ItemMgr.GetAllArmorTemplates();

	History = `XCOMHISTORY;
	TempContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Fake Loadout");
	TempGameState = History.CreateNewGameState(true, TempContainer);
	
	foreach ArmorTemplates(ArmorTemplate)
	{
		Item = ArmorTemplate.CreateInstanceFromTemplate(TempGameState);
		if (ShowInLockerList(Item, SelectedSlot))
		{
			LockerItem.Item = Item;
			LockerItem.DisabledReason = GetDisabledReason(Item, SelectedSlot);
			LockerItem.CanBeEquipped = LockerItem.DisabledReason == "";
			LockerItems.AddItem(LockerItem);
		}
	}

	History.AddGameStateToHistory(TempGameState);

	LockerList.ClearItems();

	LockerItems.Sort(SortLockerListByUpgrades);
	LockerItems.Sort(SortLockerListByTier);
	LockerItems.Sort(SortLockerListByEquip);

	foreach LockerItems(LockerItem)
	{
		UIArmory_LoadoutItem(LockerList.CreateItem(class'UIArmory_LoadoutItem')).InitLoadoutItem(LockerItem.Item, SelectedSlot, false, LockerItem.DisabledReason);
	}
	// If we have an invalid SelectedIndex, just try and select the first thing that we can.
	// Otherwise let's make sure the Navigator is selecting the right thing.
	if(LockerList.SelectedIndex < 0 || LockerList.SelectedIndex >= LockerList.ItemCount)
		LockerList.Navigator.SelectFirstAvailable();
	else
	{
		LockerList.Navigator.SetSelected(LockerList.GetSelectedItem());
	}
	OnSelectionChanged(ActiveList, ActiveList.SelectedIndex);

	History.ObliterateGameStatesFromHistory(1);
}

simulated function bool EquipItem(UIArmory_LoadoutItem Item)
{
	local XComGameState_Item	NewItem;
	local bool					EquipSucceeded;
	local X2WeaponTemplate		WeaponTemplate;

	local XComGameStateHistory					History;	
	local XComGameState							TempGameState;
	local XComGameStateContext_ChangeContainer	TempContainer;

	local XComUnitPawn							UnitPawn;
	local UIPawnMgr								PawnMgr;
	local XComPresentationLayerBase				PresBase;
	local TAppearance							NewAppearance;


	`LOG("Attempting to equip item:" @ Item.ItemTemplate.DataName @ "into slot:" @ GetSelectedSlot(),, 'IRITEST');
	if (Item.ItemTemplate == none)
		return false;

	if (CustomizationManager.UpdatedUnitState == none)
		return false;

	`LOG("Initial checks done, proceeding",, 'IRITEST');

	PrintTorsoOptions("Before anything is done");

	History = `XCOMHISTORY;
	TempContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Fake Loadout");
	TempGameState = History.CreateNewGameState(true, TempContainer);

	CustomizationManager.UpdatedUnitState.ApplyInventoryLoadout(TempGameState);
	NewItem = CustomizationManager.UpdatedUnitState.GetItemInSlot(GetSelectedSlot(), TempGameState);
	if (NewItem != none)
	{
		`LOG("Unit already had item in this slot:" @ NewItem.GetMyTemplateName(),, 'IRITEST');
		if (!CustomizationManager.UpdatedUnitState.RemoveItemFromInventory(NewItem, TempGameState))
		{
			History.CleanupPendingGameState(TempGameState);
			return false;
		}
		`LOG("Unequipped successfully",, 'IRITEST');
	}
	`LOG("Unit's primary weapon:" @ CustomizationManager.UpdatedUnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, TempGameState).GetMyTemplateName(),, 'IRITEST');

	NewItem = Item.ItemTemplate.CreateInstanceFromTemplate(TempGameState);

	`LOG("Torso archetype:" @ CustomizationManager.UpdatedUnitState.kAppearance.nmTorso,, 'IRITEST');
	
	if (CustomizationManager.UpdatedUnitState.AddItemToInventory(NewItem, GetSelectedSlot(), TempGameState))
	{
		EquipSucceeded = true; 

		`LOG("Item equipped. New torso archetype:" @ CustomizationManager.UpdatedUnitState.kAppearance.nmTorso,, 'IRITEST');

		WeaponTemplate = X2WeaponTemplate(Item.ItemTemplate);
		if (WeaponTemplate != none && WeaponTemplate.bUseArmorAppearance)
		{
			NewItem.WeaponAppearance.iWeaponTint = CustomizationManager.UpdatedUnitState.kAppearance.iArmorTint;
		}
		else
		{
			NewItem.WeaponAppearance.iWeaponTint = CustomizationManager.UpdatedUnitState.kAppearance.iWeaponTint;
		}
		NewItem.WeaponAppearance.nmWeaponPattern = CustomizationManager.UpdatedUnitState.kAppearance.nmWeaponPattern;

		if (X2EquipmentTemplate(Item.ItemTemplate) != none && X2EquipmentTemplate(Item.ItemTemplate).EquipSound != "")
		{
			`XSTRATEGYSOUNDMGR.PlaySoundEvent(X2EquipmentTemplate(Item.ItemTemplate).EquipSound);
		}
	}

	History.AddGameStateToHistory(TempGameState);
	
	UnitPawn = XComUnitPawn(CustomizationManager.ActorPawn);

	if (UnitPawn == none)
		`LOG("Error, no Unit Pawn",, 'IRITEST');

	PresBase = XComPresentationLayerBase(CustomizationManager.Outer);
	if (PresBase == none)
		`LOG("Error, no PresBase",, 'IRITEST');

	PawnMgr = PresBase.GetUIPawnMgr();
	if (PawnMgr == none)
		`LOG("Error, no PawnMgr",, 'IRITEST');

	UnitPawn.CreateVisualInventoryAttachments(PawnMgr, CustomizationManager.UpdatedUnitState);
	`LOG("Creating visual attachments",, 'IRITEST');
	
	History.ObliterateGameStatesFromHistory(1);	

	CustomizationManager.UpdatedUnitState.EmptyInventoryItems();

	PrintTorsoOptions("Past item equipped" @ CustomizationManager.UpdatedUnitState.kAppearance.nmTorso);
	
	NewAppearance = CustomizationManager.UpdatedUnitState.kAppearance;
	XComUnitPawn(CustomizationManager.ActorPawn).SetAppearance(NewAppearance);

	CharPoolMgr.SaveCharacterPool();

	PrintTorsoOptions("Past Refresh" @ CustomizationManager.UpdatedUnitState.kAppearance.nmTorso);

	return EquipSucceeded;
}

simulated function PrintTorsoOptions(string LogString)
{
	local array<string> Datas;
	local string Data;
	local int i;

	`LOG(LogString);
	Datas = CustomizationManager.GetCategoryList(eUICustomizeCat_Torso);
	foreach Datas(Data, i)
	{
		`LOG(i @ "Torso option:" @ Data,, 'IRITEST');
	}
	`LOG("---------------------------",, 'IRITEST');
}


simulated function bool ShowInLockerList(XComGameState_Item Item, EInventorySlot SelectedSlot)
{
	local X2ItemTemplate ItemTemplate;

	ItemTemplate = Item.GetMyTemplate();
	
	return class'CHItemSlot'.static.SlotShowItemInLockerList(SelectedSlot, GetUnit(), Item, ItemTemplate, CheckGameState);
}

simulated function UpdateData(optional bool bRefreshPawn)
{
	UpdateLockerList();
	UpdateEquippedList();
	Header.PopulateData(GetUnit());
}