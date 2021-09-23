class UICustomize_CPExtended extends UICustomize;

var private CharacterPoolManagerExtended	PoolMgr;
var private array<int> UniformIndices;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	PoolMgr = CharacterPoolManagerExtended(`CHARACTERPOOLMGR);
}

simulated function UpdateData()
{
	local XComGameState_Unit CPUnit;
	local XComGameState_Unit ArmoryUnit;
	local int i;

	super.UpdateData();
	
	ArmoryUnit = CustomizeManager.UpdatedUnitState;
	foreach PoolMgr.CharacterPool(CPUnit, i)
	{
		if (ArmoryUnit.kAppearance.iGender != CPUnit.kAppearance.iGender)
			continue;

		if (ArmoryUnit.UnitSize != CPUnit.UnitSize)
			continue;

		if (ArmoryUnit.UnitHeight != CPUnit.UnitHeight)
			continue;

		UniformIndices.AddItem(i);
	}
	
	for (i = 0; i < UniformIndices.Length; ++i)
	{
		GetListItem(i).UpdateDataDescription(PoolMgr.GetUnitFullNameExtraData(i));
	}
	List.OnItemClicked = UnitClicked;
}

simulated function UnitClicked(UIList ContainerList, int ItemIndex)
{
	local XComGameState_Unit CPUnit;
	local TAppearance AppearanceToCopy;

	CPUnit = PoolMgr.CharacterPool[UniformIndices[ItemIndex]];
	AppearanceToCopy = CPUnit.kAppearance;

	CopyUniformAppearance(CustomizeManager.UpdatedUnitState.kAppearance, AppearanceToCopy);
	XComHumanPawn(CustomizeManager.ActorPawn).SetAppearance(CustomizeManager.UpdatedUnitState.kAppearance);
	CustomizeManager.UpdatedUnitState.StoreAppearance();

	CustomizeManager.OnCategoryValueChange(eUICustomizeCat_WeaponColor, 0, AppearanceToCopy.iWeaponTint);

	CloseScreen();
}

static function CopyUniformAppearance(out TAppearance NewAppearance, const out TAppearance UniformAppearance)
{
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
	NewAppearance.nmFacePaint = UniformAppearance.nmFacePaint;
}