class X2EventListener_CPExtended extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_ListenerTemplate_Strategy());
	Templates.AddItem(Create_ListenerTemplate_StrategyAndTactical());
	Templates.AddItem(Create_ListenerTemplate_CampaignStart());
	
	return Templates;
}

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
		//else // Events still don't trigger in CP...
		//{
		//	AppearanceStoreScreen = UICustomize_AppearanceStore(ScreenStack.GetFirstInstanceOf(class'UICustomize_AppearanceStore'));
		//	if (AppearanceStoreScreen != none)
		//	{
		//		AppearanceStoreScreen.OnRefreshPawn();
		//	}
		//}
	}

	return ELR_NoInterrupt;
}

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

	MaybeApplyCharacterPoolAppearance(UnitState, ItemState.GetMyTemplateName());

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnItemAddedToSlot_CampaignStart(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
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

	// Even the Campaign Start listener is too late - units already have stored appearance for Kevlar Armor.
	// However, we can allow ourselves to ignore this at campaign start. 
	// If the unit was randomly generated, then we want to replace their appearance with a uniform anyway.
	// If the unit is present in CP, then we'll just import their appearance on top of them again anyway, and no actual changes will happen.
	MaybeApplyCharacterPoolAppearance(UnitState, ItemState.GetMyTemplateName(), true);

	return ELR_NoInterrupt;
}

static private function MaybeApplyCharacterPoolAppearance(XComGameState_Unit UnitState, name ArmorTemplateName, optional bool bSkipStoredAppearanceCheck = false)
{
	local XComGameState_Unit			CPUnitState;
	local CharacterPoolManagerExtended	CharacterPool;
	local TAppearance					CPAppearance;
	local TAppearance					NewAppearance;

	if (!bSkipStoredAppearanceCheck)
	{
		if (UnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ArmorTemplateName))
		{
			`CPOLOG(UnitState.GetFullName() @ "already has stored appearance for" @ ArmorTemplateName $ ", exiting.");
			return;
		}
	}
	
	CharacterPool = CharacterPoolManagerExtended(`CHARACTERPOOLMGR);
	if (CharacterPool == none)
		return;

	CPUnitState = CharacterPool.GetCharacter(UnitState.GetFullName());
	if (CPUnitState != none)
	{
		`CPOLOG(UnitState.GetFullName() @ "is present in Character Pool.");
		if (CPUnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ArmorTemplateName))
		{
			`CPOLOG(UnitState.GetFullName() @ "in Character Pool has stored appearance for" @ ArmorTemplateName $ ", importing it.");

			CPUnitState.GetStoredAppearance(CPAppearance, UnitState.kAppearance.iGender, ArmorTemplateName);
			UnitState.SetTAppearance(CPAppearance);
			UnitState.StoreAppearance(UnitState.kAppearance.iGender, ArmorTemplateName);
			return;
		}
		`CPOLOG(UnitState.GetFullName() @ "in Character Pool has no stored appearance for" @ ArmorTemplateName $ ".");
	}

	foreach CharacterPool.CharacterPool(CPUnitState)
	{
		if (CharacterPool.IsUnitUniform(CPUnitState) && CharacterPool.IsUniformValidForUnit(UnitState, CPUnitState) &&
			CPUnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ArmorTemplateName)) 
		{
			`CPOLOG("Found uniform unit:" @ CPUnitState.GetFullName() $ ", importing their appearance.");

			CPUnitState.GetStoredAppearance(CPAppearance, UnitState.kAppearance.iGender, ArmorTemplateName);

			NewAppearance = UnitState.kAppearance;
			class'UICustomize_CPExtended'.static.CopyAppearance_Static(NewAppearance, CPAppearance, 'PresetUniform');

			UnitState.SetTAppearance(NewAppearance);
			UnitState.StoreAppearance(UnitState.kAppearance.iGender, ArmorTemplateName);
			return;
		}
	}
}

