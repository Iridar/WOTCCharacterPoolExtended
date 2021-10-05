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

	return Template;
}

// See comments in UICustomize_CPExtended::UpdateUnitAppearance() as to why this is necessary
static function EventListenerReturn OnOverrideCharCustomizationScale(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local UIScreenStack ScreenStack;
	local UICustomize_CPExtended CPExtendedScreen;

	ScreenStack = `SCREENSTACK;
	if (ScreenStack != none)
	{
		CPExtendedScreen = UICustomize_CPExtended(ScreenStack.GetFirstInstanceOf(class'UICustomize_CPExtended'));
		if (CPExtendedScreen != none)
		{
			CPExtendedScreen.OnRefreshPawn();
		}
	}

	return ELR_NoInterrupt;
}


static function CHEventListenerTemplate Create_ListenerTemplate_StrategyAndTactical()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_XYM_X2EventListener_CPExtended_StrategyAndTactical');

	// Units shouldn't be able to swap armor mid-mission, but you never know
	Template.RegisterInTactical = true; 
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

	`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "equipped on:" @ UnitState.GetFullName(),, 'IRITEST');

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

	`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "equipped on:" @ UnitState.GetFullName(),, 'IRITEST');

	// Even the Campaign Start listener is too late - units already have stored appearance for Kevlar Armor.
	// However, we can allow ourselves to ignore this at campaign start. 
	// If the unit was randomly generated, then we want to replace their appearance with a uniform anyway.
	// If the unit is present in CP, then we'll just import their appearance on top of them again anyway, and no actual changes will happen.
	MaybeApplyCharacterPoolAppearance(UnitState, ItemState.GetMyTemplateName(), true);

	return ELR_NoInterrupt;
}

static private function MaybeApplyCharacterPoolAppearance(XComGameState_Unit UnitState, name ArmorTemplateName, optional bool bSkipStoredAppearanceCheck = false)
{
	local XComGameState_Unit	CPUnitState;
	local CharacterPoolManager	CharacterPool;
	local TAppearance			CPAppearance;
	local TAppearance			NewAppearance;

	if (!bSkipStoredAppearanceCheck)
	{
		if (UnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ArmorTemplateName))
		{
			`LOG("Unit already has stored appearance for this armor, exiting",, 'IRITEST');
			return;
		}
	}
	
	CharacterPool = `CHARACTERPOOLMGR;
	CPUnitState = CharacterPool.GetCharacter(UnitState.GetFullName());
	if (CPUnitState != none)
	{
		`LOG("This unit is present in CP.",, 'IRITEST');
	}

	if (CPUnitState != none && CPUnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ArmorTemplateName))
	{
		`LOG("CP unit has stored appearance for this armor, restoring.",, 'IRITEST');

		CPUnitState.GetStoredAppearance(CPAppearance, UnitState.kAppearance.iGender, ArmorTemplateName);
		UnitState.SetTAppearance(CPAppearance);
		UnitState.StoreAppearance(UnitState.kAppearance.iGender, ArmorTemplateName);
		return;
	}

	`LOG("CP unit has no stored appearance for this armor",, 'IRITEST');

	foreach CharacterPool.CharacterPool(CPUnitState)
	{
		if (CPUnitState.GetFirstName() == class'UISL_CPExtended'.default.strUniform &&
			CPUnitState.HasStoredAppearance(UnitState.kAppearance.iGender, ArmorTemplateName))
		{
			`LOG("Found uniform unit:" @ CPUnitState.GetFullName() @ "using its appearance",, 'IRITEST');

			CPUnitState.GetStoredAppearance(CPAppearance, UnitState.kAppearance.iGender, ArmorTemplateName);

			NewAppearance = UnitState.kAppearance;
			CopyUniformAppearance(NewAppearance, CPAppearance);

			UnitState.SetTAppearance(NewAppearance);
			UnitState.StoreAppearance(UnitState.kAppearance.iGender, ArmorTemplateName);
			return;
		}
	}
}

static private function CopyUniformAppearance(out TAppearance NewAppearance, const TAppearance UniformAppearance)
{
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmHead')) NewAppearance.nmHead = UniformAppearance.nmHead;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iGender')) NewAppearance.iGender = UniformAppearance.iGender;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iRace')) NewAppearance.iRace = UniformAppearance.iRace;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmHaircut')) NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iHairColor')) NewAppearance.iHairColor = UniformAppearance.iHairColor;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iFacialHair')) NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmBeard')) NewAppearance.nmBeard = UniformAppearance.nmBeard;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iSkinColor')) NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iEyeColor')) NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmFlag')) NewAppearance.nmFlag = UniformAppearance.nmFlag;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iVoice')) NewAppearance.iVoice = UniformAppearance.iVoice;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iAttitude')) NewAppearance.iAttitude = UniformAppearance.iAttitude;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iArmorDeco')) NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iArmorTint')) NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iArmorTintSecondary')) NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iWeaponTint')) NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('iTattooTint')) NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmWeaponPattern')) NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmPawn')) NewAppearance.nmPawn = UniformAppearance.nmPawn;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmTorso')) NewAppearance.nmTorso = UniformAppearance.nmTorso;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmArms')) NewAppearance.nmArms = UniformAppearance.nmArms;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmLegs')) NewAppearance.nmLegs = UniformAppearance.nmLegs;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmHelmet')) NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmEye')) NewAppearance.nmEye = UniformAppearance.nmEye;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmTeeth')) NewAppearance.nmTeeth = UniformAppearance.nmTeeth;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmFacePropLower')) NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmFacePropUpper')) NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmPatterns')) NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmVoice')) NewAppearance.nmVoice = UniformAppearance.nmVoice;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmLanguage')) NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmTattoo_LeftArm')) NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmTattoo_RightArm')) NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmScars')) NewAppearance.nmScars = UniformAppearance.nmScars;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmTorso_Underlay')) NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmArms_Underlay')) NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmLegs_Underlay')) NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmFacePaint')) NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmLeftArm')) NewAppearance.nmLeftArm = UniformAppearance.nmLeftArm;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmRightArm')) NewAppearance.nmRightArm = UniformAppearance.nmRightArm;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmLeftArmDeco')) NewAppearance.nmLeftArmDeco = UniformAppearance.nmLeftArmDeco;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmRightArmDeco')) NewAppearance.nmRightArmDeco = UniformAppearance.nmRightArmDeco;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmLeftForearm')) NewAppearance.nmLeftForearm = UniformAppearance.nmLeftForearm;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmRightForearm')) NewAppearance.nmRightForearm = UniformAppearance.nmRightForearm;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmThighs')) NewAppearance.nmThighs = UniformAppearance.nmThighs;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmShins')) NewAppearance.nmShins = UniformAppearance.nmShins;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('nmTorsoDeco')) NewAppearance.nmTorsoDeco = UniformAppearance.nmTorsoDeco;
	if (class'UICustomize_CPExtended'.static.ShouldCopyUniformPiece('bGhostPawn')) NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;
}
