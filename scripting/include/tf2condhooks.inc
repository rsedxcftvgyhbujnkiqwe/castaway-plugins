#if defined _tf2condhooks_included
	#endinput
#endif

#define _tf2condhooks_included

#include <tf2_stocks>

/**
 *	Called when a condition is added.
 *
 *	@param client 			Client receiving the condition.
 *	@param cond 			Condition being added.
 *							Note that a client can already be in this condition!
 *	@param time 			Time duration of this condition.
 *	@param provider 		condition provider, -1 if there is not one.
 *
 *	@return 				Plugin_Changed to use changed values, >=Plugin_Handled
 *							to prevent condition addition.
*/
forward Action TF2_OnAddCond(int client, TFCond &cond, float &time, int &provider);


/**
 *	Called when a condition is removed.
 *
 *	@param client 			Client that has the condition that's being removed.
 *	@param cond 			Condition type.
 *	@param timeleft 		Time remaining on the condition. If -1.0, this condition
 *							was added permanently and removed manually. If 0.0, the
 *							condition was most likely removed automatically.
 *	@param provider 		Provider of the condition, -1 if there is not one.
 *
 *	@return 				Plugin_Changed to change time and provider values.
 *							Changing timeleft to a value > 0.0 or TFCondDuration_Infinite
 *							will adjust this condition's removal time.
 *
 *							>= Plugin_Handled to prevent removal of this condition.
 *							Handling a condition that was removed automatically will
 *							simply fire this again for this condition next frame.
 *							If you intend to delay removal, it's recommended that
 *							set the timeleft and return Plugin_Changed.
 *
 *							Note that this may produce unintentional behavior!
 *							If a condition is removed manually, there is a chance
 *							that m_nPlayerCondEx bits will be adjusted regardless.
 *							This happens with CTFPlayerShared::RemoveAllCond which
 *							noteably fires on spawn, death, and changeteam
*/
forward Action TF2_OnRemoveCond(int client, TFCond &cond, float &timeleft, int &provider);

public SharedPlugin __pl_tf2condhooks = {
	name = "tf2condhooks",
	file = "tf2condhooks.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};