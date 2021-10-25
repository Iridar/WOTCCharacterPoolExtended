class UICharacterPool_ListPools_CPExtended extends UICharacterPool_ListPools;

// This screen is used for:
// 1. Displaying the list of "extended" Character Pool files that can be imported from or exported into.
// 2. Creating new CP files.
// 3. Importing units from "extended" CP files.

// This screen can work with CP files located in:
// 1. CharacterPoolExtended folder in Documents.
// 2. Content folders of mods that add new character pool files.

struct PoolInfoStruct
{
	// This data must be filled by mods that add new CP files.
	var name DLCName;		// Name of the .XComMod file that contains the mod-added character pool, used to find its Content folder.
	var name PoolName;		// Name of the .bin character pool file.

	// This data is filled automatically by this mod.
	var string FilePath;	// Full path to the .bin character pool file.

	// Display name for this character pool file in the in-game UI. Read from 'WOTCCharacterPoolExtended.*' localization files and then stored here.
	// Alternatively, can be specified directly by the mod in config.
	var string FriendlyName;
};
// Mods should use this array to add their character pool files. Examply entry:
// +DefaultCharacterPoolFiles = (DLCName = "WOTCCharacterPoolTest", PoolName = "ModAddedPool")
var private config(WOTCCharacterPoolExtended_DEFAULT) array<PoolInfoStruct> DefaultCharacterPoolFiles;

// Array of all character pool files this mod has access to, both for mod-added pools and player-created ones.
// Cached and validated on this screen's Init
var private config(WOTCCharacterPoolExtended) array<PoolInfoStruct> CharacterPoolFiles;

// Default path for storing player-created character pool files.
const PlayerPoolFileImportFolderPath = "\\Documents\\my games\\XCOM2 War of the Chosen\\XComGame\\CharacterPool\\CharacterPoolExtended\\";

// Current pool we're exporting into or importing from.
var private CPUnitData		UnitData; 
var private PoolInfoStruct	CurrentPoolInfo;

// ============================================================================
// OVERRIDDEN CHARACTER POOL MANAGER FUNCTIONS

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);
	BuildCharacterPoolFilesList();
}

simulated private function BuildCharacterPoolFilesList()
{
	local PoolInfoStruct PoolInfo;
	local int Index;

	`CPOLOG("Building character pool files. Default pools:" @ DefaultCharacterPoolFiles.Length $ ", cached pools:" @ CharacterPoolFiles.Length);

	foreach DefaultCharacterPoolFiles(PoolInfo)
	{		
		`CPOLOG("Default pool:" @ GeneratePoolText(PoolInfo));
		if (PoolInfo.PoolName == '')
		{
			`CPOLOG("This default pool is invalid: no PoolName specified. Skipping.");
		}

		Index = CharacterPoolFiles.Find('PoolName', PoolInfo.PoolName);
		if (Index != INDEX_NONE)
		{	
			if (LoadPool(CharacterPoolFiles[Index]))
			{
				`CPOLOG("This pool was already cached and can be loaded, skipping to the next default pool");
				continue;
			}
			else
			{
				`CPOLOG("This pool was already cached, but canoot be loaded currently.");
				`CPOLOG("Cached pool:" @ GeneratePoolText(CharacterPoolFiles[Index]));
			}
		}

		if (PoolInfo.DLCName != '')
		{
			if (FillDLCPoolFilePathAndValidate(PoolInfo))
			{
				FillPoolFriendlyName(PoolInfo);
				CharacterPoolFiles.AddItem(PoolInfo);
				`CPOLOG("Caching mod-added pool:" @ GeneratePoolText(PoolInfo));
			}
			else `CPOLOG("Error: failed to read mod-added pool file from disk.");
		}
		else
		{
			if (FillPlayerPoolFilePathAndValidate(PoolInfo))
			{	
				FillPoolFriendlyName(PoolInfo);
				CharacterPoolFiles.AddItem(PoolInfo);
				`CPOLOG("Caching player-added pool:" @ GeneratePoolText(PoolInfo));
			}
			else `CPOLOG("Error: failed to read player-added pool file from disk.");
		}
	}
	default.CharacterPoolFiles = CharacterPoolFiles;
	SaveConfig();
}

