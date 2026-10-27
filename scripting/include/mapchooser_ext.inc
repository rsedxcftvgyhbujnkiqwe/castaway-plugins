#include <mapchooser>

/**
 * Get the current list of map categories.
 *
 * @param categories	An ADT array to store the list of map categories.
 */
native void GetMapCategories(ArrayList categories);

/**
 * Get maps in a category.
 *
 * @param category		Name of the category.
 * @param maps			An ADT array to store the list of maps.
 * @return				True on success, false on failure.
 */
native bool GetMapsInCategory(const char[] category, ArrayList maps);

/**
 * Called when mapchooser config has executed.
 */
forward void OnMapVoteConfigExecuted();
