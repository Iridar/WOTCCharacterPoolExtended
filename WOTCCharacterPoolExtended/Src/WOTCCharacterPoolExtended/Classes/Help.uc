class Help extends Object abstract;

static final function X2ItemTemplate GetItemTemplateFromCosmeticTorso(const name nmTorso)
{
	local name						ArmorTemplateName;
	local X2BodyPartTemplate		ArmorPartTemplate;
	local X2BodyPartTemplateManager BodyPartMgr;
	local X2ItemTemplateManager		ItemMgr;

	BodyPartMgr = class'X2BodyPartTemplateManager'.static.GetBodyPartTemplateManager();
	ArmorPartTemplate = BodyPartMgr.FindUberTemplate("Torso", nmTorso);
	if (ArmorPartTemplate != none)
	{
		ArmorTemplateName = ArmorPartTemplate.ArmorTemplate;
		if (ArmorTemplateName != '')
		{
			ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
			return ItemMgr.FindItemTemplate(ArmorTemplateName);
		}
	}
	return none;
}
/*
static final function X2SoldierPersonalityTemplate GetPersonalityTemplate(const int iAttitude)
{
	local array<X2StrategyElementTemplate> PersonalityTemplates;

	PersonalityTemplates = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().GetAllTemplatesOfClass(class'X2SoldierPersonalityTemplate');
	PersonalityTemplate = X2SoldierPersonalityTemplate(PersonalityTemplates[iAttitude]);

	return PersonalityTemplate;
}*/