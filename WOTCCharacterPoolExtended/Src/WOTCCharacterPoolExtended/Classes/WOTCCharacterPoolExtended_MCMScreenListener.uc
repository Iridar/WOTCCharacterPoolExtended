//-----------------------------------------------------------
//	Class:	WOTCCharacterPoolExtended_MCMScreenListener
//	Author: Iridar
//	
//-----------------------------------------------------------

class WOTCCharacterPoolExtended_MCMScreenListener extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local WOTCCharacterPoolExtended_MCMScreen MCMScreen;

	if (ScreenClass==none)
	{
		if (MCM_API(Screen) != none)
			ScreenClass=Screen.Class;
		else return;
	}

	MCMScreen = new class'WOTCCharacterPoolExtended_MCMScreen';
	MCMScreen.OnInit(Screen);
}

defaultproperties
{
    ScreenClass = none;
}
