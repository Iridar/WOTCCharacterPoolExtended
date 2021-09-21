class UICharacterPool_ListPools_CPExtended extends UICharacterPool_ListPools;
/*
simulated function bool DoMakeEmptyPool(string NewFriendlyName)
{
	local CharacterPoolManagerExtended ExportPool;
	local string FullFileName;

	local array<string> FriendlyNames;
	local array<string> FileNames;
	local string PrintString;

	FullFileName = CharacterPoolManagerExtended(CharacterPoolMgr).ImportDirectoryName $ "\\" $ NewFriendlyName $ ".bin";

	if(EnumeratedFilenames.Find(FullFileName) != INDEX_NONE)
		return false;

	ExportPool = new class'CharacterPoolManagerExtended';
	ExportPool.ImportDirectoryName = "CharacterPool\\CharacterPoolExtended";
	ExportPool.default.ImportDirectoryName = "CharacterPool\\CharacterPoolExtended";

	ExportPool.EnumerateImportablePools(FriendlyNames, FileNames);

	`LOG("BEGIN CP PRINT",, 'IRITEST');
	foreach FriendlyNames(PrintString)
	{
		`LOG(PrintString,, 'IRITEST');
	}
	foreach FileNames(PrintString)
	{
		`LOG(PrintString,, 'IRITEST');
	}
	`LOG("END CP PRINT",, 'IRITEST');

	ExportPool.CharPoolExtendedFilePath = FullFileName;
	ExportPool.SaveCharacterPoolExtended();
	return true;
}
*/