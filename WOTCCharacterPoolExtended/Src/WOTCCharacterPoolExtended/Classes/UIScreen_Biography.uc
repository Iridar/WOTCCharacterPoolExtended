class UIScreen_Biography extends UICustomize;

var private UIText	Text_1;
var private UIText	Text_2;
var private UIText	ArrowText;
var private UIBGBox	TextBG;


var delegate<OnScreenClosed> OnScreenClosedFn;

delegate OnScreenClosed();

simulated function CloseScreen()
{	
	if (OnScreenClosedFn != none)
		OnScreenClosedFn();

	super.CloseScreen();
}

simulated final function ShowText(string Biography_1, string Biography_2)
{
	TextBG = Spawn(class'UIBGBox', self);
	TextBG.InitBG();
	TextBG.bAnimateOnInit = true;
	TextBG.bIsNavigable = false;
	TextBG.SetSize(1820, 980);
	TextBG.SetPosition(50, 50);
	TextBG.Show();
	
	Text_1 = Spawn(class'UIText', self);
	Text_1.InitText();
	Text_1.SetPosition(100, 100);
	Text_1.SetHeight(880);
	Text_1.SetWidth(835);
	Text_1.SetText(Biography_1);
	Text_1.bAnimateOnInit = true;
	Text_1.Show();

	ArrowText = Spawn(class'UIText', self);
	ArrowText.InitText();
	ArrowText.SetText("->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->\n->");
	ArrowText.SetPosition(940, 100);
	ArrowText.bAnimateOnInit = true;
	ArrowText.Show();

	Text_2 = Spawn(class'UIText', self);
	Text_2.InitText();
	Text_2.SetPosition(985, 100);
	Text_2.SetHeight(880);
	Text_2.SetWidth(835);
	Text_2.SetText(Biography_2);
	Text_2.bAnimateOnInit = true;
	//Text_2.EnableScrollbar(); // Doesn't seem to be doing anything.
	Text_2.Show();
}

simulated function UpdateData() {}

defaultproperties
{
	bUsePersonalityAnim = false;
}