class UICharacterPool_ListPools_CPExtended extends UICharacterPool_ListPools;

var private CPUnitData UnitData; // Current pool we're exporting into or importing from.

var private config(CharacterPoolExtended_NULLCONFIG) array<string> PoolFileNames; // List of all pools added previously.

var private array<string> ReadFailPoolFileNames; // List of pools that couldn't be read from the disk. 

// ============================================================================
// OVERRIDDEN CHARACTER POOL MANAGER FUNCTIONS


simulated function UpdateData( bool _bIsExporting )
{
	bIsExporting = _bIsExporting; 

	if( bIsExporting )
	{
		TitleHeader.SetText(m_strTitle, m_strExportSubtitle);
		Data = GetListOfPools(); 
	}
	else
	{
		if( bHasSelectedImportLocation )
		{
			TitleHeader.SetText(m_strTitleImportPoolCharacter, SelectedFriendlyName);
			Data = GetListOfImportableUnitsFromSelectedPool();
		}
		else
		{
			TitleHeader.SetText(m_strTitleImportPoolLocation, m_strImportSubtitle);
			Data = GetListOfPools();
		}
	}

	List.OnItemClicked = OnClickLocal;
	
	UpdateDisplay();
}

simulated function DoExportCharacters(string FilenameForExport)
{
	local int i;
	local XComGameState_Unit ExportUnit;
	
	//Copy out each character
	for (i = 0; i < UnitsToExport.Length; i++)
	{
		ExportUnit = UnitsToExport[i];
		if (ExportUnit == None)
			continue;

		UnitData.UpdateOrAddUnit(ExportUnit);
	}

	//Save it
	if (SaveCurrentlyOpenPool())
	{	
		ExportSuccessDialogue();
	}
	else
	{
		ShowInfoPopup("ERROR!", "Warning! Failed to write the pool to the disk.", eDialog_Warning);
	}
}

simulated function OnClickLocal(UIList _list, int iItemIndex)
{
	// If we're exporting, the soldiers to be exported are already selected in UICharacterPool,
	// and written into 'UnitsToExport' array, so the only thing left to do is select the pool to export into.
	if (bIsExporting)
	{
		if (iItemIndex == 0) //Request to create a new pool 
		{
			AddNewPoolInputBox();
		}
		else
		{
			// Player selected an existing pool
			if (LoadPool(PoolFileNames[iItemIndex-1]))
			{
				SelectedFilename = PoolFileNames[iItemIndex-1];
				SelectedFriendlyName = SelectedFilename;

				OnExportCharacters();
			}
			else
			{
				ShowInfoPopup("ERROR!", "Warning! Failed to read pool from the disk.", eDialog_Warning);
			}
		}
	}
	else // If we're importing, the player has to select the pool to import from, and then a specific soldier, or the 'import all' option.
	{
		if (!bHasSelectedImportLocation) // Select pool to import to.
		{
			if (iItemIndex == 0) //Request to create a new pool 
			{
				AddNewPoolInputBox();
			}
			else
			{
				if (LoadPool(PoolFileNames[iItemIndex-1]))
				{
					bHasSelectedImportLocation = true; 
					SelectedFilename = PoolFileNames[iItemIndex-1];
					SelectedFriendlyName = SelectedFilename;

					UpdateData(false); // We're not exporting
				}
				else
				{
					ShowInfoPopup("ERROR!", "Warning! Failed to read pool from the disk.", eDialog_Warning);
				}				
			}
		}	
		else
		{
			if (iItemIndex == 0) //"all" case
				DoImportAllCharacters(SelectedFilename);
			else
				DoImportCharacter(SelectedFilename, iItemIndex-1);

			bHasSelectedImportLocation = false;  // This will allow us to exit the screen 
			OnCancel();
		}
	}
}

