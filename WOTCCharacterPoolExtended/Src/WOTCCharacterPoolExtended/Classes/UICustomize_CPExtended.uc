class UICustomize_CPExtended extends UICustomize;

var private CharacterPoolManagerExtended	PoolMgr;
var private X2BodyPartTemplateManager		BodyPartMgr;

var private array<int> UniformIndices;

var private bool bPlayerClickedOnUnit;

var private TAppearance			SelectedAppearance;

var private XComHumanPawn		ArmoryPawn;
var private XComGameState_Unit	ArmoryUnit;
var private vector				OriginalPawnLocation;
var private TAppearance			OriginalAppearance; // Appearance to restore if the player exits the screen without selecting anything
var private name				ArmorTemplateName;

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

	Armor = ArmoryUnit.GetItemInSlot(eInvSlot_Armor);
	if (Armor != none)
	{
		ArmorTemplateName = Armor.GetMyTemplateName();
	}
	// TODO: MAke this work for switching between units
	OriginalAppearance = ArmoryPawn.m_kAppearance;
	OriginalPawnLocation = ArmoryPawn.Location;

	PawnLocation = OriginalPawnLocation;
	PawnLocation.X += 20; // Nudge the soldier pawn to the left a little
	ArmoryPawn.SetLocation(PawnLocation);

	List.bStickyHighlight = true;
	List.OnSelectionChanged = OnUnitSelected;
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

	GetListItem(0).UpdateDataDescription("NO CHANGE"); // TODO: Localize
	
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
	
	// DEBUG ONLY
	//for (i = 1; i < UniformIndices.Length + 1; i++)
	//{
	//	GetListItem(i).UpdateDataDescription(PoolMgr.GetUnitFullNameExtraData(UniformIndices[i - 1]));
	//}

	for (i = 1; i < 25; i++)
	{
		GetListItem(i).UpdateDataDescription("Mockup entry" @ i);
	}

	UpdateOptionsList();
}

simulated function CreateOptionName(name OptionName, name CosmeticTemplateName)
{
	local UIMechaListItem		SpawnedItem;
	local X2BodyPartTemplate	BodyPartTemplate;
	local string				PartType;
	
	if (CosmeticTemplateName == '')
		return;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	PartType = GetPartType(OptionName);
	if (PartType != "")
	{
		BodyPartTemplate = BodyPartMgr.FindUberTemplate(PartType, CosmeticTemplateName);
	}

	/*simulated function UIMechaListItem UpdateDataCheckbox(string _Desc,
									  String _CheckboxLabel,
									  bool bIsChecked,
									  delegate<OnCheckboxChangedCallback> _OnCheckboxChangedCallback = none,
									  optional delegate<OnClickDelegate> _OnClickDelegate = none)*/

	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName) $ ":" @ BodyPartTemplate != none ? BodyPartTemplate.DisplayName : string(CosmeticTemplateName), 
			"",
			true, // bIsChecked
			none, 
			none);
}

simulated function CreateOptionInt(name OptionName, int iValue)
{
	local UIMechaListItem SpawnedItem;
	
	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(OptionName);

	//SpawnedItem.UpdateDataButton(string(CosmeticTemplateName), class'UISaveLoadGameListItem'.default.m_sDeleteLabel, OnDeletePool);

	/*simulated function UIMechaListItem UpdateDataCheckbox(string _Desc,
									  String _CheckboxLabel,
									  bool bIsChecked,
									  delegate<OnCheckboxChangedCallback> _OnCheckboxChangedCallback = none,
									  optional delegate<OnClickDelegate> _OnClickDelegate = none)*/

	SpawnedItem.UpdateDataCheckbox(GetOptionFriendlyName(OptionName) $ ":" @ string(iValue), 
			"",
			true, // bIsChecked
			none, 
			none);
}

