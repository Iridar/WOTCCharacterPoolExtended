class UISL_CPExtended extends UIScreenListener;
/*
event OnInit(UIScreen Screen)
{
	local UICustomize_Menu				CustomizeScreen;
	local UICustomize_Menu_CPExtended	NewCustomizeScreen;
	local XComPresentationlayerBase		Pres;

	CustomizeScreen = UICustomize_Menu(Screen);
	if (CustomizeScreen != none && !CustomizeScreen.bInArmory && CustomizeScreen.Class != class'UICustomize_Menu_CPExtended')
	{
		Pres = CustomizeScreen.Movie.Pres;
		NewCustomizeScreen = Pres.Spawn(class'UICustomize_Menu_CPExtended', Pres);

		NewCustomizeScreen.CustomizeManager = CustomizeScreen.CustomizeManager;
		NewCustomizeScreen.UnitRef = CustomizeScreen.UnitRef;
		NewCustomizeScreen.Unit = CustomizeScreen.Unit;
		NewCustomizeScreen.bInArmory = CustomizeScreen.bInArmory;
		NewCustomizeScreen.bInMP = CustomizeScreen.bInMP;
		NewCustomizeScreen.IdleAnimName = CustomizeScreen.IdleAnimName;
		NewCustomizeScreen.bUsePersonalityAnim = CustomizeScreen.bUsePersonalityAnim;
		NewCustomizeScreen.NavHelp = CustomizeScreen.NavHelp;
		NewCustomizeScreen.ListBG = CustomizeScreen.ListBG;
		NewCustomizeScreen.List = CustomizeScreen.List;
		NewCustomizeScreen.Header = CustomizeScreen.Header;
		NewCustomizeScreen.CameraTag = CustomizeScreen.CameraTag;
		NewCustomizeScreen.DisplayTag = CustomizeScreen.DisplayTag;
		NewCustomizeScreen.FontSize = CustomizeScreen.FontSize;
		NewCustomizeScreen.bDisableVeteranOptions = CustomizeScreen.bDisableVeteranOptions;
		NewCustomizeScreen.bIsSuperSoldier = CustomizeScreen.bIsSuperSoldier;
		NewCustomizeScreen.bIsXPACSoldier = CustomizeScreen.bIsXPACSoldier;

		Pres.ScreenStack.Pop(CustomizeScreen);
		Pres.ScreenStack.Push(NewCustomizeScreen, Pres.Get3DMovie());
	}
}*/
/*
event OnReceiveFocus(UIScreen Screen);

event OnLoseFocus(UIScreen Screen);

event OnRemoved(UIScreen Screen);
*/

