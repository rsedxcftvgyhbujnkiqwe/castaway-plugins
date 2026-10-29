/**
 * Get an absolute value of an integer.
 *
 * @param x		Integer.
 * @return		Absolute value of x.
 */
stock int abs(int x)
{
	int mask = x >> 31;
	return (x + mask) ^ mask;
}

/**
 * Get the lesser integer between two integers.
 *
 * @param x		Integer x.
 * @param y		Integer y.
 * @return		The lesser integer between x and y.
 */
stock int intMin(int x, int y)
{
	return x > y ? y : x;
}

/**
 * Get the greater integer between two integers.
 *
 * @param x		Integer x.
 * @param y		Integer y.
 * @return		The greater integer between x and y.
 */
stock int intMax(int x, int y)
{
	return x > y ? x : y;
}

/**
 * Get the lesser float between two floats.
 *
 * @param x		Float x.
 * @param y		Float y.
 * @return		The lesser float between x and y.
 */
stock float floatMin(float x, float y)
{
	return x > y ? y : x;
}

/**
 * Get the greater float between two floats.
 *
 * @param x		Float x.
 * @param y		Float y.
 * @return		The greater float between x and y.
 */
stock float floatMax(float x, float y)
{
	return x > y ? x : y;
}

stock float clamp(float val, float a, float b)
{
	return (val > b ? b : (val < a ? a : val));
}
