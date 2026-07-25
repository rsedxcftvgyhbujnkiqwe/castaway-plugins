#if defined _NATIVEVOTES_UTILS_INCLUDED
	#endinput
#endif
#define _NATIVEVOTES_UTILS_INCLUDED

#include <sourcemod>
#include <nativevotes>

/**
 * Sends a vote menu to all clients who are not spectators or waiting to choose a
 * team. See NativeVotes.DisplayVote() for more information.
 * This is a deprecated function in nativevotes.inc copied over.
 *
 * @param vote				Vote Handle.
 * @param time				Maximum time to leave menu on the screen.
 * @param flag				Optional voting flags (i.e. VOTEFLAG_NO_REVOTES)
 * @return					True on success, false if this menu already has a vote session
 *							in progress.
 * @error					Invalid Handle, or a vote is already in progress.
 */
stock bool DisplayNativeVoteToNonSpectators(NativeVote vote, int time, int flags = 0) {
	int total;
	int[] players = new int[MaxClients];
	
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || IsClientObserver(i)) {
			continue;
		}
		players[total++] = i;
	}
	return vote.DisplayVote(players, total, time, flags);
}

/**
 * Sends a vote menu to all clients who are not spectators or waiting to choose a
 * team. See Menu.DisplayVote() for more information.
 * This is the same function above but now it accepts Menu instead of NativeVote.
 *
 * @param vote				Menu Handle.
 * @param time				Maximum time to leave menu on the screen.
 * @param flag				Optional voting flags (i.e. VOTEFLAG_NO_REVOTES)
 * @return					True on success, false if this menu already has a vote session
 *							in progress.
 * @error					Invalid Handle, or a vote is already in progress.
 */
stock bool DisplayMenuVoteToNonSpectators(Menu vote, int time, int flags = 0) {
	int total;
	int[] players = new int[MaxClients];
	
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || IsClientObserver(i)) {
			continue;
		}
		players[total++] = i;
	}
	return vote.DisplayVote(players, total, time, flags);
}
