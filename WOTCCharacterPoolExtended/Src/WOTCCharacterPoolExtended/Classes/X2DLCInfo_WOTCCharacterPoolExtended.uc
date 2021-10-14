class X2DLCInfo_WOTCCharacterPoolExtended extends X2DownloadableContentInfo;

static function OnPreCreateTemplates()
{	
	local XComEngine LocalEngine;

	LocalEngine = `XENGINE;
	LocalEngine.m_CharacterPoolManager = new class'CharacterPoolManagerExtended';
}

static event OnLoadedSavedGame()
{
	class'UICustomize_CPExtended'.static.SetInitialSoldierListSettings();
}

static event InstallNewCampaign(XComGameState StartState)
{
	class'UICustomize_CPExtended'.static.SetInitialSoldierListSettings();
}

/*
exec function SetLoc(int X, int Y)
{
	local UICustomize_CPExtended CPExtended;

	CPExtended = UICustomize_CPExtended(`SCREENSTACK.GetCurrentScreen());
	if (CPExtended != none)
	{
		CPExtended.OptionsContainer.SetPosition(X, Y);
	}
}

exec function SetSize(int X, int Y)
{
	local UICustomize_CPExtended CPExtended;

	CPExtended = UICustomize_CPExtended(`SCREENSTACK.GetCurrentScreen());
	if (CPExtended != none)
	{
		CPExtended.OptionsContainer.SetSize(X, Y);
	}
}*/
