class UIMechaListItem_Color extends UIMechaListItem;

// Same as original, but used to display two colors at once.

var UIBGBox	ColorChip2;
var UIText	ArrowText;

var string	strColor1;
var string	strColor2;

var private UIText Color1_Text;
var private UIText Color2_Text;

var string HTMLColorChip2;
/*
simulated function SetWidgetType(EUILineItemType NewType)
{
	super.SetWidgetType(NewType);

	if(ColorChip2 != None) ColorChip2.Hide();

	Show();
}*/

simulated function UIMechaListItem UpdateDataColorChip(string _Desc,
										String _HTMLColorChip,
										optional delegate<OnClickDelegate> _OnClickDelegate = none)
{
	//SetWidgetType(EUILineItemType_ColorChip);

	if( ColorChip == none )
	{
		ColorChip = Spawn(class'UIBGBox', self);
		ColorChip.bAnimateOnInit = false;
		ColorChip.bIsNavigable = false;
		ColorChip.InitBG('ColorChipMC');
		ColorChip.SetSize(85, 20);
		ColorChip.SetPosition(width / 2, 7);
	}

	//--------------------------------
	ColorChip.SetColor(_HTMLColorChip);
	ColorChip.Show();

	Color1_Text = Spawn(class'UIText', self);
	Color1_Text.InitText('ColorChip1TextMC');
	Color1_Text.SetPosition(ColorChip.X, 5);
	Color1_Text.SetCenteredText(strColor1, ColorChip);
	//Color1_Text.MoveToHighestDepth();
	
	ArrowText = Spawn(class'UIText', self);
	ArrowText.InitText('ColorArrowTextMC', "->");
	ArrowText.SetPosition(width / 2 + ColorChip.Width + 3, 0);

	if( ColorChip2 == none )
	{
		ColorChip2 = Spawn(class'UIBGBox', self);
		ColorChip2.bAnimateOnInit = false;
		ColorChip2.bIsNavigable = false;
		ColorChip2.InitBG('ColorChip2MC');
		ColorChip2.SetSize(85, 20);
		ColorChip2.SetPosition(width / 2 + ColorChip.Width + 30, 7);

		Color2_Text = Spawn(class'UIText', self);
		Color2_Text.InitText('ColorChip2TextMC');
		Color2_Text.SetPosition(ColorChip2.X, 5);
		Color2_Text.SetCenteredText(strColor2, ColorChip2);
		//Color2_Text.MoveToHighestDepth();
	}

	ColorChip2.SetColor(HTMLColorChip2);
	ColorChip2.Show();

	//--------------------------------
	Desc.SetWidth(width / 2);
	Desc.SetHTMLText(" ");
	Desc.SetHTMLText(_Desc);
	Desc.Show();

	OnClickDelegate = _OnClickDelegate;

	return self;
}