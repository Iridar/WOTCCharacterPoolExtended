class UICharacterPool_CPExtended extends UICharacterPool;

/*
// Just adding a couple of buttons in a third column at the bottom of the CP screen

var UIButton CPE_ImportButton;
var UIButton CPE_ExportButton;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local float RunningY;
	local float RunningYBottom;
	
	super.InitScreen(InitController, InitMovie, InitName);

	// ---------------------------------------------------------

	// Create Container
	Container = Spawn(class'UIPanel', self).InitPanel('').SetPosition(30, 70).SetSize(600, 850);

	// Create BG
	BG = Spawn(class'UIBGBox', Container).InitBG('', 0, 0, Container.width, Container.height);
	BG.SetAlpha( 80 );

	RunningY = 10;
	RunningYBottom = Container.Height - 10;

	// Create Title text
	TitleHeader = Spawn(class'UIX2PanelHeader', Container);
	TitleHeader.InitPanelHeader('', m_strTitle, m_strSubtitle);
	TitleHeader.SetHeaderWidth(Container.width - 20);
	TitleHeader.SetPosition(10, RunningY);
	RunningY += TitleHeader.Height;

	if(Movie.IsMouseActive())
	{
		//Create buttons
		CreateButton = Spawn(class'UIButton', Container);
		CreateButton.ResizeToText = true;
		CreateButton.InitButton('', m_strCreateCharacter, OnButtonCallback, eUIButtonStyle_NONE);
		CreateButton.SetPosition(10, RunningY);
		CreateButton.OnSizeRealized = OnCreateButtonSizeRealized;

		ImportButton = Spawn(class'UIButton', Container);
		ImportButton.InitButton('', m_strImportCharacter, OnButtonCallback, eUIButtonStyle_NONE);
		ImportButton.SetPosition(180, RunningY);

		RunningY += ImportButton.Height + 10;
	}

	//Create bottom buttons
	OptionsList = Spawn(class'UIList', Container);
	OptionsList.InitList('OptionsListMC', 10, RunningYBottom - class'UIMechaListItem'.default.Height, Container.Width - 20, 300, , false);

	RunningYBottom -= class'UIMechaListItem'.default.Height + 10;   

	if (Movie.IsMouseActive())
	{
		ExportButton = Spawn(class'UIButton', Container);
		ExportButton.ResizeToText = true;
		ExportButton.InitButton('', m_strExportSelection, OnButtonCallback, eUIButtonStyle_NONE);
		ExportButton.SetPosition(10, RunningYBottom - ExportButton.Height);
		ExportButton.DisableButton(m_strNothingSelected);
		ExportButton.OnSizeRealized = OnExportButtonSizeRealized;

		DeselectAllButton = Spawn(class'UIButton', Container);
		DeselectAllButton.InitButton('', m_strDeselectAll, OnButtonCallback, eUIButtonStyle_NONE);
		DeselectAllButton.SetPosition(180, RunningYBottom - DeselectAllButton.Height);
		DeselectAllButton.DisableButton(m_strNothingSelected);
		// ADDED
		DeselectAllButton.OnSizeRealized = OnDeselectAllButtonSizeRealized;

		CPE_ExportButton = Spawn(class'UIButton', Container);
		CPE_ExportButton.InitButton('', "CPE" @ m_strExportSelection, OnCPE_ExportButtonCallback, eUIButtonStyle_NONE);
		CPE_ExportButton.SetPosition(10, RunningYBottom - CPE_ExportButton.Height);
		CPE_ExportButton.DisableButton(m_strNothingSelected);
		// END OF ADDED
		RunningYBottom -= ExportButton.Height + 10;

		DeleteButton = Spawn(class'UIButton', Container);
		DeleteButton.ResizeToText = true;
		DeleteButton.InitButton('', m_strDeleteSelection, OnButtonCallback, eUIButtonStyle_NONE);
		DeleteButton.SetPosition(10, RunningYBottom - DeleteButton.Height);
		DeleteButton.DisableButton(m_strNothingSelected);
		DeleteButton.OnSizeRealized = OnDeleteButtonSizeRealized;

		SelectAllButton = Spawn(class'UIButton', Container);
		SelectAllButton.InitButton('', m_strSelectAll, OnButtonCallback, eUIButtonStyle_NONE);
		SelectAllButton.SetPosition(180, RunningYBottom - SelectAllButton.Height);
		SelectAllButton.DisableButton(m_strNoCharacters);

		// ADDED
		SelectAllButton.OnSizeRealized = OnSelectAllButtonSizeRealized;

		CPE_ImportButton = Spawn(class'UIButton', Container);
		CPE_ImportButton.InitButton('',"CPE" @ m_strImportCharacter, CPE_ImportButton_Callback, eUIButtonStyle_NONE);
		CPE_ImportButton.SetPosition(180, RunningYBottom - CPE_ImportButton.Height);
		// END OF ADDED
		RunningYBottom -= DeleteButton.Height + 10;
	}

	List = Spawn(class'UIList', Container);
	List.bAnimateOnInit = false;
	List.InitList('', 10, RunningY, TitleHeader.headerWidth - 20, RunningYBottom - RunningY);
	BG.ProcessMouseEvents(List.OnChildMouseEvent);
	List.bStickyHighlight = true;

	// --------------------------------------------------------

	NavHelp = Spawn(class'UINavigationHelp', self).InitNavHelp();

	// ---------------------------------------------------------

	CharacterPoolMgr = CharacterPoolManager(`XENGINE.GetCharacterPoolManager());

	
	if( `ISCONTROLLERACTIVE )
	{
		m_iCurrentUsage = (`XPROFILESETTINGS.Data.m_eCharPoolUsage);
	}
	else
	{
		// Subtract one b/c NONE first option is skipped when generating the list
		m_iCurrentUsage = (`XPROFILESETTINGS.Data.m_eCharPoolUsage - 1);
	}
	

	// ---------------------------------------------------------
	
	CreateOptionsList();

	// ---------------------------------------------------------
	
	UpdateData();
	
	// ---------------------------------------------------------

	if (InShell()) // Support for entering character pool from Armory
	{
		Hide();
		`XCOMGRI.DoRemoteEvent('StartCharacterPool'); // start a fade
		WorldInfo.RemoteEventListeners.AddItem(self);
		SetTimer(2.0, false, nameof(ForceShow));
	
		bAnimateOut = false;
	}
}

simulated function UpdateEnabledButtons()
{
	super.UpdateEnabledButtons();

	if (SelectedCharacters.Length == 0)
	{
		CPE_ExportButton.DisableButton(m_strNothingSelected);
	}
	else
	{
		CPE_ExportButton.EnableButton();
	}
}

simulated function OnDeselectAllButtonSizeRealized()
{
	CPE_ExportButton.SetX(DeselectAllButton.X + DeselectAllButton.Width + 10);
}

simulated function OnSelectAllButtonSizeRealized()
{
	CPE_ImportButton.SetX(SelectAllButton.X + SelectAllButton.Width + 10);
}

simulated function CPE_ImportButton_Callback(UIButton kButton)
{
	local UICharacterPool_ListPools_CPExtended ListPools;

	if(bAnimateOut) return;

	ListPools = UICharacterPool_ListPools_CPExtended(PC.Pres.ScreenStack.Push(Spawn(class'UICharacterPool_ListPools_CPExtended', PC.Pres)));
	ListPools.UpdateData(false); // Is exporting?
}

simulated private function OnCPE_ExportButtonCallback(UIButton kButton)
{
	local UICharacterPool_ListPools_CPExtended ListPools;

	if(bAnimateOut) return;

	if (SelectedCharacters.Length > 0)
	{	
		ListPools = UICharacterPool_ListPools_CPExtended(PC.Pres.ScreenStack.Push(Spawn(class'UICharacterPool_ListPools_CPExtended', PC.Pres)));
		ListPools.UnitsToExport = SelectedCharacters;
		ListPools.UpdateData(true); // Is exporting?
	}
}
*/

