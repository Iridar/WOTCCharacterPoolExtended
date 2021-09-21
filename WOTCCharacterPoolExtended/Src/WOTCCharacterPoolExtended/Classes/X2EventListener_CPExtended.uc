class X2EventListener_CPExtended extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_ListenerTemplate());

	return Templates;
}

static function CHEventListenerTemplate Create_ListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_XYM_X2EventListener_CPExtended');

	// Units shouldn't be able to swap armor mid-mission, but you never know
	Template.RegisterInTactical = true; 
	Template.RegisterInStrategy = true;

	// Needed so that soldier generated at the campaign start properly get their custom Kevlar appearance from CP 
	// even if the CP unit didn't have Kevlar equipped when CP was saved.
	Template.RegisterInCampaignStart = true; 

	Template.AddCHEvent('ItemAddedToSlot', OnItemAddedToSlot, ELD_Immediate, 50);

	return Template;
}

static function EventListenerReturn OnItemAddedToSlot(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Item	ItemState;
	local XComGameState_Unit	UnitState;
	local XComGameState_Unit	CPUnitState;
	local CharacterPoolManager	CharacterPool;
	local TAppearance			CPAppearance;

	ItemState = XComGameState_Item(EventData);
	if (ItemState == none || X2ArmorTemplate(ItemState.GetMyTemplate()) == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	if (UnitState == none)
		return ELR_NoInterrupt;

	`LOG(ItemState.GetMyTemplateName() @ "equipped on:" @ UnitState.GetFullName(),, 'IRITEST');

	if (UnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ItemState.GetMyTemplateName()))
	{
		`LOG("Unit already has stored appearance for this armor, exiting",, 'IRITEST');
		return ELR_NoInterrupt;
	}
	
	CharacterPool = `CHARACTERPOOLMGR;
	CPUnitState = CharacterPool.GetCharacter(UnitState.GetFullName());
	if (CPUnitState == none)
	{
		`LOG("Didn't find CP unit for this unit",, 'IRITEST');
		return ELR_NoInterrupt;
	}

	//for (i = 0; i < CPUnitState.AppearanceStore.Length; i++)
	//{
	//	`LOG("Stored appearance:" @ CPUnitState.AppearanceStore[i].GenderArmorTemplate,, 'IRITEST');
	//}
		
	if (CPUnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ItemState.GetMyTemplateName()))
	{
		`LOG("Restoring CP appearance",, 'IRITEST');
		CPUnitState.GetStoredAppearance(CPAppearance, UnitState.kAppearance.iGender, ItemState.GetMyTemplateName());
		UnitState.SetTAppearance(CPAppearance);
		UnitState.StoreAppearance(UnitState.kAppearance.iGender, ItemState.GetMyTemplateName());
	}
	else `LOG("CP unit has no stored appearance for this armor",, 'IRITEST');

	return ELR_NoInterrupt;
}
