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
	local X2EquipmentTemplate			EqTemplate;
	local X2DataTemplate				DataTemplate;

	local XComGameStateHistory					History;	
	local XComGameState							TempGameState;
	local XComGameStateContext_ChangeContainer	TempContainer;
	local XComGameState_Unit					UnitState;

	UnitState = GetUnit();
	SelectedSlot = GetSelectedSlot();
	LocTag.StrValue0 = class'CHItemSlot'.static.SlotGetName(SelectedSlot);
	MC.FunctionString("setRightPanelTitle", `XEXPAND.ExpandString(m_strLockerTitle));
		
	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	History = `XCOMHISTORY;
	TempContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Fake Loadout");
	TempGameState = History.CreateNewGameState(true, TempContainer);
	
	foreach ItemMgr.IterateTemplates(DataTemplate)
	{
		EqTemplate = X2EquipmentTemplate(DataTemplate);
		if (EqTemplate == none || !UnitState.CanAddItemToInventory(EqTemplate, SelectedSlot, TempGameState))
			continue;

		Item = EqTemplate.CreateInstanceFromTemplate(TempGameState);
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
	//local UIArmory_LoadoutItem					LIstItem;

	`LOG("Attempting to equip item:" @ Item.ItemTemplate.DataName @ "into slot:" @ GetSelectedSlot(),, 'IRITEST');
	if (Item.ItemTemplate == none)
		return false;

	if (CustomizationManager.UpdatedUnitState == none)
		return false;

	`LOG("Initial checks done, proceeding",, 'IRITEST');

	//PrintTorsoOptions("Before anything is done");

	History = `XCOMHISTORY;
	TempContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Fake Loadout");
	TempGameState = History.CreateNewGameState(true, TempContainer);

	//CustomizationManager.UpdatedUnitState.ApplyInventoryLoadout(TempGameState); //TEST

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

	// Doesn't seem to work.
	//if (EquipSucceeded)
	//{
	//	LIstItem = UIArmory_LoadoutItem(LockerList.GetItem(1));
	//	LIstItem.InitLoadoutItem(NewItem, GetSelectedSlot(), true);
	//}

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

	//PrintTorsoOptions("Past item equipped" @ CustomizationManager.UpdatedUnitState.kAppearance.nmTorso);
	
	NewAppearance = CustomizationManager.UpdatedUnitState.kAppearance;
	XComUnitPawn(CustomizationManager.ActorPawn).SetAppearance(NewAppearance);

	CharPoolMgr.SaveCharacterPool();

	//PrintTorsoOptions("Past Refresh" @ CustomizationManager.UpdatedUnitState.kAppearance.nmTorso);

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

simulated function UpdateEquippedList()
{
	//local int i, numUtilityItems; // Issue #118, unneeded
	local UIArmory_LoadoutItem Item;
	//ocal array<XComGameState_Item> UtilityItems; // Issue #118, unneeded
	local XComGameState_Unit UpdatedUnit;
	local int prevIndex;
	local CHUIItemSlotEnumerator En; // Variable for Issue #118
	local X2ItemTemplate		ItemTemplate;


	prevIndex = EquippedList.SelectedIndex;
	UpdatedUnit = GetUnit();
	EquippedList.ClearItems();

	// Clear out tooltips from removed list items
	Movie.Pres.m_kTooltipMgr.RemoveTooltipsByPartialPath(string(EquippedList.MCPath));

	// Issue #171 Start
	// Realize Inventory so mods changing utility slots get updated faster
	UpdatedUnit.RealizeItemSlotsCount(CheckGameState);
	// Issue #171 End

	// Issue #118 Start
	// Here used to be a lot of code handling individual slots, this has been abstracted in CHItemSlot (and the Enumerator)
	//CreateEnumerator(XComGameState_Unit _UnitState, optional XComGameState _CheckGameState, optional array<CHSlotPriority> _SlotPriorities, optional bool _UseUnlockHints, optional array<EInventorySlot> _OverrideSlotsList)
	En = class'CHUIItemSlotEnumerator'.static.CreateEnumerator(UpdatedUnit, CheckGameState);
	while (En.HasNext())
	{
		En.Next();
		Item = UIArmory_LoadoutItem(EquippedList.CreateItem(class'UIArmory_LoadoutItem'));
		if (CannotEditSlotsList.Find(En.Slot) != INDEX_NONE)
			Item.InitLoadoutItem(En.ItemState, En.Slot, true, m_strCannotEdit);
		else if (En.IsLocked)
			Item.InitLoadoutItem(En.ItemState, En.Slot, true, En.LockedReason);
		else
			Item.InitLoadoutItem(En.ItemState, En.Slot, true);

		if (En.Slot == eInvSlot_Armor)
		{
			ItemTemplate = GetItemTemplateFromCosmeticTorso(UpdatedUnit.kAppearance.nmTorso);
			if (ItemTemplate != none)
			{
				SetItemImage(Item, ItemTemplate);
				Item.SetTitle(ItemTemplate.GetItemFriendlyName());
				Item.SetSubTitle(ItemTemplate.GetLocalizedCategory());
			}
		}
	}
	EquippedList.SetSelectedIndex(prevIndex < EquippedList.ItemCount ? prevIndex : 0);
	// Force item into view
	EquippedList.NavigatorSelectionChanged(EquippedList.SelectedIndex);
	// Issue #118 End
}

static final function X2ItemTemplate GetItemTemplateFromCosmeticTorso(const name nmTorso)
{
	local name						ArmorTemplateName;
	local X2BodyPartTemplate		ArmorPartTemplate;
	local X2BodyPartTemplateManager BodyPartMgr;
	local X2ItemTemplateManager		ItemMgr;

	BodyPartMgr = class'X2BodyPartTemplateManager'.static.GetBodyPartTemplateManager();
	ArmorPartTemplate = BodyPartMgr.FindUberTemplate("Torso", nmTorso);
	if (ArmorPartTemplate != none)
	{
		ArmorTemplateName = ArmorPartTemplate.ArmorTemplate;
		if (ArmorTemplateName != '')
		{
			ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
			return ItemMgr.FindItemTemplate(ArmorTemplateName);
		}
	}
	return none;
}



simulated function SetItemImage(UIArmory_LoadoutItem LoadoutItem, X2ItemTemplate ItemTemplate)
{
	local int i;
	local bool bUpdate;
	local array<string> NewImages;
	// Issue #171 variables
	local array<X2DownloadableContentInfo> DLCInfos;

	if(ItemTemplate.strImage == "")
	{
		LoadoutItem.MC.FunctionVoid("setImages");
		return;
	}

	NewImages.AddItem(ItemTemplate.strImage);

	// Start Issue #171
	DLCInfos = `ONLINEEVENTMGR.GetDLCInfos(false);
	for(i = 0; i < DLCInfos.Length; ++i)
	{
		// Single line for Issue #962 - pass on Item State.
		DLCInfos[i].OverrideItemImage_Improved(NewImages, LoadoutItem.EquipmentSlot, ItemTemplate, UIArmory(LoadoutItem.Screen).GetUnit(), none);
	}
	// End Issue #171

	bUpdate = false;
	for( i = 0; i < NewImages.Length; i++ )
	{
		if( LoadoutItem.Images.Length <= i || LoadoutItem.Images[i] != NewImages[i] )
		{
			bUpdate = true;
			break;
		}
	}

	//If no image at all is defined, mark it as empty 
	if( NewImages.length == 0 )
	{
		NewImages.AddItem("");
		bUpdate = true;
	}

	if(bUpdate)
	{
		LoadoutItem.Images = NewImages;
		
		LoadoutItem.MC.BeginFunctionOp("setImages");
		LoadoutItem.MC.QueueBoolean(false); // always first

		for( i = 0; i < LoadoutItem.Images.Length; i++ )
			LoadoutItem.MC.QueueString(LoadoutItem.Images[i]); 

		LoadoutItem.MC.EndOp();
	}
}