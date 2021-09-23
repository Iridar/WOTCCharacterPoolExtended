class UICustomize_CPExtended extends UICustomize;

var private CharacterPoolManagerExtended PoolMgr;
var private array<int> UniformIndices;

var private bool bPlayerClickedOnUnit;

var private XComHumanPawn		ArmoryPawn;
var private XComGameState_Unit	ArmoryUnit;
var private TAppearance			OriginalAppearance; // Appearance to restore if the player exits the screen without selecting anything
var private name				ArmorTemplateName;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local XComGameState_Item Armor;

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

	Armor = ArmoryUnit.GetItemInSlot(eInvSlot_Armor);
	if (Armor != none)
	{
		ArmorTemplateName = Armor.GetMyTemplateName();
	}
	OriginalAppearance = ArmoryPawn.m_kAppearance;

	List.OnSelectionChanged = OnUnitSelected;
	List.OnItemClicked = UnitClicked;
	//List.SetX(List.X + 900);
	//ListBG.SetX(ListBG.X + 900);
}

simulated function UpdateData()
{
	local XComGameState_Unit CPUnit;
	local int i;

	super.UpdateData();
	
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
	for (i = 0; i < UniformIndices.Length; i++)
	{
		GetListItem(i).UpdateDataDescription(PoolMgr.GetUnitFullNameExtraData(UniformIndices[i]));
	}
}

simulated function OnUnitSelected(UIList ContainerList, int ItemIndex)
{
	local XComGameState_Unit	CPUnit;
	local TAppearance			CPUnitAppearance;
	local TAppearance			NewAppearance;

	if (ItemIndex == INDEX_NONE || ItemIndex > UniformIndices.Length - 1)
		return;

	CPUnit = PoolMgr.CharacterPool[UniformIndices[ItemIndex]];
	NewAppearance = ArmoryPawn.m_kAppearance;

	if (ArmorTemplateName != '' && CPUnit.HasStoredAppearance(NewAppearance.iGender, ArmorTemplateName))
	{
		CPUnit.GetStoredAppearance(CPUnitAppearance, NewAppearance.iGender, ArmorTemplateName);
	}
	else
	{
		CPUnitAppearance = CPUnit.kAppearance;
	}
	
	CopyUniformAppearance(NewAppearance, CPUnitAppearance);

	ArmoryPawn.SetAppearance(NewAppearance);
	CustomizeManager.OnCategoryValueChange(eUICustomizeCat_WeaponColor, 0, NewAppearance.iWeaponTint);
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