simulated function OnUnitSelected(UIList ContainerList, int ItemIndex)
{
	local XComGameState_Unit	CPUnit;
	local TAppearance			NewAppearance;

	if (ItemIndex == 0)
	{
		ArmoryPawn.SetAppearance(OriginalAppearance);
		CustomizeManager.OnCategoryValueChange(eUICustomizeCat_WeaponColor, 0, OriginalAppearance.iWeaponTint);
		return;
	}

	if (ItemIndex == INDEX_NONE || ItemIndex - 1 > UniformIndices.Length - 1)
		return;

	CPUnit = PoolMgr.CharacterPool[UniformIndices[ItemIndex - 1]];
	NewAppearance = ArmoryPawn.m_kAppearance;

	if (ArmorTemplateName != '' && CPUnit.HasStoredAppearance(NewAppearance.iGender, ArmorTemplateName))
	{
		CPUnit.GetStoredAppearance(SelectedAppearance, NewAppearance.iGender, ArmorTemplateName);
	}
	else
	{
		SelectedAppearance = CPUnit.kAppearance;
	}
	
	CopyUniformAppearance(NewAppearance, SelectedAppearance);

	ArmoryPawn.SetAppearance(NewAppearance);
	CustomizeManager.OnCategoryValueChange(eUICustomizeCat_WeaponColor, 0, NewAppearance.iWeaponTint);

	UpdateOptionsList();
}

