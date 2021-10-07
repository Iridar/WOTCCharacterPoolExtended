class WOTCCharacterPoolExtended_MCMScreen extends Object config(WOTCCharacterPoolExtended);

var config int VERSION_CFG;

var localized string ModName;
var localized string PageTitle;
var localized string GroupHeader;

`include(WOTCCharacterPoolExtended\Src\ModConfigMenuAPI\MCM_API_Includes.uci)

`MCM_API_AutoCheckBoxVars(DISABLE_APPEARANCE_VALIDATION_REVIEW);
`MCM_API_AutoCheckBoxVars(DISABLE_APPEARANCE_VALIDATION_DEBUG);

`include(WOTCCharacterPoolExtended\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

`MCM_API_AutoCheckBoxFns(DISABLE_APPEARANCE_VALIDATION_REVIEW, 1);
`MCM_API_AutoCheckBoxFns(DISABLE_APPEARANCE_VALIDATION_DEBUG, 1);

/********************************************************************
Insert `MCM_API_Auto????Fns and MCM_API_AutoButtonHandler macros here
********************************************************************/

event OnInit(UIScreen Screen)
{
	`MCM_API_Register(Screen, ClientModCallback);
}

//Simple one group framework code
simulated function ClientModCallback(MCM_API_Instance ConfigAPI, int GameMode)
{
	local MCM_API_SettingsPage Page;
	local MCM_API_SettingsGroup Group;

	LoadSavedSettings();
	Page = ConfigAPI.NewSettingsPage(ModName);
	Page.SetPageTitle(PageTitle);
	Page.SetSaveHandler(SaveButtonClicked);
	
	//Uncomment to enable reset
	//Page.EnableResetButton(ResetButtonClicked);

	Group = Page.AddGroup('Group', GroupHeader);

	`MCM_API_AutoAddCheckBox(Group, DISABLE_APPEARANCE_VALIDATION_REVIEW);	
	`MCM_API_AutoAddCheckBox(Group, DISABLE_APPEARANCE_VALIDATION_DEBUG);	
	
	Page.ShowSettings();
}

simulated function LoadSavedSettings()
{
	DISABLE_APPEARANCE_VALIDATION_REVIEW = `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_REVIEW);
	DISABLE_APPEARANCE_VALIDATION_DEBUG = `GETMCMVAR(DISABLE_APPEARANCE_VALIDATION_DEBUG);
}

simulated function ResetButtonClicked(MCM_API_SettingsPage Page)
{
	`MCM_API_AutoReset(DISABLE_APPEARANCE_VALIDATION_REVIEW);
	`MCM_API_AutoReset(DISABLE_APPEARANCE_VALIDATION_DEBUG);
}


simulated function SaveButtonClicked(MCM_API_SettingsPage Page)
{
	VERSION_CFG = `MCM_CH_GetCompositeVersion();
	SaveConfig();
}


