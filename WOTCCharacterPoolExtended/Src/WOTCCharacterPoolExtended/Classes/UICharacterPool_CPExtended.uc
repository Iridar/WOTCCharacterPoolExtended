class UICharacterPool_CPExtended extends UICharacterPool;

var UIButton CPE_ImportButton;
var UIButton CPE_ExportButton;

// Just adding a couple of buttons in a third column at the bottom of the CP screen
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

	Hide();
	`XCOMGRI.DoRemoteEvent('StartCharacterPool'); // start a fade
	WorldInfo.RemoteEventListeners.AddItem(self);
	SetTimer(2.0, false, nameof(ForceShow));
	
	bAnimateOut = false;
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
