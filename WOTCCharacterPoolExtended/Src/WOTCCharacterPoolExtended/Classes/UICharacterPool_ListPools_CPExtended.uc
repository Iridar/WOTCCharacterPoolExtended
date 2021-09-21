class UICharacterPool_ListPools_CPExtended extends UICharacterPool_ListPools;

var CPUnitData UnitData; 

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);
	
	// ---------------------------------------------------------

	// Create Container
	Container = Spawn(class'UIPanel', self).InitPanel('').SetPosition(30, 110).SetSize(600, 800);

	// Create BG
	BG = Spawn(class'UIBGBox', Container).InitBG('', 0, 0, Container.width, Container.height);
	BG.SetAlpha(80);

	// Create Title text
	TitleHeader = Spawn(class'UIX2PanelHeader', Container);
	TitleHeader.InitPanelHeader('', m_strTitleImportPoolLocation, m_strImportSubtitle); // TODO: Maybe change it here
	TitleHeader.SetHeaderWidth(Container.width - 20);
	TitleHeader.SetPosition(10, 10);

	List = Spawn(class'UIList', Container);
	List.bAnimateOnInit = false;
	List.InitList('', 10, TitleHeader.height, TitleHeader.headerWidth - 20, Container.height - TitleHeader.height - 10);
	List.Navigator.LoopSelection = true;
	List.OnSelectionChanged = ItemChanged;
	
	BG.ProcessMouseEvents(List.OnChildMouseEvent);

	// ---------------------------------------------------------

	NavHelp = Spawn(class'UINavigationHelp', self).InitNavHelp();
	NavHelp.AddBackButton(OnCancel);
		
	// ---------------------------------------------------------

	CharacterPoolMgr = CharacterPoolManager(`XENGINE.GetCharacterPoolManager());
}

simulated function UpdateData( bool _bIsExporting )
{
	bIsExporting = _bIsExporting; 

	// TODO: Figure out why this title is wrong
	`LOG(`showvar(m_strTitleImportPoolCharacter) @ `showvar(SelectedFriendlyName),, 'IRITESTSCREEN');

	TitleHeader.SetText(m_strTitleImportPoolCharacter, SelectedFriendlyName);

	Data = GetImportList();

	List.OnItemClicked = OnClickLocal;
	
	UpdateDisplay();
}

simulated function array<string> GetImportList()
{
	local array<string> Items; 

	Items = UnitData.GetUnitsFriendly();
	
	if (Items.Length > 0)
	{
		Items.InsertItem(0, m_strImportAll);
	}

	return Items; 
}




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