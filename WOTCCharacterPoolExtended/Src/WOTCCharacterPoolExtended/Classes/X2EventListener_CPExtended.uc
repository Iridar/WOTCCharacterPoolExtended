class X2EventListener_CPExtended extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	//Templates.AddItem(Create_ListenerTemplate_Strategy());
	Templates.AddItem(Create_ListenerTemplate_StrategyAndTactical());
	Templates.AddItem(Create_ListenerTemplate_CampaignStart());
	
	return Templates;
}

// Events still don't trigger in CP...
/*
static function CHEventListenerTemplate Create_ListenerTemplate_Strategy()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_XYM_X2EventListener_CPExtended_Strategy');

	Template.RegisterInStrategy = true;

	Template.AddCHEvent('OverrideCharCustomizationScale', OnOverrideCharCustomizationScale, ELD_Immediate, 50); 
	//'PostInventoryLoadoutApplied' doesn't seem to trigger for CP units.

	return Template;
}

// See comments in UICustomize_CPExtended::UpdateUnitAppearance() as to why this is necessary
static function EventListenerReturn OnOverrideCharCustomizationScale(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local UIScreenStack ScreenStack;
	local UICustomize_CPExtended		CPExtendedScreen;
	//local UICustomize_AppearanceStore	AppearanceStoreScreen;

	ScreenStack = `SCREENSTACK;
	if (ScreenStack != none)
	{
		CPExtendedScreen = UICustomize_CPExtended(ScreenStack.GetFirstInstanceOf(class'UICustomize_CPExtended'));
		if (CPExtendedScreen != none)
		{
			CPExtendedScreen.OnRefreshPawn();
		}
		//else 
		//{
		//	AppearanceStoreScreen = UICustomize_AppearanceStore(ScreenStack.GetFirstInstanceOf(class'UICustomize_AppearanceStore'));
		//	if (AppearanceStoreScreen != none)
		//	{
		//		AppearanceStoreScreen.OnRefreshPawn();
		//	}
		//}
	}

	return ELR_NoInterrupt;
}*/

// ItemAddedToSlot listeners are responsible for two things:
// 1. CP Appearance Store support.
// 2. CP Uniforms support.
// If a unit equips an armor they don't have stored appearance for, the mod will check if this unit exists in the character pool, and attempt to load CP unit's stored appearance for that armor.
// If that fails, the mod will look for an appropriate uniform for this soldier.

static function CHEventListenerTemplate Create_ListenerTemplate_StrategyAndTactical()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_XYM_X2EventListener_CPExtended_StrategyAndTactical');

	Template.RegisterInTactical = true; // Units shouldn't be able to swap armor mid-mission, but you never know
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('ItemAddedToSlot', OnItemAddedToSlot, ELD_Immediate, 50);

	return Template;
}

static function CHEventListenerTemplate Create_ListenerTemplate_CampaignStart()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_XYM_X2EventListener_CPExtended_CampaignStart');

	// Needed so that soldier generated at the campaign start properly get their custom Kevlar appearance from CP 
	// even if the CP unit didn't have Kevlar equipped when CP was saved.
	Template.RegisterInCampaignStart = true; 

	Template.AddCHEvent('ItemAddedToSlot', OnItemAddedToSlot_CampaignStart, ELD_Immediate, 50);

	return Template;
}

static function EventListenerReturn OnItemAddedToSlot(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Item	ItemState;
	local XComGameState_Unit	UnitState;

	ItemState = XComGameState_Item(EventData);
	if (ItemState == none || X2ArmorTemplate(ItemState.GetMyTemplate()) == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	if (UnitState == none)
		return ELR_NoInterrupt;

	`CPOLOG(UnitState.GetFullName() @ "equipped armor:" @ ItemState.GetMyTemplateName());

	if (UnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ItemState.GetMyTemplateName()))
	{
		`CPOLOG(UnitState.GetFullName() @ "already has stored appearance for" @ ItemState.GetMyTemplateName() $ ", exiting.");
		return ELR_NoInterrupt;
	}

	MaybeApplyUniformAppearance(UnitState, ItemState.GetMyTemplateName());

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnItemAddedToSlot_CampaignStart(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Item			ItemState;
	local XComGameState_Unit			UnitState;
	local CharacterPoolManagerExtended	CharacterPool;

	ItemState = XComGameState_Item(EventData);
	if (ItemState == none || X2ArmorTemplate(ItemState.GetMyTemplate()) == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	if (UnitState == none)
		return ELR_NoInterrupt;
	
	`CPOLOG(UnitState.GetFullName() @ "equipped armor:" @ ItemState.GetMyTemplateName());

	// Even the Campaign Start listener is too late - units already have stored appearance for Kevlar Armor.
	// However, we can allow ourselves to ignore this at campaign start. 
	// If the unit was randomly generated, then we want to replace their appearance with a uniform anyway.
	// If the unit is present in CP, then we'll just import their appearance on top of them again anyway, and no actual changes will happen.

	//if (UnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ArmorTemplateName))
	//{
	//	`CPOLOG(UnitState.GetFullName() @ "already has stored appearance for" @ ArmorTemplateName $ ", exiting.");
	//	return;
	//}

	// This will have to do for now. Assume if the character is present in CP, they will at least have some initial appearance configured.
	// EDIT: Duh, just cuz a char is in CP doesn't mean user doesn't want uniform for them. Removing.
	//CharacterPool = `CHARACTERPOOLMGRXTD;
	//if (CharacterPool == none)
	//	return ELR_NoInterrupt;

	//if (IsCharacterPoolCharacter(UnitState))
	//	return ELR_NoInterrupt;

	MaybeApplyUniformAppearance(UnitState, ItemState.GetMyTemplateName());

	return ELR_NoInterrupt;
}

static private function MaybeApplyUniformAppearance(XComGameState_Unit UnitState, name ArmorTemplateName)
{
	local CharacterPoolManagerExtended	CharacterPool;
	local TAppearance					NewAppearance;
	
	CharacterPool = `CHARACTERPOOLMGRXTD;
	if (CharacterPool == none)
		return;

	NewAppearance = UnitState.kAppearance;

	`CPOLOG(UnitState.GetFullName() @ ArmorTemplateName);
	if (CharacterPool.GetUniformAppearanceForUnit(NewAppearance, UnitState, ArmorTemplateName))
	{
		UnitState.SetTAppearance(NewAppearance);
		UnitState.StoreAppearance(UnitState.kAppearance.iGender, ArmorTemplateName);
	}
}

