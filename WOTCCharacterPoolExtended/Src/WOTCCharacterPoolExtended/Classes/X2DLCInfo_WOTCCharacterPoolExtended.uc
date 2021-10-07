class X2DLCInfo_WOTCCharacterPoolExtended extends X2DownloadableContentInfo;

static function OnPreCreateTemplates()
{	
	local XComEngine LocalEngine;

	LocalEngine = `XENGINE;
	LocalEngine.m_CharacterPoolManager = new class'CharacterPoolManagerExtended';
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