simulated function UnitClicked(UIList ContainerList, int ItemIndex)
{
	bPlayerClickedOnUnit = true;
	CloseScreen();
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

static function CopyUniformAppearance(out TAppearance NewAppearance, const out TAppearance UniformAppearance)
{
	NewAppearance = UniformAppearance;
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
	
	if (OriginalAppearance.iRace != SelectedAppearance.iRace)								CreateOptionInt('iRace', SelectedAppearance.iRace);
	if (OriginalAppearance.iHairColor != SelectedAppearance.iHairColor)						CreateOptionInt('iHairColor', SelectedAppearance.iHairColor);
	if (OriginalAppearance.iFacialHair != SelectedAppearance.iFacialHair)					CreateOptionInt('iFacialHair', SelectedAppearance.iFacialHair);
	if (OriginalAppearance.iSkinColor != SelectedAppearance.iSkinColor)						CreateOptionInt('iSkinColor', SelectedAppearance.iSkinColor);
	if (OriginalAppearance.iEyeColor != SelectedAppearance.iEyeColor)						CreateOptionInt('iEyeColor', SelectedAppearance.iEyeColor);
	if (OriginalAppearance.iAttitude != SelectedAppearance.iAttitude)						CreateOptionInt('iAttitude', SelectedAppearance.iAttitude);
	if (OriginalAppearance.iArmorDeco != SelectedAppearance.iArmorDeco)						CreateOptionInt('iArmorDeco', SelectedAppearance.iArmorDeco);
	if (OriginalAppearance.iArmorTint != SelectedAppearance.iArmorTint)						CreateOptionInt('iArmorTint', SelectedAppearance.iArmorTint);
	if (OriginalAppearance.iArmorTintSecondary != SelectedAppearance.iArmorTintSecondary)	CreateOptionInt('iArmorTintSecondary', SelectedAppearance.iArmorTintSecondary);
	if (OriginalAppearance.iWeaponTint != SelectedAppearance.iWeaponTint)					CreateOptionInt('iWeaponTint', SelectedAppearance.iWeaponTint);
	if (OriginalAppearance.iTattooTint != SelectedAppearance.iTattooTint)					CreateOptionInt('iTattooTint', SelectedAppearance.iTattooTint);

	if (OriginalAppearance.nmHead != SelectedAppearance.nmHead)								CreateOptionName('nmHead', SelectedAppearance.nmHead);
	if (OriginalAppearance.nmHaircut != SelectedAppearance.nmHaircut)						CreateOptionName('nmHaircut', SelectedAppearance.nmHaircut);
	if (OriginalAppearance.nmBeard != SelectedAppearance.nmBeard)							CreateOptionName('nmBeard', SelectedAppearance.nmBeard);
	if (OriginalAppearance.nmVoice != SelectedAppearance.nmVoice)							CreateOptionName('nmVoice', SelectedAppearance.nmVoice);
	if (OriginalAppearance.nmFlag != SelectedAppearance.nmFlag)								CreateOptionName('nmFlag', SelectedAppearance.nmFlag);
	if (OriginalAppearance.nmPatterns != SelectedAppearance.nmPatterns)						CreateOptionName('nmPatterns', SelectedAppearance.nmPatterns);
	if (OriginalAppearance.nmWeaponPattern != SelectedAppearance.nmWeaponPattern)			CreateOptionName('nmWeaponPattern', SelectedAppearance.nmWeaponPattern);
	if (OriginalAppearance.nmTorso != SelectedAppearance.nmTorso)							CreateOptionName('nmTorso', SelectedAppearance.nmTorso);
	if (OriginalAppearance.nmArms != SelectedAppearance.nmArms)								CreateOptionName('nmArms', SelectedAppearance.nmArms);
	if (OriginalAppearance.nmLegs != SelectedAppearance.nmLegs)								CreateOptionName('nmLegs', SelectedAppearance.nmLegs);
	if (OriginalAppearance.nmHelmet != SelectedAppearance.nmHelmet)							CreateOptionName('nmHelmet', SelectedAppearance.nmHelmet);
	if (OriginalAppearance.nmEye != SelectedAppearance.nmEye)								CreateOptionName('nmEye', SelectedAppearance.nmEye);
	if (OriginalAppearance.nmTeeth != SelectedAppearance.nmTeeth)							CreateOptionName('nmTeeth', SelectedAppearance.nmTeeth);
	if (OriginalAppearance.nmFacePropLower != SelectedAppearance.nmFacePropLower)			CreateOptionName('nmFacePropLower', SelectedAppearance.nmFacePropLower);
	if (OriginalAppearance.nmFacePropUpper != SelectedAppearance.nmFacePropUpper)			CreateOptionName('nmFacePropUpper', SelectedAppearance.nmFacePropUpper);
	if (OriginalAppearance.nmLanguage != SelectedAppearance.nmLanguage)						CreateOptionName('nmLanguage', SelectedAppearance.nmLanguage);
	if (OriginalAppearance.nmTattoo_LeftArm != SelectedAppearance.nmTattoo_LeftArm)			CreateOptionName('nmTattoo_LeftArm', SelectedAppearance.nmTattoo_LeftArm);
	if (OriginalAppearance.nmTattoo_RightArm != SelectedAppearance.nmTattoo_RightArm)		CreateOptionName('nmTattoo_RightArm', SelectedAppearance.nmTattoo_RightArm);
	if (OriginalAppearance.nmScars != SelectedAppearance.nmScars)							CreateOptionName('nmScars', SelectedAppearance.nmScars);
	if (OriginalAppearance.nmTorso_Underlay != SelectedAppearance.nmTorso_Underlay)			CreateOptionName('nmTorso_Underlay', SelectedAppearance.nmTorso_Underlay);
	if (OriginalAppearance.nmArms_Underlay != SelectedAppearance.nmArms_Underlay)			CreateOptionName('nmArms_Underlay', SelectedAppearance.nmArms_Underlay);
	if (OriginalAppearance.nmLegs_Underlay != SelectedAppearance.nmLegs_Underlay)			CreateOptionName('nmLegs_Underlay', SelectedAppearance.nmLegs_Underlay);
	if (OriginalAppearance.nmFacePaint != SelectedAppearance.nmFacePaint)					CreateOptionName('nmFacePaint', SelectedAppearance.nmFacePaint);
	if (OriginalAppearance.nmLeftArm != SelectedAppearance.nmLeftArm)						CreateOptionName('nmLeftArm', SelectedAppearance.nmLeftArm);
	if (OriginalAppearance.nmRightArm != SelectedAppearance.nmRightArm)						CreateOptionName('nmRightArm', SelectedAppearance.nmRightArm);
	if (OriginalAppearance.nmLeftArmDeco != SelectedAppearance.nmLeftArmDeco)				CreateOptionName('nmLeftArmDeco', SelectedAppearance.nmLeftArmDeco);
	if (OriginalAppearance.nmRightArmDeco != SelectedAppearance.nmRightArmDeco)				CreateOptionName('nmRightArmDeco', SelectedAppearance.nmRightArmDeco);
	if (OriginalAppearance.nmLeftForearm != SelectedAppearance.nmLeftForearm)				CreateOptionName('nmLeftForearm', SelectedAppearance.nmLeftForearm);
	if (OriginalAppearance.nmRightForearm != SelectedAppearance.nmRightForearm)				CreateOptionName('nmRightForearm', SelectedAppearance.nmRightForearm);
	if (OriginalAppearance.nmThighs != SelectedAppearance.nmThighs)							CreateOptionName('nmThighs', SelectedAppearance.nmThighs);
	if (OriginalAppearance.nmShins != SelectedAppearance.nmShins)							CreateOptionName('nmShins', SelectedAppearance.nmShins);
	if (OriginalAppearance.nmTorsoDeco != SelectedAppearance.nmTorsoDeco)					CreateOptionName('nmTorsoDeco', SelectedAppearance.nmTorsoDeco);
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