package backend;

/**
 * LOCAL ENGINE — Version Info
 *   LocalEngineVersion.VERSION      → "1.0.0"
 *   LocalEngineVersion.BUILD_DATE   → "2026-04-26"
 *   LocalEngineVersion.FULL_STRING  → "Local Engine 1.0.0 (built 2026-04-26)"
 *   LocalEngineVersion.PSYCH_BASE   → "0.7.3"
 */
class LocalEngineVersion
{
	public static inline var VERSION:String = "0.0.2";

	public static inline var PSYCH_BASE:String = "0.7.3";

	public static var BUILD_DATE(get, never):String;
	static function get_BUILD_DATE():String
	{
		return BuildMacro.getBuildDate();
	}

	public static var FULL_STRING(get, never):String;
	static function get_FULL_STRING():String
	{
		return 'Local Engine $VERSION (built $BUILD_DATE) [Psych $PSYCH_BASE]';
	}

	public static var SHORT_STRING(get, never):String;
	static function get_SHORT_STRING():String
	{
		return 'LE $VERSION | $BUILD_DATE';
	}
}