simulated function DoImportCharacter(string FilenameForImport, int IndexOfCharacter)
{
	local CharacterPoolManagerExtended	CharacterPool;
	local CharacterPoolDataElement		CPData;
	local XComGameState_Unit			NewUnitState;

	CharacterPool = CharacterPoolManagerExtended(`CHARACTERPOOLMGR);
	CPData = UnitData.CharacterPoolDatas[IndexOfCharacter].CharacterPoolData;
	
	NewUnitState = CharacterPool.CreateSoldier(CPData.CharacterTemplateName);
	if (NewUnitState == none)
	{
		ShowInfoPopup("ERROR!", "Failed to import unit" @ CPData.strFirstName @ CPData.strLastName @ "with character template:" @ CPData.CharacterTemplateName @ ", maybe you're mising a mod?", eDialog_Warning);
		return; 
	}
	
	CharacterPool.InitSoldierOld(NewUnitState, CPData);
	NewUnitState.AppearanceStore = UnitData.CharacterPoolDatas[IndexOfCharacter].AppearanceStore;

	CharacterPool.CharacterPool.AddItem(NewUnitState);
	CharacterPool.SaveCharacterPool();
}

simulated function DoImportAllCharacters(string FilenameForImport)
{
	local int i;

	for (i = 0; i < UnitData.CharacterPoolDatas.Length; i++)
	{
		DoImportCharacter("", i);
	}
}

simulated function UpdateDisplay()
{
	local UIMechaListItem SpawnedItem;
	local int i;

	if(List.itemCount > Data.length)
		List.ClearItems();

	while (List.itemCount < Data.length)
	{
		SpawnedItem = Spawn(class'UIMechaListItem', List.itemContainer);
		SpawnedItem.bAnimateOnInit = false;
		SpawnedItem.InitListItem();
	}
	
	// Display delete buttons on pools except the first one
	for( i = 0; i < Data.Length; i++ )
	{
		if (((!bHasSelectedImportLocation || bIsExporting) && i != 0) && !`ISCONTROLLERACTIVE)
		{
			UIMechaListItem(List.GetItem(i)).UpdateDataButton(Data[i], class'UISaveLoadGameListItem'.default.m_sDeleteLabel, OnDeletePool);
		}
		else
		{
			UIMechaListItem(List.GetItem(i)).UpdateDataValue(Data[i], "");
		}
	}
}

simulated function OnDeletePool(UIButton Button)
{
	local int Index;

	Index = List.GetItemIndex(Button);

	if(Index != INDEX_NONE)
	{
		Index -= 1;
		SelectedFilename = PoolFileNames[Index];
		SelectedFriendlyName = SelectedFilename;
		OnConfirmDeletePool();
	}
}

simulated function OnConfirmDeletePool()
{
	local XGParamTag        kTag;
	local TDialogueBoxData  DialogData;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = SelectedFilename;

	DialogData.strTitle = m_strDeletePoolDialogueTitle;
	DialogData.strText = `XEXPAND.ExpandString(m_strDeletePoolDialogueBody);
	DialogData.fnCallback = OnConfirmDeletePoolCallback;

	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	DialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNo;

	Movie.Pres.UIRaiseDialog(DialogData);
}

simulated public function OnConfirmDeletePoolCallback(Name eAction)
{
	local CharacterPoolManager CharacterPool;

	if (eAction == 'eUIAction_Accept')
	{
		CharacterPool = new class'CharacterPoolManager';
		CharacterPool.PoolFileName = "CharacterPool\\CharacterPoolExtended\\" $ SelectedFilename $ ".bin";
		CharacterPool.DeleteCharacterPool();

		PoolFileNames.RemoveItem(SelectedFilename);
		default.PoolFileNames = PoolFileNames;
		SaveConfig();
		SelectedFilename = "";

		UpdateData(bIsExporting);
	}
}

/*
simulated function DoImportAllCharacters(string FilenameForImport)
{
	local CharacterPoolManagerExtended	CharacterPool;
	local CharacterPoolDataElement		CPData;
	local XComGameState_Unit			NewUnitState;
	local int i;

	CharacterPool = CharacterPoolManagerExtended(`CHARACTERPOOLMGR);
	
	for (i = 0; i < UnitData.CharacterPoolDatas.Length; i++)
	{
		CPData = UnitData.CharacterPoolDatas[i].CharacterPoolData;
		NewUnitState = CharacterPool.CreateSoldier(CPData.CharacterTemplateName);
		if (NewUnitState == none)
		{
			ShowInfoPopup("ERROR!", "Failed to import unit" @ CPData.strFirstName @ CPData.strLastName @ "with character template:" @ CPData.CharacterTemplateName @ ", maybe you're mising a mod?", eDialog_Warning);
			continue; 
		}
	
		CharacterPool.InitSoldierOld(NewUnitState, CPData);
		NewUnitState.AppearanceStore = UnitData.CharacterPoolDatas[i].AppearanceStore;
		CharacterPool.CharacterPool.AddItem(NewUnitState);
	}
	CharacterPool.SaveCharacterPool();
}
*/
private function OnAddNewPoolInputBoxAccepted(string strFileName)
{
	local CPUnitData NewUnitData;

	if (string(name(strFileName)) != strFileName)
	{
		ShowInfoPopup("Warning!", "Illegal characters in the filename. Please use only letters and numbers.", eDialog_Alert);
		return;
	}

	if (PoolFileNames.Find(strFileName) != INDEX_NONE)
	{
		// This pool already exists!
		ShowInfoPopup("Warning!", "A pool with this filename already exists in the list. Aborting.", eDialog_Alert);
		return;
	}

	NewUnitData = new class'CPUnitData';
	
	if (class'Engine'.static.BasicLoadObject(NewUnitData, NewUnitData.GetImportPath(strFileName), false, 1))
	{
		// Loaded pool successfully!
		PoolFileNames.AddItem(strFileName);
		default.PoolFileNames = PoolFileNames;
		self.SaveConfig();
		UpdateData(bIsExporting);
		ShowInfoPopup("Importing existing pool", "A pool with this filename already exists. Adding it to the list.");
	}
	else if (class'Engine'.static.BasicSaveObject(NewUnitData, NewUnitData.GetImportPath(strFileName), false, 1))
	{
		// Created new pool successfully!
		PoolFileNames.AddItem(strFileName);
		default.PoolFileNames = PoolFileNames;
		self.SaveConfig();
		UpdateData(bIsExporting);
		ShowInfoPopup("Success", "Created new pool successfully. Adding it to the list.");
	}
	else
	{
		// ERROR! Failed to save pool.
		ShowInfoPopup("ERROR!", "Warning! Failed to write the new pool to the disk.", eDialog_Warning);
	}
}

