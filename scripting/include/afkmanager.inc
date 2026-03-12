#if defined _AFKMANAGER_INCLUDED
	#endinput
#endif
#define _AFKMANAGER_INCLUDED

/**
 * Called when an AFK kick is about to be performed.
 * 
 * @param client    Client index.
 * @returns         Return Plugin_Continue to continue the kick, return a
 *                  higher value to block the kick. When blocked, it will
 * 					reset the internal AFK time and will get called again
 * 					when the client continues to be AFK.
 */
forward Action OnAFKKick(int client);

public SharedPlugin __pl_afkmanager = {
	name = "afkmanager",
	file = "afkmanager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
