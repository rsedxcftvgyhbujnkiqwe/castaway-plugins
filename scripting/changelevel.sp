public Plugin myinfo =
{
	name = "changelevel",
	author = "random",
	description = "Fixes SourceTV crash on server start",
	version = "1.0",
	url = "http://castaway.tf"
};
public void OnPluginStart()
{
	char current_map[255];
	GetCurrentMap(current_map,sizeof(current_map));
	ForceChangeLevel(current_map,"Fixing crash");
}
