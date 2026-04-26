package backend;

/**
* macros for developement
*/

class BuildMacro
{
	// build data
	public static macro function getBuildDate():haxe.macro.Expr {
		var now = Date.now();
		var dateStr = '${now.getFullYear()}-${pad(now.getMonth() +1)}-${pad(now.getDate())}';
		return macro $v{dateStr};
	}

	public static macro function getBuildDateTime():haxe.macro.Expr
	{
		var now = Date.now();
		var str = '${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}';
		return macro $v{str};
	}

	#if macro
	static function pad(n:Int):String {
		return n < 10 ? '0$n' : '$n';
	}
	#end
	
}