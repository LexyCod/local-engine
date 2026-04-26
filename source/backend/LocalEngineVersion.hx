package backend;

/**
 * Version Info
 * пиздец нахуй
 */
class LocalEngineVersion
{
	public static inline var VERSION:String = "0.0.25";

	public static inline var PSYCH_BASE:String = "0.7.3";

	public static var BUILD_DATE(get, never):String;
	static function get_BUILD_DATE() return BuildMacro.getBuildDate();

	public static var GIT_HASH(get, never):String;
	static function get_GIT_HASH() return BuildMacro.getGitHash();

	public static var GIT_HASH_FULL(get, never):String;
	static function get_GIT_HASH_FULL() return BuildMacro.getGitHashFull();

	public static var GIT_BRANCH(get, never):String;
	static function get_GIT_BRANCH() return BuildMacro.getGitBranch();

	public static var GIT_MESSAGE(get, never):String;
	static function get_GIT_MESSAGE() return BuildMacro.getGitMessage();

	public static var GIT_AUTHOR(get, never):String;
	static function get_GIT_AUTHOR() return BuildMacro.getGitAuthor();

	public static var GIT_DATE(get, never):String;
	static function get_GIT_DATE() return BuildMacro.getGitDate();

	public static var GIT_CHANGED_FILES(get, never):String;
	static function get_GIT_CHANGED_FILES() return BuildMacro.getGitChangedFiles();

	public static var GIT_STATS(get, never):String;
	static function get_GIT_STATS() return BuildMacro.getGitStats();


	public static var SHORT_STRING(get, never):String;
	static function get_SHORT_STRING()
		return 'LE $VERSION | $GIT_HASH';

	public static var FULL_STRING(get, never):String;
	static function get_FULL_STRING()
		return 'Local Engine $VERSION ($GIT_HASH · $GIT_BRANCH) built $BUILD_DATE';
}
