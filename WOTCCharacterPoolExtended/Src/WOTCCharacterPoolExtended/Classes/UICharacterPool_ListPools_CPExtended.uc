class UICharacterPool_ListPools_CPExtended extends UICharacterPool_ListPools;

var private CPUnitData UnitData; // Current pool we're exporting into or importing from.
var private config(CharacterPoolExtended_NULLCONFIG) array<string> PoolFileNames; // List of all pools added previously.

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
}

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

simulated function array<string> GetListOfPools()
{
	local array<string> Items; 

	Items = PoolFileNames;
	Items.InsertItem(0, "ADD NEW POOL");

	return Items; 
}

simulated function array<string> GetListOfImportableUnitsFromSelectedPool()
{
	local array<string> Items; 

	Items = UnitData.GetUnitsFriendly();
	
	if (Items.Length > 0)
	{
		Items.InsertItem(0, m_strImportAll);
	}

	return Items; 
}

simulated function OnClickLocal(UIList _list, int iItemIndex)
{
	if( bIsExporting )
	{
		if( iItemIndex == 0) //Request to create a new pool 
		{
			// We want a new pool
			AddNewPoolInputBox();
		}
		else
		{
			//TODO @nway: notify the game of the export pool: iItemIndex-1 
			SelectedFilename = EnumeratedFilenames[iItemIndex-1];
			SelectedFriendlyName = Data[iItemIndex];
			// TODO: Confirm export
			`log("EXPORT location selected: " $string(iItemIndex-1) $ ":" $ SelectedFilename);
			OnExportCharacters();
		}
	}
	else
	{
		if( !bHasSelectedImportLocation )
		{
			if( iItemIndex == 0) //Request to create a new pool 
			{
				// We want a new pool
				AddNewPoolInputBox();
			}
			else
			{
				// TODO: Do stuff that will result in printing soldiers available for import
				// (i.e. read selected pool into UnitData
				// We just picked the import location
				bHasSelectedImportLocation = true; 
				SelectedFilename = EnumeratedFilenames[iItemIndex];
				SelectedFriendlyName = Data[iItemIndex];
				`log("IMPORT location selected: " $string(iItemIndex) $ ":" $ SelectedFilename);
				// Then, refresh this screen:
				UpdateData( false );
			}
		}	
		else
		{
			`log("IMPORT character selected: " $ string(iItemIndex));

			if (iItemIndex == 0) //"all" case
				DoImportAllCharacters(SelectedFilename);
			else
				DoImportCharacter(SelectedFilename, iItemIndex-1);

			bHasSelectedImportLocation = false;  // This will allow us to exit the screen 
			OnCancel();
		}
	}
}


simulated function AddNewPoolInputBox()
{
	local TInputDialogData kData;

	kData.strTitle = "Enter pool file name:";
	kData.iMaxChars = 99;
	kData.strInputBoxText = "CPExtendedImport";
	kData.fnCallback = fnCallbackAccepted;

	Movie.Pres.UIInputDialog(kData);
}

function OnAddNewPoolInputBoxClosed(string strFileName)
{
	local CPUnitData NewUnitData;

	// TODO: If cancelled, then?
	//var delegate<TextInputCancelledCallback> fnCallbackCancelled;
	//var delegate<TextInputAcceptedCallback> fnCallbackAccepted;

	if (string(name(strFileName)) != strFileName)
	{
		ShowInfoPopup("Warning!", "Illegal characters in the filename. Please use only letters and numbers.", eDialog_Alert);
		return;
	}

	if (PoolFileNames.Find(strFileName) != INDEX_NONE)
	{
		// TODO: This pool already exists!
		ShowInfoPopup("Warning!", "A pool with this filename already exists in the list. Aborting.", eDialog_Alert);
		return;
	}

	NewUnitData = new class'CPUnitData';
	
	if (class'Engine'.static.BasicLoadObject(NewUnitData, NewUnitData.GetImportPath(strFileName), false, 1))
	{
		// TODO: Loaded pool successfully!
		PoolFileNames.AddItem(strFileName);
		default.PoolFileNames = PoolFileNames;
		self.SaveConfig();
		UpdateData(bIsExporting);
		ShowInfoPopup("Importing existing pool", "A pool with this filename already exists. Adding it to the list.");
	}
	else if (class'Engine'.static.BasicSaveObject(NewUnitData, NewUnitData.GetImportPath(strFileName), false, 1))
	{
		// TODO: Created new pool successfully!
		PoolFileNames.AddItem(strFileName);
		default.PoolFileNames = PoolFileNames;
		self.SaveConfig();
		UpdateData(bIsExporting);
		ShowInfoPopup("Success", "Created new pool successfully. Adding it to the list.");
	}
	else
	{
		// TODO: ERROR! Failed to save pool.
		ShowInfoPopup("ERROR!", "Warning! Failed to write the new pool to the disk.", eDialog_Warning);
	}
}


simulated function ShowInfoPopup(string strTitle, string strText, optional EUIDialogBoxDisplay eType)
{
	local TDialogueBoxData kDialogData;

	kDialogData.strTitle = strTitle;
	kDialogData.strText = strText;
	kDialogData.eType = eType;
	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericOK;

	Movie.Pres.UIRaiseDialog(kDialogData);
}
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