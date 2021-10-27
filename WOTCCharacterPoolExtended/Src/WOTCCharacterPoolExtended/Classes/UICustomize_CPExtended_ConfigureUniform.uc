class UICustomize_CPExtended_ConfigureUniform extends UICustomize_CPExtended;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	bShowAllCosmeticOptions = true;

	super.InitScreen(InitController, InitMovie, InitName);

	List.Hide();
	ListBG.Hide();
}

simulated function CreateOptionShowAll()
{
	local UIMechaListItem_Button SpawnedItem;

	SpawnedItem = Spawn(class'UIMechaListItem_Button', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem('bShowAllCosmeticOptions'); 
	SpawnedItem.UpdateDataCheckbox("SHOW ALL OPTIONS", "", bShowAllCosmeticOptions, OptionCheckboxChanged, none); // TODO: Localize
	SpawnedItem.SetDisabled(true);
}

simulated function CreateFiltersList() {}
simulated function UpdateSoldierList() {}

simulated function UpdateOptionsList()
{
	super.UpdateOptionsList();

	SetCheckboxPositions();
}

simulated private function SetCheckboxPositions()
{
	local array<CosmeticOptionStruct>	CosmeticOptions;
	local CosmeticOptionStruct			CosmeticOption;
	local CheckboxPresetStruct			CheckboxPreset;

	CosmeticOptions = PoolMgr.GetCosmeticOptionsForUnit(ArmoryUnit, GetGenderArmorTemplate());
	if (CosmeticOptions.Length != 0)
	{
		`CPOLOG("Loading CosmeticOptions for unit" @ CosmeticOptions.Length);
		foreach CosmeticOptions(CosmeticOption)
		{
			`CPOLOG(`showvar(CheckboxPreset.OptionName) @ `showvar(CheckboxPreset.bChecked));
			SetCheckbox(CosmeticOption.OptionName, CosmeticOption.bChecked);
		}
	}
	else
	{
		`CPOLOG("No cosmetic options for this unit, loading uniform defaults");
		foreach class'UICustomize_CPExtended'.default.CheckboxPresets(CheckboxPreset)
		{
			if (CheckboxPreset.Preset == 'PresetUniform')
			{
				`CPOLOG(`showvar(CheckboxPreset.OptionName) @ `showvar(CheckboxPreset.bChecked));
				SetCheckbox(CheckboxPreset.OptionName, CheckboxPreset.bChecked);
			}
		}
	}
}

simulated function OptionCheckboxChanged(UICheckbox CheckBox)
{
	super.OptionCheckboxChanged(CheckBox);

	SaveCosmeticOptions();
}

simulated function CloseScreen()
{	
	SaveCosmeticOptions();
	super.CloseScreen();
}

simulated function SaveCosmeticOptions()
{
	local array<CosmeticOptionStruct>	CosmeticOptions;
	local CosmeticOptionStruct			CosmeticOption;
	local UIMechaListItem				ListItem;
	local int i;

	for (i = 1; i < OptionsList.ItemCount; i++) // Skip 0th member that is for sure "ShowAllCosmetics"
	{
		ListItem = UIMechaListItem(OptionsList.GetItem(i));
		if (ListItem == none || ListItem.Checkbox == none || !IsCosmeticOption(ListItem.MCName))
			continue;

		`CPOLOG(i @ "List item:" @ ListItem.MCName @ ListItem.Desc.htmlText @ "Checked:" @ ListItem.Checkbox.bChecked);

		CosmeticOption.OptionName = ListItem.MCName;
		CosmeticOption.bChecked = ListItem.Checkbox.bChecked;
		CosmeticOptions.AddItem(CosmeticOption);
	}

	PoolMgr.SaveCosmeticOptionsForUnit(CosmeticOptions, ArmoryUnit, GetGenderArmorTemplate());
}

// Exclude presets and category checkboxes
simulated function bool IsCosmeticOption(const name OptionName)
{
	switch(OptionName)
	{
		case'nmHead': return true;
		case'iGender': return true;
		case'iRace': return true;
		case'nmHaircut': return true;
		case'iHairColor': return true;
		case'iFacialHair': return true;
		case'nmBeard': return true;
		case'iSkinColor': return true;
		case'iEyeColor': return true;
		case'nmFlag': return true;
		case'iVoice': return true;
		case'iAttitude': return true;
		case'iArmorDeco': return true;
		case'iArmorTint': return true;
		case'iArmorTintSecondary': return true;
		case'iWeaponTint': return true;
		case'iTattooTint': return true;
		case'nmWeaponPattern': return true;
		case'nmPawn': return true;
		case'nmTorso': return true;
		case'nmArms': return true;
		case'nmLegs': return true;
		case'nmHelmet': return true;
		case'nmEye': return true;
		case'nmTeeth': return true;
		case'nmFacePropLower': return true;
		case'nmFacePropUpper': return true;
		case'nmPatterns': return true;
		case'nmVoice': return true;
		case'nmLanguage': return true;
		case'nmTattoo_LeftArm': return true;
		case'nmTattoo_RightArm': return true;
		case'nmScars': return true;
		case'nmTorso_Underlay': return true;
		case'nmArms_Underlay': return true;
		case'nmLegs_Underlay': return true;
		case'nmFacePaint': return true;
		case'nmLeftArm': return true;
		case'nmRightArm': return true;
		case'nmLeftArmDeco': return true;
		case'nmRightArmDeco': return true;
		case'nmLeftForearm': return true;
		case'nmRightForearm': return true;
		case'nmThighs': return true;
		case'nmShins': return true;
		case'nmTorsoDeco': return true;
		case'bGhostPawn': return true;
	default:
		return false;
	}
}


/*


simulated private function CreateOptionPresets()
{
	local string strFriendlyPresetName;
	local UIMechaListItem SpawnedItem;
	local int i;

	if (Presets.Length == 0)
		return;

	SpawnedItem = Spawn(class'UIMechaListItem', OptionsList.itemContainer);
	SpawnedItem.bAnimateOnInit = false;
	SpawnedItem.InitListItem(); 
	SpawnedItem.SetDisabled(true);
	SpawnedItem.UpdateDataDescription(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset));

	`CPOLOG(GetFuncName() @ `showvar(CurrentPreset));

	for (i = 0; i < Presets.Length; i++)
	{
		strFriendlyPresetName = Localize("UICustomize_CPExtended", string(Presets[i]), "WOTCCharacterPoolExtended");
		if (strFriendlyPresetName == "")
			strFriendlyPresetName = string(Presets[i]);

		CreateOptionPreset(Presets[i], strFriendlyPresetName, "", CurrentPreset == Presets[i]);
	}

	if (PoolMgr.IsUnitUniform(ArmoryUnit))
	{
		CreateOptionPreset(ConfigureUniformPreset, "Configure Uniform", "", CurrentPreset == ConfigureUniformPreset); // TODO: Localize
	}
}
simulated private function ApplyPresetCheckboxPositions()
{
	local array<CosmeticOptionStruct>	CosmeticOptions;
	local CosmeticOptionStruct			CosmeticOption;

	CosmeticOptions = PoolMgr.GetCosmeticOptionsForUnit(ArmoryUnit, GetGenderArmorTemplate());
	foreach CosmeticOptions(CosmeticOption)
	{
		SetCheckbox(CosmeticOption.OptionName, CosmeticOption.bChecked);
	}
}*/