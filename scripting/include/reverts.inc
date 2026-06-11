#if defined _tf2reverts_included
 #endinput
#endif
#define _tf2reverts_included

/**
 * Applies weapon reverts to the given item
 * Must be a tf2items item handle!
 *
 * @param item				TF2Items handle for the item
 * @param index				Item definition index
 * @return					0
 * @error					Invalid Handle
 */
native int Reverts_ApplyRevertsToItem(Handle item, int index);

public SharedPlugin __pl_reverts = 
{
	name = "reverts",
	file = "reverts.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_reverts_SetNTVOptional()
{
	MarkNativeAsOptional("Reverts_ApplyRevertsToItem");
}
#endif