// Sort the displayed list of soldiers and display more info.
simulated function array<string> GetCharacterNames()
{
	local array<string> CharacterNames; 
	local int i; 
	
	local XComGameState_Unit Soldier;
	local string soldierName;

	CharacterPoolManagerExtended(CharacterPoolMgr).SortCharacterPoolBySoldierName();
	CharacterPoolManagerExtended(CharacterPoolMgr).SortCharacterPoolBySoldierClass();
	
	for( i = 0; i < CharacterPoolMgr.CharacterPool.Length; i++ )
	{
		Soldier = CharacterPoolMgr.CharacterPool[i];

		// Display soldier class name in front of the name.
		if (Soldier.GetSoldierClassTemplate() != none)
		{
			soldierName = Soldier.GetSoldierClassTemplate().DisplayName $ ": ";
		}
		else soldierName = "";


		if( Soldier.GetNickName() != "" )
			soldierName $= Soldier.GetFirstName() @ Soldier.GetNickName() @ Soldier.GetLastName();
		else
			soldierName $= Soldier.GetFirstName() @ Soldier.GetLastName();

		CharacterNames.AddItem(soldierName);
	}
	return CharacterNames; 
}


// Wanted to add some extra data about the unit and put it into parallel array, but we can't expect every mod and UI Screen to do that for us.
// Will be handled in CreateSoldier() itself.
/*
simulated function OnButtonCallbackCreateNew()
{
	local XComGameState_Unit		NewSoldierState;
	local CPExtendedExtraDataStruct	NewCPExtraData; // Added

	NewSoldierState = CharacterPoolMgr.CreateSoldier('Soldier');

	NewSoldierState.PoolTimestamp = class'X2StrategyGameRulesetDataStructures'.static.GetSystemDateTimeString();
	CharacterPoolMgr.CharacterPool.AddItem(NewSoldierState);

	// Added
	NewCPExtraData.ObjectID = NewSoldierState.ObjectID;
	CharacterPoolManagerExtended(CharacterPoolMgr).CPExtraDatas.AddItem(NewCPExtraData);


	PC.Pres.UICustomize_Menu( NewSoldierState, none ); // If sending in 'none', needs to create this character.
	//<workshop> CHARACTER_POOL RJM 2016/02/05
	//WAS:
	//CharacterPoolMgr.SaveCharacterPool();	
	SaveCharacterPool();
	//</workshop>
	SelectedCharacters.Length = 0;
}
*/

// Support for entering character pool from Armory
/*
simulated function OnCancel()
{
	if (InShell())
	{
		super.OnCancel();
	}
	else
	{
		CloseScreen();
	}
}

simulated private function bool InShell()
{
	return XComShellPresentationLayer(Movie.Pres) != none;
}*/