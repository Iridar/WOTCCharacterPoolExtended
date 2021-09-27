class UICustomize_CPExtended extends UICustomize;

/*
var UIIcon Icon;

Icon = Spawn(class'UIIcon', self);
	Icon.InitIcon('IconMC',, false, true, 36); // 'IconMC' matches instance name of control in Flash's 'AbilityItem' Symbol
	Icon.SetPosition(-20, -20); // offset because we scale the icon

Icon.LoadIcon(AbilityState.GetMyIconImage());
Icon.EnableMouseAutomaticColor(BackgroundColor, ForegroundColor);
*/

var private CharacterPoolManagerExtended	PoolMgr;
var private X2BodyPartTemplateManager		BodyPartMgr;
var private X2StrategyElementTemplateManager StratMgr;

var private array<int> UniformIndices;

var private bool bPlayerClickedOnUnit;

var private TAppearance			SelectedAppearance;
var private X2SoldierPersonalityTemplate SelectedAttitude; // TODO: Actually use it lol


var private XComHumanPawn		ArmoryPawn;
var private XComGameState_Unit	ArmoryUnit;
var private vector				OriginalPawnLocation;
var private TAppearance			OriginalAppearance; // Appearance to restore if the player exits the screen without selecting anything
var private name				ArmorTemplateName;
var private X2SoldierPersonalityTemplate OriginalAttitude;

// Left list with lotta checkboxes
var UIPanel	OptionsContainer;
var UIBGBox OptionsBG;
var UIList	OptionsList;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local XComGameState_Item	Armor;
	local vector				PawnLocation;
	local UIScreen				CycleScreen;
	local UIMouseGuard			MouseGuard;

	super.InitScreen(InitController, InitMovie, InitName);

	PoolMgr = CharacterPoolManagerExtended(`CHARACTERPOOLMGR);
	if (PoolMgr == none)
		super.CloseScreen();

	ArmoryUnit = CustomizeManager.UpdatedUnitState;
	if (ArmoryUnit == none)
		super.CloseScreen();

	ArmoryPawn = XComHumanPawn(CustomizeManager.ActorPawn);
	if (ArmoryPawn == none)
		super.CloseScreen();

	BodyPartMgr = class'X2BodyPartTemplateManager'.static.GetBodyPartTemplateManager();
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	Armor = ArmoryUnit.GetItemInSlot(eInvSlot_Armor);
	if (Armor != none)
	{
		ArmorTemplateName = Armor.GetMyTemplateName();
	}
	// TODO: MAke this work for switching between units
	OriginalAppearance = ArmoryPawn.m_kAppearance;
	SelectedAppearance = OriginalAppearance;
	OriginalPawnLocation = ArmoryPawn.Location;
	OriginalAttitude = ArmoryUnit.GetPersonalityTemplate();

	PawnLocation = OriginalPawnLocation;
	PawnLocation.X += 20; // Nudge the soldier pawn to the left a little
	ArmoryPawn.SetLocation(PawnLocation);

	List.bStickyHighlight = true;
	//List.OnSelectionChanged = OnUnitSelected;
	List.OnItemClicked = UnitClicked;

	List.SetPosition(1920 - List.Width - 70, 280);
	ListBG.SetPosition(List.X, 280);

	List.SetPosition(List.X + 15, List.Y + 15);
	ListBG.SetHeight(725);

	// Mouse guard dims the entire screen when this UIScreen is spawned, not sure why.
	// Setting it to 3D seems to fix it.
	foreach Movie.Pres.ScreenStack.Screens(CycleScreen)
	{
		MouseGuard = UIMouseGuard(CycleScreen);
		if (MouseGuard == none)
			continue;

		MouseGuard.bIsIn3D = true;
		MouseGuard.SetAlpha(0);
	}

	
	// Create left list	
	OptionsBG = Spawn(class'UIBGBox', self).InitBG('LeftOptionsListBG', 100, 280);
	OptionsBG.SetAlpha(80);
	OptionsBG.SetWidth(582);
	OptionsBG.SetHeight(725);

	OptionsList = Spawn(class'UIList', self);
	OptionsList.bAnimateOnInit = false;
	OptionsList.InitList('LeftOptionsList', 110, 290);
	OptionsList.SetWidth(542);
	OptionsList.SetHeight(705);
	OptionsList.Navigator.LoopSelection = true;
	//OptionsList.OnSelectionChanged = ItemChanged;
	
	OptionsBG.ProcessMouseEvents(List.OnChildMouseEvent);
}

simulated function UpdateData()
{
	local XComGameState_Unit CPUnit;
	
	local int i;

	super.UpdateData();

	//GetListItem(0).UpdateDataDescription("NO CHANGE"); 

	GetListItem(0).UpdateDataCheckbox("NO CHANGE", // TODO: Localize
			"",
			true, // bIsChecked
			SoldierCheckboxChanged, 
			none);
	
	UniformIndices.Length = 0;

	foreach PoolMgr.CharacterPool(CPUnit, i)
	{
		if (OriginalAppearance.iGender != CPUnit.kAppearance.iGender)
			continue;
		
		if (ArmoryUnit.UnitSize != CPUnit.UnitSize)
			continue;

		if (ArmoryUnit.UnitHeight != CPUnit.UnitHeight)
			continue;

		if (ArmorTemplateName != '' && !CPUnit.HasStoredAppearance(OriginalAppearance.iGender, ArmorTemplateName))
			continue;

		UniformIndices.AddItem(i);
	}
	
	for (i = 1; i < UniformIndices.Length + 1; i++)
	{
		//GetListItem(i).UpdateDataDescription(PoolMgr.GetUnitFullNameExtraData(UniformIndices[i - 1]));

		GetListItem(i).UpdateDataCheckbox(PoolMgr.GetUnitFullNameExtraData(UniformIndices[i - 1]), 
			"",
			false, // bIsChecked
			SoldierCheckboxChanged, 
			none);
	}

	//for (i = 1; i < 25; i++)
	//{
	//	GetListItem(i).UpdateDataDescription("Mockup entry" @ i);
	//}

	UpdateOptionsList();
}

simulated function SoldierCheckboxChanged(UICheckbox CheckBox)
{
	local int Index;
	local int i;

	Index = List.GetItemIndex(CheckBox.ParentPanel);
	for (i = 0; i < List.ItemCount; i++)
	{
		if (i == Index)
			continue;

		GetListItem(i).Checkbox.SetChecked(false, false);
	}

	CheckBox.SetChecked(true, false);
	if (Index != INDEX_NONE)
	{
		OnUnitSelected(Index);
	}
}

simulated function CreateOptionName(name OptionName, name CosmeticTemplateName, name NewCosmeticTemplateName)
{
	local UIMechaListItem SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName) $ ":" @ GetBodyPartFriendlyName(OptionName, CosmeticTemplateName) @ "->" @ GetBodyPartFriendlyName(OptionName, NewCosmeticTemplateName), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated function string GetBodyPartFriendlyName(name OptionName, name CosmeticTemplateName)
{
	local X2BodyPartTemplate	BodyPartTemplate;
	local string				PartType;

	if (CosmeticTemplateName == '')
		return class'UIPhotoboothBase'.default.m_strEmptyOption; // "none"

	PartType = GetPartType(OptionName);
	if (PartType != "")
	{
		BodyPartTemplate = BodyPartMgr.FindUberTemplate(PartType, CosmeticTemplateName);
	}

	if (BodyPartTemplate != none && BodyPartTemplate.DisplayName == "")
		`LOG("No localized name for template:" @ BodyPartTemplate.DataName @ PartType @ OptionName,, 'IRITEST');

	if (BodyPartTemplate != none && BodyPartTemplate.DisplayName != "")
		return BodyPartTemplate.DisplayName;

	return string(CosmeticTemplateName);
}

