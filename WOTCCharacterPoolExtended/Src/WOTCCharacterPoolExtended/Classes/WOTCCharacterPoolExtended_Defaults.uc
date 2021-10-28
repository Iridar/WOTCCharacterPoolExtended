class WOTCCharacterPoolExtended_Defaults extends object config(WOTCCharacterPoolExtended_DEFAULT);

var config int VERSION_CFG;

var config bool AUTOMATIC_UNIFORM_MANAGEMENT;
var config bool DISABLE_APPEARANCE_VALIDATION_REVIEW;
var config bool DISABLE_APPEARANCE_VALIDATION_DEBUG;
var config bool DEBUG_LOGGING;

var config array<CheckboxPresetStruct> CheckboxPresetsDefaults;

var config array<name> Presets_DEFAULT;
var config bool bShowCharPoolSoldiers_DEFAULT;
var config bool bShowUniformSoldiers_DEFAULT;
var config bool bShowBarracksSoldiers_DEFAULT;
var config bool bShowDeadSoldiers_DEFAULT;
var config bool bShowAllCosmeticOptions_DEFAULT;

// Mods should use this array to add their character pool files. Examply entry:
// +DefaultCharacterPoolFiles = (DLCName = "WOTCCharacterPoolTest", PoolName = "ModAddedPool")
var config array<PoolInfoStruct> DefaultCharacterPoolFiles;