// ============================================================================
// INTERNAL FUNCTIONS

simulated function array<string> GetListOfPools()
{
	local array<string> Items; 
	local string PoolFileName;

	ReadFailPoolFileNames.Length = 0;
	Items.AddItem("ADD NEW POOL");

	foreach PoolFileNames(PoolFileName)
	{
		if (LoadPool(PoolFileName))
		{
			Items.AddItem(PoolFileName $ ":" @ UnitData.GetNumUnits() @ "units"); // TODO: Localize
		}
		else
		{
			Items.AddItem(PoolFileName @ "FILE ACCESS ERROR!");
			ReadFailPoolFileNames.AddItem(PoolFileName);
		}
	}
	
	return Items; 
}

simulated function array<string> GetListOfImportableUnitsFromSelectedPool()
{
	local array<string> Items; 

	//Items = UnitData.GetUnitsFriendly();
	Items = UnitData.GetUnitsFriendlyExtraData();
	
	if (Items.Length > 0)
	{
		Items.InsertItem(0, m_strImportAll);
	}

	return Items; 
}


private simulated function AddNewPoolInputBox()
{
	local TInputDialogData kData;

	kData.strTitle = "Enter pool file name:";
	kData.iMaxChars = 99;
	kData.strInputBoxText = "CPExtendedImport";
	kData.fnCallbackAccepted = OnAddNewPoolInputBoxAccepted;

	Movie.Pres.UIInputDialog(kData);
}

// ============================================================================
// INTERNAL HELPERS

simulated private function ShowInfoPopup(string strTitle, string strText, optional EUIDialogBoxDisplay eType)
{
	local TDialogueBoxData kDialogData;

	kDialogData.strTitle = strTitle;
	kDialogData.strText = strText;
	kDialogData.eType = eType;
	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericOK;

	Movie.Pres.UIRaiseDialog(kDialogData);
}

simulated private function bool LoadPool(string strFileName)
{
	UnitData = new class'CPUnitData';

	return class'Engine'.static.BasicLoadObject(UnitData, UnitData.GetImportPath(strFileName), false, 1);
}

simulated private function bool SaveCurrentlyOpenPool()
{
	return class'Engine'.static.BasicSaveObject(UnitData, UnitData.GetImportPath(SelectedFilename), false, 1);
}

/*
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);
	ValidatePools();
}

// Attempt to load all previously added pools.
// Delete pools that fail to load from the list.
simulated private function ValidatePools()
{
	local CPUnitData TestUnitData;
	local int i;

	TestUnitData = new class'CPUnitData';
	for (i = PoolFileNames.Length - 1; i >= 0; i--)
	{
		if (!class'Engine'.static.BasicLoadObject(TestUnitData, TestUnitData.GetImportPath(PoolFileNames[i]), false, 1))
		{
			PoolFileNames.Remove(i, 1);
		}
	}
	default.PoolFileNames = PoolFileNames;
	self.SaveConfig();
}*/
/*
simulated function RequiredModsPopups()
{
	local TDialogueBoxData kDialogData;
	local array<ModDependencyData> ModsWithMissing;
	local ModDependencyData Mod;
	local X2WOTCCH_DialogCallbackData CallbackData;

	ModsWithMissing = DependencyChecker.GetModsWithMissingRequirements();

	foreach ModsWithMissing(Mod)
	{
		if (HideRequiredModWarnings.Find(Mod.SourceName) == INDEX_NONE)
		{
			CallbackData = new class'X2WOTCCH_DialogCallbackData';
			CallbackData.DependencyData = Mod;

			kDialogData.strTitle = Mod.ModName @ class'X2WOTCCH_ModDependencies'.default.ModRequiredPopupTitle;
			kDialogData.eType = eDialog_Warning;
			kDialogData.strText = GetRequiredModsText(Mod);
			kDialogData.fnCallbackEx = RequiredModsCB;
			kDialogData.strAccept = class'X2WOTCCH_ModDependencies'.default.DisablePopup;
			kDialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericAccept;
			kDialogData.xUserData = CallbackData;

			`LOG(kDialogData.strText,, 'X2WOTCCommunityHighlander');

			`PRESBASE.UIRaiseDialog(kDialogData);
		}
	}
}*/