simulated function CreateCountryOptionName(name CountryTemplateName, name NewCountryTemplateName)
{
	local UIMechaListItem SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('nmFlag');

	SpawnedItem.UpdateDataCheckbox(class'UICustomize_Info'.default.m_strNationality $ ":" @ GetFriendlyCountryName(CountryTemplateName) @ "->" @ GetFriendlyCountryName(NewCountryTemplateName), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated function string GetFriendlyCountryName(name CountryTemplateName)
{
	local X2CountryTemplate	CountryTemplate;

	CountryTemplate = X2CountryTemplate(StratMgr.FindStrategyElementTemplate(CountryTemplateName));

	return CountryTemplate != none ? CountryTemplate.DisplayName : string(CountryTemplateName);
}


simulated function CreateOptionInt(name OptionName, int iValue, int iNewValue)
{
	local UIMechaListItem SpawnedItem;
	
	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);
									 
	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName) $ ":" @ string(iValue) @ "->" @ string(iNewValue), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}

simulated function CreateColorOptionInt(name OptionName, int iValue, int iNewValue, EColorPalette PaletteType, optional bool bPrimary = true)
{
	local UIMechaListItem_Color			SpawnedItem;
	local XComLinearColorPalette	Palette;
	local LinearColor				ParamColor;
	local LinearColor				NewParamColor;

	SpawnedItem = Spawn(class'UIMechaListItem_Color', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName), 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);

	Palette = `CONTENT.GetColorPalette(PaletteType);
	if (bPrimary)
	{
		ParamColor = Palette.Entries[iValue].Primary;
		NewParamColor = Palette.Entries[iNewValue].Primary;
	}
	else
	{
		ParamColor = Palette.Entries[iValue].Secondary;
		NewParamColor = Palette.Entries[iNewValue].Secondary;
	}
	SpawnedItem.HTMLColorChip2 = GetHTMLColor(NewParamColor);
	SpawnedItem.strColor1 = string(iValue);
	SpawnedItem.strColor2 = string(iNewValue);
	SpawnedItem.UpdateDataColorChip(GetOptionFriendlyName(OptionName), GetHTMLColor(ParamColor));	
}

simulated function string GetColorFriendlyText(coerce string strText, LinearColor ParamColor)
{
	return "<font color='#" $ GetHTMLColor(ParamColor) $ "'>" $ strText $ "</font>";
}

simulated function string GetHTMLColor(LinearColor ParamColor)
{
	local string ColorString;

	ColorString = Right(ToHex(int(ParamColor.R * 255.0f)), 2) $ Right(ToHex(int(ParamColor.G * 255.0f)), 2)  $ Right(ToHex(int(ParamColor.B * 255.0f)), 2);
	
	return ColorString;
}

simulated function CreateOptionAttitude()
{
	local UIMechaListItem SpawnedItem;
	
	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('iAttitude');
									 
	SpawnedItem.UpdateDataCheckbox(class'UICustomize_Info'.default.m_strAttitude $ ":" @ OriginalAttitude.FriendlyName @ "->" @ SelectedAttitude.FriendlyName, 
			"",
			true, // bIsChecked
			OptionCheckboxChanged, 
			none);
}



simulated function OptionCheckboxChanged(UICheckbox CheckBox)
{
	UpdateUnitAppearance();
}

//simulated function OnUnitSelected(UIList ContainerList, int ItemIndex)
simulated function OnUnitSelected(int ItemIndex)
{
	local XComGameState_Unit CPUnit;

	if (ItemIndex == INDEX_NONE || ItemIndex - 1 > UniformIndices.Length - 1)
		return;
	
	if (ItemIndex == 0)
	{
		SelectedAppearance = OriginalAppearance;
	}
	else
	{
		CPUnit = PoolMgr.CharacterPool[UniformIndices[ItemIndex - 1]];

		if (ArmorTemplateName != '' && CPUnit.HasStoredAppearance(OriginalAppearance.iGender, ArmorTemplateName))
		{
			CPUnit.GetStoredAppearance(SelectedAppearance, OriginalAppearance.iGender, ArmorTemplateName);
		}
		else
		{
			SelectedAppearance = CPUnit.kAppearance;
		}

		SelectedAttitude = CPUnit.GetPersonalityTemplate();
	}
	UpdateOptionsList();
	UpdateUnitAppearance();	
}

simulated function UpdateUnitAppearance()
{
	local TAppearance NewAppearance;

	NewAppearance = OriginalAppearance;

	CopyUniformAppearance(NewAppearance, SelectedAppearance);

	ArmoryPawn.SetAppearance(NewAppearance);
	CustomizeManager.OnCategoryValueChange(eUICustomizeCat_WeaponColor, 0, NewAppearance.iWeaponTint);
}

simulated function UnitClicked(UIList ContainerList, int ItemIndex)
{
	//bPlayerClickedOnUnit = true;
	//CloseScreen();
	SoldierCheckboxChanged(GetListItem(ItemIndex).Checkbox);
}

simulated function CloseScreen()
{	
	if (!bPlayerClickedOnUnit)
	{
		ArmoryPawn.SetAppearance(OriginalAppearance);
		CustomizeManager.OnCategoryValueChange(eUICustomizeCat_WeaponColor, 0, OriginalAppearance.iWeaponTint);
	}
	else
	{
		CustomizeManager.UpdatedUnitState.SetTAppearance(ArmoryPawn.m_kAppearance);
		CustomizeManager.UpdatedUnitState.StoreAppearance();
	}
	ArmoryPawn.SetLocation(OriginalPawnLocation);
	super.CloseScreen();
}

simulated function bool ShouldCopy(name OptionName)
{
	local UIMechaListItem ListItem;

	ListItem = UIMechaListItem(OptionsList.GetChildByName(OptionName, false));

	return ListItem != none && ListItem.Checkbox.bChecked;
}

simulated function CopyUniformAppearance(out TAppearance NewAppearance, const out TAppearance UniformAppearance)
{
	//NewAppearance = UniformAppearance;

	if (ShouldCopy('nmHead')) NewAppearance.nmHead = UniformAppearance.nmHead;
	if (ShouldCopy('iGender')) NewAppearance.iGender = UniformAppearance.iGender;
	if (ShouldCopy('iRace')) NewAppearance.iRace = UniformAppearance.iRace;
	if (ShouldCopy('nmHaircut')) NewAppearance.nmHaircut = UniformAppearance.nmHaircut;
	if (ShouldCopy('iHairColor')) NewAppearance.iHairColor = UniformAppearance.iHairColor;
	if (ShouldCopy('iFacialHair')) NewAppearance.iFacialHair = UniformAppearance.iFacialHair;
	if (ShouldCopy('nmBeard')) NewAppearance.nmBeard = UniformAppearance.nmBeard;
	if (ShouldCopy('iSkinColor')) NewAppearance.iSkinColor = UniformAppearance.iSkinColor;
	if (ShouldCopy('iEyeColor')) NewAppearance.iEyeColor = UniformAppearance.iEyeColor;
	if (ShouldCopy('nmFlag')) NewAppearance.nmFlag = UniformAppearance.nmFlag;
	if (ShouldCopy('iVoice')) NewAppearance.iVoice = UniformAppearance.iVoice;
	if (ShouldCopy('iAttitude')) NewAppearance.iAttitude = UniformAppearance.iAttitude;
	if (ShouldCopy('iArmorDeco')) NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
	if (ShouldCopy('iArmorTint')) NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
	if (ShouldCopy('iArmorTintSecondary')) NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
	if (ShouldCopy('iWeaponTint')) NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
	if (ShouldCopy('iTattooTint')) NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
	if (ShouldCopy('nmWeaponPattern')) NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
	if (ShouldCopy('nmTorso')) NewAppearance.nmTorso = UniformAppearance.nmTorso;
	if (ShouldCopy('nmArms')) NewAppearance.nmArms = UniformAppearance.nmArms;
	if (ShouldCopy('nmLegs')) NewAppearance.nmLegs = UniformAppearance.nmLegs;
	if (ShouldCopy('nmHelmet')) NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
	if (ShouldCopy('nmEye')) NewAppearance.nmEye = UniformAppearance.nmEye;
	if (ShouldCopy('nmTeeth')) NewAppearance.nmTeeth = UniformAppearance.nmTeeth;
	if (ShouldCopy('nmFacePropLower')) NewAppearance.nmFacePropLower = UniformAppearance.nmFacePropLower;
	if (ShouldCopy('nmFacePropUpper')) NewAppearance.nmFacePropUpper = UniformAppearance.nmFacePropUpper;
	if (ShouldCopy('nmPatterns')) NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
	if (ShouldCopy('nmVoice')) NewAppearance.nmVoice = UniformAppearance.nmVoice;
	if (ShouldCopy('nmLanguage')) NewAppearance.nmLanguage = UniformAppearance.nmLanguage;
	if (ShouldCopy('nmTattoo_LeftArm')) NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
	if (ShouldCopy('nmTattoo_RightArm')) NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;
	if (ShouldCopy('nmScars')) NewAppearance.nmScars = UniformAppearance.nmScars;
	if (ShouldCopy('nmTorso_Underlay')) NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
	if (ShouldCopy('nmArms_Underlay')) NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
	if (ShouldCopy('nmLegs_Underlay')) NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
	if (ShouldCopy('nmFacePaint')) NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;
	if (ShouldCopy('nmLeftArm')) NewAppearance.nmLeftArm = UniformAppearance.nmLeftArm;
	if (ShouldCopy('nmRightArm')) NewAppearance.nmRightArm = UniformAppearance.nmRightArm;
	if (ShouldCopy('nmLeftArmDeco')) NewAppearance.nmLeftArmDeco = UniformAppearance.nmLeftArmDeco;
	if (ShouldCopy('nmRightArmDeco')) NewAppearance.nmRightArmDeco = UniformAppearance.nmRightArmDeco;
	if (ShouldCopy('nmLeftForearm')) NewAppearance.nmLeftForearm = UniformAppearance.nmLeftForearm;
	if (ShouldCopy('nmRightForearm')) NewAppearance.nmRightForearm = UniformAppearance.nmRightForearm;
	if (ShouldCopy('nmThighs')) NewAppearance.nmThighs = UniformAppearance.nmThighs;
	if (ShouldCopy('nmShins')) NewAppearance.nmShins = UniformAppearance.nmShins;
	if (ShouldCopy('nmTorsoDeco')) NewAppearance.nmTorsoDeco = UniformAppearance.nmTorsoDeco;
	if (ShouldCopy('bGhostPawn')) NewAppearance.bGhostPawn = UniformAppearance.bGhostPawn;

	//OptionsList.GetChildByName()

	/*
	NewAppearance.iArmorDeco = UniformAppearance.iArmorDeco;
	NewAppearance.iArmorTint = UniformAppearance.iArmorTint;
	NewAppearance.iArmorTintSecondary = UniformAppearance.iArmorTintSecondary;
	NewAppearance.iWeaponTint = UniformAppearance.iWeaponTint;
	NewAppearance.iTattooTint = UniformAppearance.iTattooTint;
	NewAppearance.nmWeaponPattern = UniformAppearance.nmWeaponPattern;
	NewAppearance.nmTorso = UniformAppearance.nmTorso;
	NewAppearance.nmArms = UniformAppearance.nmArms;
	NewAppearance.nmLegs = UniformAppearance.nmLegs;
	NewAppearance.nmHelmet = UniformAppearance.nmHelmet;
	NewAppearance.nmPatterns = UniformAppearance.nmPatterns;
	NewAppearance.nmTattoo_LeftArm = UniformAppearance.nmTattoo_LeftArm;
	NewAppearance.nmTattoo_RightArm = UniformAppearance.nmTattoo_RightArm;
	NewAppearance.nmScars = UniformAppearance.nmScars;
	NewAppearance.nmTorso_Underlay = UniformAppearance.nmTorso_Underlay;
	NewAppearance.nmArms_Underlay = UniformAppearance.nmArms_Underlay;
	NewAppearance.nmLegs_Underlay = UniformAppearance.nmLegs_Underlay;
	NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;*/
}

simulated function UpdateOptionsList()
{
	OptionsList.ClearItems();

	if (SelectedAppearance == OriginalAppearance)
	{
		OptionsList.Hide();
	}
	else if (!OptionsList.bIsVisible)
	{
		OptionsList.Show();
	}

	// HEAD
	if (ShouldShowHeadCategory()) CreateOptionCategory(class'UICustomize_Menu'.default.m_strEditHead); 

	if (OriginalAppearance.iRace != SelectedAppearance.iRace)								CreateOptionInt('iRace', OriginalAppearance.iRace, SelectedAppearance.iRace);
	if (OriginalAppearance.iSkinColor != SelectedAppearance.iSkinColor)						CreateOptionInt('iSkinColor', OriginalAppearance.iSkinColor, SelectedAppearance.iSkinColor);
	if (OriginalAppearance.nmHead != SelectedAppearance.nmHead)								CreateOptionName('nmHead', OriginalAppearance.nmHead , SelectedAppearance.nmHead);
	if (OriginalAppearance.nmHelmet != SelectedAppearance.nmHelmet)							CreateOptionName('nmHelmet', OriginalAppearance.nmHelmet, SelectedAppearance.nmHelmet);
	if (OriginalAppearance.nmFacePropLower != SelectedAppearance.nmFacePropLower)			CreateOptionName('nmFacePropLower', OriginalAppearance.nmHelmet, SelectedAppearance.nmFacePropLower);
	if (OriginalAppearance.nmFacePropUpper != SelectedAppearance.nmFacePropUpper)			CreateOptionName('nmFacePropUpper', OriginalAppearance.nmFacePropUpper, SelectedAppearance.nmFacePropUpper);
	if (OriginalAppearance.nmHaircut != SelectedAppearance.nmHaircut)						CreateOptionName('nmHaircut', OriginalAppearance.nmHaircut, SelectedAppearance.nmHaircut);
	if (OriginalAppearance.nmBeard != SelectedAppearance.nmBeard)							CreateOptionName('nmBeard', OriginalAppearance.nmBeard, SelectedAppearance.nmBeard);
	if (OriginalAppearance.iHairColor != SelectedAppearance.iHairColor)						CreateColorOptionInt('iHairColor', OriginalAppearance.iHairColor, SelectedAppearance.iHairColor, ePalette_HairColor);
	if (OriginalAppearance.iFacialHair != SelectedAppearance.iFacialHair)					CreateOptionInt('iFacialHair', OriginalAppearance.iFacialHair, SelectedAppearance.iFacialHair);
	if (OriginalAppearance.iEyeColor != SelectedAppearance.iEyeColor)						CreateColorOptionInt('iEyeColor', OriginalAppearance.iEyeColor, SelectedAppearance.iEyeColor, ePalette_EyeColor);
	if (OriginalAppearance.nmScars != SelectedAppearance.nmScars)							CreateOptionName('nmScars', OriginalAppearance.nmScars, SelectedAppearance.nmScars);
	if (OriginalAppearance.nmFacePaint != SelectedAppearance.nmFacePaint)					CreateOptionName('nmFacePaint', OriginalAppearance.nmFacePaint, SelectedAppearance.nmFacePaint);
	if (OriginalAppearance.nmEye != SelectedAppearance.nmEye)								CreateOptionName('nmEye', OriginalAppearance.nmEye ,SelectedAppearance.nmEye);
	if (OriginalAppearance.nmTeeth != SelectedAppearance.nmTeeth)							CreateOptionName('nmTeeth', OriginalAppearance.nmTeeth, SelectedAppearance.nmTeeth);

	// BODY
	if (ShouldShowBodyCategory()) CreateOptionCategory(class'UICustomize_Menu'.default.m_strEditBody); 

	if (OriginalAppearance.nmTorso != SelectedAppearance.nmTorso)							CreateOptionName('nmTorso', OriginalAppearance.nmTorso, SelectedAppearance.nmTorso);
	if (OriginalAppearance.nmArms != SelectedAppearance.nmArms)								CreateOptionName('nmArms', OriginalAppearance.nmArms, SelectedAppearance.nmArms);
	if (OriginalAppearance.nmLegs != SelectedAppearance.nmLegs)								CreateOptionName('nmLegs', OriginalAppearance.nmLegs, SelectedAppearance.nmLegs);
	if (OriginalAppearance.nmTorso_Underlay != SelectedAppearance.nmTorso_Underlay)			CreateOptionName('nmTorso_Underlay', OriginalAppearance.nmTorso_Underlay, SelectedAppearance.nmTorso_Underlay);
	if (OriginalAppearance.nmArms_Underlay != SelectedAppearance.nmArms_Underlay)			CreateOptionName('nmArms_Underlay', OriginalAppearance.nmArms_Underlay, SelectedAppearance.nmArms_Underlay);
	if (OriginalAppearance.nmLeftArm != SelectedAppearance.nmLeftArm)						CreateOptionName('nmLeftArm', OriginalAppearance.nmLeftArm, SelectedAppearance.nmLeftArm);
	if (OriginalAppearance.nmRightArm != SelectedAppearance.nmRightArm)						CreateOptionName('nmRightArm', OriginalAppearance.nmRightArm, SelectedAppearance.nmRightArm);
	if (OriginalAppearance.nmLeftArmDeco != SelectedAppearance.nmLeftArmDeco)				CreateOptionName('nmLeftArmDeco', OriginalAppearance.nmLeftArmDeco, SelectedAppearance.nmLeftArmDeco);
	if (OriginalAppearance.nmRightArmDeco != SelectedAppearance.nmRightArmDeco)				CreateOptionName('nmRightArmDeco', OriginalAppearance.nmRightArmDeco, SelectedAppearance.nmRightArmDeco);
	if (OriginalAppearance.nmLeftForearm != SelectedAppearance.nmLeftForearm)				CreateOptionName('nmLeftForearm', OriginalAppearance.nmLeftForearm, SelectedAppearance.nmLeftForearm);
	if (OriginalAppearance.nmRightForearm != SelectedAppearance.nmRightForearm)				CreateOptionName('nmRightForearm', OriginalAppearance.nmRightForearm, SelectedAppearance.nmRightForearm);
	if (OriginalAppearance.nmLegs_Underlay != SelectedAppearance.nmLegs_Underlay)			CreateOptionName('nmLegs_Underlay', OriginalAppearance.nmLegs_Underlay, SelectedAppearance.nmLegs_Underlay);
	if (OriginalAppearance.nmThighs != SelectedAppearance.nmThighs)							CreateOptionName('nmThighs', OriginalAppearance.nmThighs, SelectedAppearance.nmThighs);
	if (OriginalAppearance.nmShins != SelectedAppearance.nmShins)							CreateOptionName('nmShins', OriginalAppearance.nmShins, SelectedAppearance.nmShins);
	if (OriginalAppearance.nmTorsoDeco != SelectedAppearance.nmTorsoDeco)					CreateOptionName('nmTorsoDeco', OriginalAppearance.nmTorsoDeco, SelectedAppearance.nmTorsoDeco);

	// TATTOOS - thanks to Xym for Localize()
	if (ShouldShowTattooCategory()) CreateOptionCategory(Localize("UIArmory_Customize", "m_strBaseLabels[eUICustomizeBase_Tattoos]", "XComGame"));

	if (OriginalAppearance.nmTattoo_LeftArm != SelectedAppearance.nmTattoo_LeftArm)			CreateOptionName('nmTattoo_LeftArm', OriginalAppearance.nmTattoo_LeftArm, SelectedAppearance.nmTattoo_LeftArm);
	if (OriginalAppearance.nmTattoo_RightArm != SelectedAppearance.nmTattoo_RightArm)		CreateOptionName('nmTattoo_RightArm', OriginalAppearance.nmTattoo_RightArm, SelectedAppearance.nmTattoo_RightArm);
	if (ShouldShowTatooColorOption())														CreateColorOptionInt('iTattooTint', OriginalAppearance.iTattooTint, SelectedAppearance.iTattooTint, ePalette_ArmorTint);
	
	// ARMOR PATTERN
	if (ShouldShowArmorPatternCategory()) CreateOptionCategory(class'UICustomize_Body'.default.m_strArmorPattern);

	if (OriginalAppearance.nmPatterns != SelectedAppearance.nmPatterns)						CreateOptionName('nmPatterns', OriginalAppearance.nmPatterns, SelectedAppearance.nmPatterns);
	if (OriginalAppearance.iArmorDeco != SelectedAppearance.iArmorDeco)						CreateOptionInt('iArmorDeco', OriginalAppearance.iArmorDeco, SelectedAppearance.iArmorDeco);
	if (OriginalAppearance.iArmorTint != SelectedAppearance.iArmorTint)						CreateColorOptionInt('iArmorTint', OriginalAppearance.iArmorTint, SelectedAppearance.iArmorTint, ePalette_ArmorTint);
	if (OriginalAppearance.iArmorTintSecondary != SelectedAppearance.iArmorTintSecondary)	CreateColorOptionInt('iArmorTintSecondary', OriginalAppearance.iArmorTintSecondary, SelectedAppearance.iArmorTintSecondary, ePalette_ArmorTint, false);

	// WEAPON PATTERN
	if (ShouldShowWeaponPatternCategory())  CreateOptionCategory(class'UICustomize_Weapon'.default.m_strWeaponPattern); // WEAPON PATTERN

	if (OriginalAppearance.nmWeaponPattern != SelectedAppearance.nmWeaponPattern)			CreateOptionName('nmWeaponPattern', OriginalAppearance.nmWeaponPattern, SelectedAppearance.nmWeaponPattern);
	if (OriginalAppearance.iWeaponTint != SelectedAppearance.iWeaponTint)					CreateColorOptionInt('iWeaponTint', OriginalAppearance.iWeaponTint, SelectedAppearance.iWeaponTint, ePalette_ArmorTint);	

	if (ShouldShowPersonalityCategory()) CreateOptionCategory(Localize("UIArmory_Customize", "m_strBaseLabels[eUICustomizeBase_Personality]", "XComGame")); // PERSONALITY

	if (OriginalAppearance.iAttitude != SelectedAppearance.iAttitude)						CreateOptionAttitude();
	if (OriginalAppearance.nmVoice != SelectedAppearance.nmVoice)							CreateOptionName('nmVoice', OriginalAppearance.nmVoice, SelectedAppearance.nmVoice);
	if (OriginalAppearance.nmFlag != SelectedAppearance.nmFlag)								CreateCountryOptionName(OriginalAppearance.nmFlag, SelectedAppearance.nmFlag);
	if (OriginalAppearance.nmLanguage != SelectedAppearance.nmLanguage)						CreateOptionName('nmLanguage', OriginalAppearance.nmLanguage, SelectedAppearance.nmLanguage);
}

simulated function bool ShouldShowHeadCategory()
{	
	return  OriginalAppearance.iRace != SelectedAppearance.iRace ||
			OriginalAppearance.iSkinColor != SelectedAppearance.iSkinColor ||
			OriginalAppearance.nmHead != SelectedAppearance.nmHead ||
			OriginalAppearance.nmHelmet != SelectedAppearance.nmHelmet ||
			OriginalAppearance.nmFacePropLower != SelectedAppearance.nmFacePropLower ||
			OriginalAppearance.nmFacePropUpper != SelectedAppearance.nmFacePropUpper ||
			OriginalAppearance.nmHaircut != SelectedAppearance.nmHaircut ||
			OriginalAppearance.nmBeard != SelectedAppearance.nmBeard ||
			OriginalAppearance.iHairColor != SelectedAppearance.iHairColor ||
			OriginalAppearance.iFacialHair != SelectedAppearance.iFacialHair ||
			OriginalAppearance.iEyeColor != SelectedAppearance.iEyeColor||
			OriginalAppearance.nmScars != SelectedAppearance.nmScars ||
			OriginalAppearance.nmFacePaint != SelectedAppearance.nmFacePaint ||
			OriginalAppearance.nmEye != SelectedAppearance.nmEye ||
			OriginalAppearance.nmTeeth != SelectedAppearance.nmTeeth;
}

simulated function bool ShouldShowBodyCategory()
{	
	return  OriginalAppearance.nmTorso != SelectedAppearance.nmTorso ||
			OriginalAppearance.nmArms != SelectedAppearance.nmArms ||				
			OriginalAppearance.nmLegs != SelectedAppearance.nmLegs ||					
			OriginalAppearance.nmTorso_Underlay != SelectedAppearance.nmTorso_Underlay ||
			OriginalAppearance.nmArms_Underlay != SelectedAppearance.nmArms_Underlay ||
			OriginalAppearance.nmLeftArm != SelectedAppearance.nmLeftArm ||
			OriginalAppearance.nmRightArm != SelectedAppearance.nmRightArm ||
			OriginalAppearance.nmLeftArmDeco != SelectedAppearance.nmLeftArmDeco ||
			OriginalAppearance.nmRightArmDeco != SelectedAppearance.nmRightArmDeco ||		
			OriginalAppearance.nmLeftForearm != SelectedAppearance.nmLeftForearm ||	
			OriginalAppearance.nmRightForearm != SelectedAppearance.nmRightForearm ||		
			OriginalAppearance.nmLegs_Underlay != SelectedAppearance.nmLegs_Underlay ||	
			OriginalAppearance.nmThighs != SelectedAppearance.nmThighs ||
			OriginalAppearance.nmShins != SelectedAppearance.nmShins ||				
			OriginalAppearance.nmTorsoDeco != SelectedAppearance.nmTorsoDeco;
}

simulated function bool ShouldShowTattooCategory()
{	
	return   OriginalAppearance.nmTattoo_LeftArm != SelectedAppearance.nmTattoo_LeftArm ||
			 OriginalAppearance.nmTattoo_RightArm != SelectedAppearance.nmTattoo_RightArm ||
			 ShouldShowTatooColorOption();
}

simulated function bool ShouldShowTatooColorOption()
{
	// Show tattoo color only if we're changing it *and* at least one of the tattoos for the new appearance isn't empty
	return	OriginalAppearance.iTattooTint != SelectedAppearance.iTattooTint && 
			(SelectedAppearance.nmTattoo_LeftArm != 'Tattoo_Arms_BLANK' || 
			SelectedAppearance.nmTattoo_RightArm != 'Tattoo_Arms_BLANK');
}

simulated function bool ShouldShowArmorPatternCategory()
{	
	return OriginalAppearance.nmPatterns != SelectedAppearance.nmPatterns ||		
		   OriginalAppearance.iArmorDeco != SelectedAppearance.iArmorDeco ||				
		   OriginalAppearance.iArmorTint != SelectedAppearance.iArmorTint ||				
		   OriginalAppearance.iArmorTintSecondary != SelectedAppearance.iArmorTintSecondary;
}

simulated function bool ShouldShowWeaponPatternCategory()
{	
	return	OriginalAppearance.nmWeaponPattern != SelectedAppearance.nmWeaponPattern ||
			OriginalAppearance.iWeaponTint != SelectedAppearance.iWeaponTint;
}

simulated function bool ShouldShowPersonalityCategory()
{	
	return	OriginalAppearance.iAttitude != SelectedAppearance.iAttitude ||
			OriginalAppearance.nmVoice != SelectedAppearance.nmVoice ||		
			OriginalAppearance.nmFlag != SelectedAppearance.nmFlag ||
			OriginalAppearance.nmLanguage != SelectedAppearance.nmLanguage;				
}

static simulated function string GetOptionFriendlyName(name OptionName)
{
	switch (OptionName)
	{
	case'iRace': return class'UICustomize_Head'.default.m_strRace;
	case'iHairColor': return class'UICustomize_Head'.default.m_strHairColor;
	case'iFacialHair': return class'UICustomize_Head'.default.m_strFacialHair;
	case'iSkinColor': return class'UICustomize_Head'.default.m_strSkinColor;
	case'iEyeColor': return class'UICustomize_Head'.default.m_strEyeColor;
	case'iAttitude': return class'UICustomize_Info'.default.m_strAttitude;
	case'iArmorDeco': return class'UICustomize_Body'.default.m_strMainColor;
	case'iArmorTint': return class'UICustomize_Body'.default.m_strMainColor;
	case'iArmorTintSecondary': return class'UICustomize_Body'.default.m_strSecondaryColor;
	case'iWeaponTint': return class'UICustomize_Weapon'.default.m_strWeaponColor;
	case'iTattooTint': return class'UICustomize_Body'.default.m_strTattooColor;
	case'nmHead': return class'UICustomize_Head'.default.m_strFace;
	case'nmHaircut': return class'UICustomize_Head'.default.m_strHair;
	case'nmBeard': return class'UICustomize_Head'.default.m_strFacialHair;
	case'nmVoice': return class'UICustomize_Info'.default.m_strVoice;
	case'nmFlag': return class'UICustomize_Info'.default.m_strNationality;
	case'nmPatterns': return class'UICustomize_Body'.default.m_strArmorPattern;
	case'nmWeaponPattern': return class'UICustomize_Weapon'.default.m_strWeaponPattern;
	case'nmTorso': return class'UICustomize_Body'.default.m_strTorso;
	case'nmArms': return class'UICustomize_Body'.default.m_strArms;
	case'nmLegs': return class'UICustomize_Body'.default.m_strLegs;
	case'nmHelmet': return class'UICustomize_Head'.default.m_strHelmet;
	case'nmEye': return "Eye type";
	case'nmTeeth': return "Teeth";
	case'nmFacePropUpper': return class'UICustomize_Head'.default.m_strUpperFaceProps;
	case'nmFacePropLower': return class'UICustomize_Head'.default.m_strLowerFaceProps;
	case'nmLanguage': return "Language";
	case'nmTattoo_LeftArm': return class'UICustomize_Body'.default.m_strTattoosLeft;
	case'nmTattoo_RightArm': return class'UICustomize_Body'.default.m_strTattoosRight;
	case'nmScars': return class'UICustomize_Head'.default.m_strScars;
	case'nmTorso_Underlay': return "Torso Underlay";
	case'nmArms_Underlay': return "Arms Underlay";
	case'nmLegs_Underlay': return "Legs Underlay";
	case'nmFacePaint': return class'UICustomize_Head'.default.m_strFacepaint;
	case'nmLeftArm': return class'UICustomize_Body'.default.m_strLeftArm;
	case'nmRightArm': return class'UICustomize_Body'.default.m_strRightArm;
	case'nmLeftArmDeco': return class'UICustomize_Body'.default.m_strLeftArmDeco;
	case'nmRightArmDeco': return class'UICustomize_Body'.default.m_strRightArmDeco;
	case'nmLeftForearm': return class'UICustomize_Body'.default.m_strLeftForearm;
	case'nmRightForearm': return class'UICustomize_Body'.default.m_strRightForearm;
	case'nmThighs': return class'UICustomize_Body'.default.m_strThighs;
	case'nmShins': return class'UICustomize_Body'.default.m_strShins;
	case'nmTorsoDeco': return class'UICustomize_Body'.default.m_strTorsoDeco;
	default:
		return "";
	}
}

simulated function string GetPartType(name OptionName)
{
	switch (OptionName)
	{
	case'nmHead': return "Head";
	case'nmHaircut': return "Hair";
	case'nmBeard': return "Beards";
	case'nmVoice': return "Voice";
	case'nmFlag': return "";
	case'nmPatterns': return "Patterns";
	case'nmWeaponPattern': return "Patterns";
	case'nmTorso': return "Torso";
	case'nmArms': return "Arms";
	case'nmLegs': return "Legs";
	case'nmHelmet': return "Helmets";
	case'nmEye': return "Eyes";
	case'nmTeeth': return "Teeth";
	case'nmFacePropUpper': return "FacePropsUpper";
	case'nmFacePropLower': return "FacePropsLower";
	case'nmLanguage': return "";
	case'nmTattoo_LeftArm': return "Tattoos";
	case'nmTattoo_RightArm': return "Tattoos";
	case'nmScars': return "Scars";
	case'nmTorso_Underlay': return "";
	case'nmArms_Underlay': return "";
	case'nmLegs_Underlay': return "";
	case'nmFacePaint': return "Facepaint";
	case'nmLeftArm': return "LeftArm";
	case'nmRightArm': return "RightArm";
	case'nmLeftArmDeco': return "LeftArmDeco";
	case'nmRightArmDeco': return "RightArmDeco";
	case'nmLeftForearm': return "LeftForearm";
	case'nmRightForearm': return "RightForearm";
	case'nmThighs': return "Thighs";
	case'nmShins': return "Shins";
	case'nmTorsoDeco': return "TorsoDeco";
	default:
		return "";
	}
	
	//DecoKits
}
simulated function CreateOptionCategory(string strText)
{
	local UIMechaListItem SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem();
	SpawnedItem.SetDisabled(true);
	SpawnedItem.UpdateDataDescription(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(strText));
}


/*class'UICustomize_Info'.default.m_strFirstNameLabel=First Name
class'UICustomize_Info'.default.m_strLastNameLabel=Last Name
class'UICustomize_Info'.default.m_strNicknameLabel=Nickname
class'UICustomize_Info'.default.m_strEditBiography=Biography
*/


/*
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_FirstName]=FIRST NAME
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_LastName]=LAST NAME
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_NickName]=NICK NAME
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_DEV_Torso]=Torso (DEV)
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_DEV_Arms]=Arms (DEV)
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_DEV_Legs]=Legs (DEV)
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Skin]=SKIN

class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Face]=FACE

class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_EyeColor]=EYE COLOR
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_EyeType]=EYE TYPE
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_TeethType]=TEETH TYPE
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Hairstyle]=HAIR STYLE
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_HairColor]=HAIR COLOR
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_FaceDecorationUpper]=FACE DECORATION UPPER
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_FaceDecorationLower]=FACE DECORATION LOWER
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_FacialHair]=FACIAL HAIR
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Scars]=SCARS
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Tattoos]=TATTOOS

class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Personality]=PERSONALITY

class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Clothes]=CLOTHES
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Country]=COUNTRY
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Voice]=VOICE
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Gender]=GENDER
class'UIArmory_Customize'.default.m_strBaseLabels[eUICustomizeBase_Race]=RACE
*/