simulated private function bool FillDLCPoolFilePathAndValidate(out PoolInfoStruct PoolInfo)
{
	local DownloadableContentEnumerator DLCEnum;
	local OnlineContent Item;

	DLCEnum = class'Engine'.static.GetEngine().GetDLCEnumerator();

	foreach DLCEnum.DLCBundles(Item)
	{	
		if (Item.Filename == string(PoolInfo.DLCName))
		{
			PoolInfo.FilePath = Item.ContentPath $ "\\Content\\" $ PoolInfo.PoolName $ ".bin";
			PoolInfo.FilePath = Repl(PoolInfo.FilePath, "\\", "\\\\");
			`CPOLOG("Generated mod-added pool path:" @ PoolInfo.FilePath);
			return LoadPool(PoolInfo);
		}
	}
	return false;
}

simulated private function string GeneratePoolText(const PoolInfoStruct PoolInfo)
{
	return `showvar(PoolInfo.DLCName) @ `showvar(PoolInfo.PoolName) @ `showvar(PoolInfo.FilePath) @ `showvar(PoolInfo.FriendlyName);
}

simulated private function bool FillPlayerPoolFilePathAndValidate(out PoolInfoStruct PoolInfo)
{
	PoolInfo.FilePath = class'Engine'.static.GetEnvironmentVariable("USERPROFILE") $ PlayerPoolFileImportFolderPath $ PoolInfo.PoolName $ ".bin";

	`CPOLOG("Generated player-added pool path:" @ PoolInfo.FilePath);

	return LoadPool(PoolInfo);
}

simulated function UpdateData( bool _bIsExporting )
{
	bIsExporting = _bIsExporting; 
	
	`CPOLOG(GetFuncName() @ `showvar(bIsExporting));

	if (bIsExporting)
	{
		TitleHeader.SetText(m_strTitle, m_strExportSubtitle);
		Data = GetListOfPools(); 
	}
	else
	{
		if (bHasSelectedImportLocation)
		{
			TitleHeader.SetText(m_strTitleImportPoolCharacter, CurrentPoolInfo.FriendlyName);
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
		ShowInfoPopup("ERROR!", "Warning! Failed to write the pool to the disk.\n\n" @ GeneratePoolText(CurrentPoolInfo), eDialog_Warning);
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
			if (LoadPool(CharacterPoolFiles[iItemIndex-1]))
			{
				CurrentPoolInfo = CharacterPoolFiles[iItemIndex-1];
				OnExportCharacters();
			}
			else
			{
				ShowInfoPopup("ERROR!", "Warning! Failed to read pool from the disk.\n\n" @ GeneratePoolText(CurrentPoolInfo), eDialog_Warning);
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
				if (LoadPool(CharacterPoolFiles[iItemIndex-1]))
				{
					bHasSelectedImportLocation = true; 
					CurrentPoolInfo = CharacterPoolFiles[iItemIndex-1];

					UpdateData(false); // We're not exporting
				}
				else
				{
					ShowInfoPopup("ERROR!", "Warning! Failed to read pool from the disk.\n\n" @ GeneratePoolText(CurrentPoolInfo), eDialog_Warning);
				}				
			}
		}	
		else
		{
			if (iItemIndex == 0) //"all" case
				DoImportAllCharacters("");
			else
				DoImportCharacter("", iItemIndex-1);

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
	//TODO: Maybe create soldier instead to attempt to salvage appearance?
	
	CharacterPool.InitSoldierOld(NewUnitState, CPData);
	//NewUnitState.AppearanceStore = UnitData.CharacterPoolDatas[IndexOfCharacter].AppearanceStore;
	UnitData.LoadExtraData(NewUnitState); // This will copy Appearance Store and some other stuff.

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
		SpawnedItem.InitListItem(,, 340); // Give more room to the text
	}
	
	// Display delete buttons on pools except the first one, since the first one is "add new pool" option.
	// Also not adding a delete button to mod-added pools, since deleting them would be weird and pointless even if we could.
	for (i = 0; i < Data.Length; i++)
	{
		if (((!bHasSelectedImportLocation || bIsExporting) && i != 0 && CharacterPoolFiles[i-1].DLCName == '') && !`ISCONTROLLERACTIVE)
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

	if (Index != INDEX_NONE)
	{
		Index -= 1;
		CurrentPoolInfo = CharacterPoolFiles[Index];
		OnConfirmDeletePool();
	}
}

simulated function OnConfirmDeletePool()
{
	local XGParamTag        kTag;
	local TDialogueBoxData  DialogData;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = CurrentPoolInfo.FriendlyName;

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
	local PoolInfoStruct EmptyPoolInfo;

	if (eAction == 'eUIAction_Accept')
	{
		CharacterPool = new class'CharacterPoolManager';
		CharacterPool.PoolFileName = "CharacterPool\\CharacterPoolExtended\\" $ CurrentPoolInfo.PoolName $ ".bin";
		CharacterPool.DeleteCharacterPool();

		CharacterPoolFiles.RemoveItem(CurrentPoolInfo);
		default.CharacterPoolFiles = CharacterPoolFiles;
		SaveConfig();
		CurrentPoolInfo = EmptyPoolInfo;

		UpdateData(bIsExporting);
	}
}

private function OnAddNewPoolInputBoxAccepted(string strPoolName)
{
	local PoolInfoStruct	NewPoolInfo;
	local int				Index;

	NewPoolInfo.PoolName = name(strPoolName);

	// Check if the pool is already in the list.
	Index = CharacterPoolFiles.Find('PoolName', NewPoolInfo.PoolName);
	if (Index != INDEX_NONE && LoadPool(CharacterPoolFiles[Index]))
	{
		ShowInfoPopup("Warning!", "A pool with this filename already exists in the list. Aborting.", eDialog_Alert);
		return;
	}

	if (FillPlayerPoolFilePathAndValidate(NewPoolInfo))
	{
		// Loaded existing pool successfully!
		FillPoolFriendlyName(NewPoolInfo);
		CharacterPoolFiles.AddItem(NewPoolInfo);
		default.CharacterPoolFiles = CharacterPoolFiles;
		self.SaveConfig();
		UpdateData(bIsExporting);
		ShowInfoPopup("Importing existing pool", "A pool with this filename already exists. Adding it to the list.");
		
	}
	else 
	{
		CurrentPoolInfo = NewPoolInfo;
		if (SaveCurrentlyOpenPool())
		{
			// Created new pool successfully!
			
			FillPoolFriendlyName(NewPoolInfo);
			CharacterPoolFiles.AddItem(NewPoolInfo);
			default.CharacterPoolFiles = CharacterPoolFiles;
			self.SaveConfig();
			UpdateData(bIsExporting);
			ShowInfoPopup("Success", "Created new pool successfully. Adding it to the list.");
		}
		else
		{
			// ERROR! Failed to save pool.
			ShowInfoPopup("ERROR!", "Warning! Failed to write the new pool to the disk.\n\n" @ GeneratePoolText(CurrentPoolInfo), eDialog_Warning);
		}
	}
}

// ============================================================================
// INTERNAL FUNCTIONS

simulated private function FillPoolFriendlyName(out PoolInfoStruct PoolInfo)
{
	PoolInfo.FriendlyName = Localize("UICharacterPool_ListPools_CPExtended", string(PoolInfo.PoolName), "WOTCCharacterPoolExtended");
	if (Left(PoolInfo.FriendlyName, 5) == "?INT?") // Failed to read localized value.
		PoolInfo.FriendlyName = string(PoolInfo.PoolName);
	
}

simulated function array<string> GetListOfPools()
{
	local array<string> Items; 
	local PoolInfoStruct PoolInfo;

	Items.AddItem("ADD NEW POOL"); // TODO: Localize

	foreach CharacterPoolFiles(PoolInfo)
	{
		if (LoadPool(PoolInfo))
		{	
			Items.AddItem(PoolInfo.FriendlyName $ ":" @ UnitData.GetNumUnits() @ "units"); // TODO: Localize
		}
		else
		{
			Items.AddItem(PoolInfo.FriendlyName @ "FILE ACCESS ERROR!");
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
	kData.strInputBoxText = "CPOverhaulImport";
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

simulated private function bool LoadPool(PoolInfoStruct PoolInfo)
{
	UnitData = new class'CPUnitData';

	return class'Engine'.static.BasicLoadObject(UnitData, PoolInfo.FilePath, false, 1);
}

simulated private function bool SaveCurrentlyOpenPool()
{
	return class'Engine'.static.BasicSaveObject(UnitData, CurrentPoolInfo.FilePath, false, 1);
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
		if (!class'Engine'.static.BasicLoadObject(TestUnitData, TestGetImportPath(PoolFileNames[i]), false, 1))
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

			`CPOLOG(kDialogData.strText,, 'X2WOTCCommunityHighlander');

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
	`CPOLOG(`showvar(m_strTitleImportPoolCharacter) @ `showvar(SelectedFriendlyName),, 'IRITESTSCREEN');

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

	`CPOLOG("BEGIN CP PRINT");
	foreach FriendlyNames(PrintString)
	{
		`CPOLOG(PrintString);
	}
	foreach FileNames(PrintString)
	{
		`CPOLOG(PrintString);
	}
	`CPOLOG("END CP PRINT");

	ExportPool.CharPoolExtendedFilePath = FullFileName;
	ExportPool.SaveCharacterPoolExtended();
	return true;
}
*/

/*
local TInputDialogData kData;

	kData.strTitle = "Enter pool file name";
	kData.iMaxChars = 99;
	kData.strInputBoxText = "CPOverhaulImport";
	kData.fnCallback = OnCPE_ImportInputBoxAccepted;

	Movie.Pres.UIInputDialog(kData);

function OnCPE_ImportInputBoxAccepted(string strFileName)
{
	local CPUnitData							ImportUnitData;
	local UICharacterPool_ListPools_CPExtended	ImportUnitsScreen;

	ImportUnitData = new class'CPUnitData';
	
	if (class'Engine'.static.BasicLoadObject(ImportUnitData, ImportGetImportPath(strFileName), false, 1))
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
		kData.strInputBoxText = "CPOverhaulImport";
		kData.fnCallback = OnCPE_ExportInputBoxAccepted;

		Movie.Pres.UIInputDialog(kData);
	}

function OnCPE_ExportInputBoxAccepted(string strFileName)
{
	local CPUnitData ExportUnitData;
	local XComGameState_Unit SelectedCharacter;

	ExportUnitData = new class'CPUnitData';
	
	if (class'Engine'.static.BasicLoadObject(ExportUnitData, ExportGetImportPath(strFileName), false, 1))
	{
		// TODO: Ask: Update, Replace, Cancel?
	}

	foreach SelectedCharacters(SelectedCharacter)
	{
		ExportUnitData.UpdateOrAddUnit(SelectedCharacter);
	}

	if (class'Engine'.static.BasicSaveObject(ExportUnitData, ExportGetImportPath(strFileName), false, 1))
	{
		// TODO: Saved success popup with filepath
	}
	else
	{
		// TODO: Failed to save
	}
}
*/