/*
	eDialog_Normal, //cyan
	eDialog_NormalWithImage, //cyan with image
	eDialog_Warning, //red
	eDialog_Alert   //yellow
*/
/*
	foreach SelectedCharacters(SelectedCharacter)
	{
		ExportUnitData.UpdateOrAddUnit(SelectedCharacter);
	}
	*/

/*
simulated function UpdateData( bool _bIsExporting )
{
	bIsExporting = _bIsExporting; 

	// TODO: Figure out why this title is wrong
	`LOG(`showvar(m_strTitleImportPoolCharacter) @ `showvar(SelectedFriendlyName),, 'IRITESTSCREEN');

	TitleHeader.SetText(m_strTitleImportPoolCharacter, SelectedFriendlyName);

	Data = GetUnitImportList();

	List.OnItemClicked = OnClickLocal;
	
	UpdateDisplay();
}
*/
/*
simulated function bool DoMakeEmptyPool(string NewFriendlyName)
{
	local CharacterPoolManagerExtended ExportPool;
	local string FullFileName;

	local array<string> FriendlyNames;
	local array<string> FileNames;
	local string PrintString;

	FullFileName = CharacterPoolManagerExtended(CharacterPoolMgr).ImportDirectoryName $ "\\" $ NewFriendlyName $ ".bin";

	if(EnumeratedFilenames.Find(FullFileName) != INDEX_NONE)
		return false;

	ExportPool = new class'CharacterPoolManagerExtended';
	ExportPool.ImportDirectoryName = "CharacterPool\\CharacterPoolExtended";
	ExportPool.default.ImportDirectoryName = "CharacterPool\\CharacterPoolExtended";

	ExportPool.EnumerateImportablePools(FriendlyNames, FileNames);

	`LOG("BEGIN CP PRINT",, 'IRITEST');
	foreach FriendlyNames(PrintString)
	{
		`LOG(PrintString,, 'IRITEST');
	}
	foreach FileNames(PrintString)
	{
		`LOG(PrintString,, 'IRITEST');
	}
	`LOG("END CP PRINT",, 'IRITEST');

	ExportPool.CharPoolExtendedFilePath = FullFileName;
	ExportPool.SaveCharacterPoolExtended();
	return true;
}
*/

/*
local TInputDialogData kData;

	kData.strTitle = "Enter pool file name";
	kData.iMaxChars = 99;
	kData.strInputBoxText = "CPExtendedImport";
	kData.fnCallback = OnCPE_ImportInputBoxAccepted;

	Movie.Pres.UIInputDialog(kData);

function OnCPE_ImportInputBoxAccepted(string strFileName)
{
	local CPUnitData							ImportUnitData;
	local UICharacterPool_ListPools_CPExtended	ImportUnitsScreen;

	ImportUnitData = new class'CPUnitData';
	
	if (class'Engine'.static.BasicLoadObject(ImportUnitData, ImportUnitData.GetImportPath(strFileName), false, 1))
	{
		

		SelectedCharacters.Length = 0;
	}
	else
	{
		// TODO: Popup failed to load CP
	}
}

local TInputDialogData kData;

	if(bAnimateOut) return;

	if (SelectedCharacters.Length > 0)
	{
		kData.strTitle = "Enter pool file name";
		kData.iMaxChars = 99;
		kData.strInputBoxText = "CPExtendedImport";
		kData.fnCallback = OnCPE_ExportInputBoxAccepted;

		Movie.Pres.UIInputDialog(kData);
	}

function OnCPE_ExportInputBoxAccepted(string strFileName)
{
	local CPUnitData ExportUnitData;
	local XComGameState_Unit SelectedCharacter;

	ExportUnitData = new class'CPUnitData';
	
	if (class'Engine'.static.BasicLoadObject(ExportUnitData, ExportUnitData.GetImportPath(strFileName), false, 1))
	{
		// TODO: Ask: Update, Replace, Cancel?
	}

	foreach SelectedCharacters(SelectedCharacter)
	{
		ExportUnitData.UpdateOrAddUnit(SelectedCharacter);
	}

	if (class'Engine'.static.BasicSaveObject(ExportUnitData, ExportUnitData.GetImportPath(strFileName), false, 1))
	{
		// TODO: Saved success popup with filepath
	}
	else
	{
		// TODO: Failed to save
	}
}
*/