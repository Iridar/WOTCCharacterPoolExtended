class UIMechaListItem_Button extends UIMechaListItem;

simulated function UIMechaListItem UpdateDataButton(string _Desc,
								 	 string _ButtonLabel,
								 	 delegate<OnButtonClickedCallback> _OnButtonClicked = none,
									 optional delegate<OnClickDelegate> _OnClickDelegate = none)
{
	//SetWidgetType(EUILineItemType_Button); // Primary function is still checbox

	if (Button == none)
	{
		Button = Spawn(class'UIButton', self);
		Button.bAnimateOnInit = false;
		Button.bIsNavigable = false;
		Button.InitButton('ButtonMC', "", OnButtonClickDelegate);
		Button.SetX(width - 150 - 25); // Added some offset
		Button.SetY(0);
		Button.SetHeight(34);
		Button.MC.SetNum("textY", 2);
		Button.OnSizeRealized = UpdateButtonX;
	}

	Button.SetText(_ButtonLabel);
	RefreshButtonVisibility();

	Desc.SetWidth(width - 150 - 25); // Added some offset
	Desc.SetHTMLText(_Desc);
	Desc.Show();

	OnClickDelegate = _OnClickDelegate;
	OnButtonClickedCallback = _OnButtonClicked;

	return self;
}
simulated function UpdateButtonX()
{
	if (Button != none)
	{
		Button.SetX(width - Button.Width - 30 - 25); // Added some offset
	}
}