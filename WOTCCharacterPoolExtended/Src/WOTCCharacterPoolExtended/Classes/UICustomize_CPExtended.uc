class UICustomize_CPExtended extends UICustomize;

var private CharacterPoolManagerExtended PoolMgr;
var private array<int> UniformIndices;

var private bool bPlayerClickedOnUnit;

var private XComHumanPawn		ArmoryPawn;
var private XComGameState_Unit	ArmoryUnit;
var private vector				OriginalPawnLocation;
var private TAppearance			OriginalAppearance; // Appearance to restore if the player exits the screen without selecting anything
var private name				ArmorTemplateName;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local XComGameState_Item	Armor;
	local vector				PawnLocation;

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
	OriginalPawnLocation = ArmoryPawn.Location;

	PawnLocation = OriginalPawnLocation;
	PawnLocation.X += 20; // Nudge the soldier pawn to the left a little
	ArmoryPawn.SetLocation(PawnLocation);

	List.OnSelectionChanged = OnUnitSelected;
	List.OnItemClicked = UnitClicked;

	List.SetPosition(1920 - List.Width - 70, 10);
	ListBG.SetPosition(List.X, 10);

	List.SetPosition(List.X + 15, List.Y + 15);
	ListBG.SetHeight(725);
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
	
	//for (i = 1; i < UniformIndices.Length + 1; i++)
	//{
	//	GetListItem(i).UpdateDataDescription(PoolMgr.GetUnitFullNameExtraData(UniformIndices[i - 1]));
	//}

	for (i = 1; i < 25; i++)
	{
		GetListItem(i).UpdateDataDescription("Mockup entry" @ i);
	}
}

simulated function OnUnitSelected(UIList ContainerList, int ItemIndex)
{
	local XComGameState_Unit	CPUnit;
	local TAppearance			CPUnitAppearance;
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