class UIMechaListItem_Color extends UIMechaListItem;

// Same as original, but used to display two colors at once in addition to a checkbox.

var string	strColorText_1;
var string	strColorText_2;
var string	HTMLColorChip2;

var private UIBGBox	ColorChip2;
var private UIText	ArrowText;

var private UIText	Color1_Text;
var private UIText	Color2_Text;

simulated function UIMechaListItem UpdateDataColorChip(string _Desc,
										String _HTMLColorChip,
										optional delegate<OnClickDelegate> _OnClickDelegate = none)
{
	// Widget type will actually be "checkbox". The intent is to call 'UpdateDataColorChip' after 'UpdateDataCheckbox'.
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
	Color1_Text.SetCenteredText(strColorText_1, ColorChip);
	Color1_Text.bAnimateOnInit = false;
	
	ArrowText = Spawn(class'UIText', self);
	ArrowText.InitText('ColorArrowTextMC', "->");
	ArrowText.SetPosition(width / 2 + ColorChip.Width + 3, 0);
	ArrowText.bAnimateOnInit = false;

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
		Color2_Text.SetCenteredText(strColorText_2, ColorChip2);
		Color2_Text.bAnimateOnInit = false;
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