package backend;

/**
 *   BuildMacro.getBuildDate()        → "2026-04-27"
 *   BuildMacro.getBuildDateTime()    → "2026-04-27 23:45"
 *   BuildMacro.getGitHash()          → "a1b2c3d"
 *   BuildMacro.getGitHashFull()      → "a1b2c3d4e5..."
 *   BuildMacro.getGitBranch()        → "main"
 *   BuildMacro.getGitMessage()       → "Add NotePool fix"
 *   BuildMacro.getGitAuthor()        → "LexyCod"
 *   BuildMacro.getGitDate()          → "2026-04-27 21:33"
 *   BuildMacro.getGitChangedFiles()  → "Note.hx\nPlayState.hx\n..."
 *   BuildMacro.getGitStats()         → "3 files, +45 -12"
 *   такая бредятина нахуй
 */

using StringTools;

class BuildMacro
{

	public static macro function getBuildDate():haxe.macro.Expr
	{
		var now = Date.now();
		var s = '${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}';
		return macro $v{s};
	}

	public static macro function getBuildDateTime():haxe.macro.Expr
	{
		var now = Date.now();
		var s = '${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}';
		return macro $v{s};
	}

	public static macro function getGitHash():haxe.macro.Expr
	{
		var hash = runGit(['rev-parse', '--short=7', 'HEAD']);
		return macro $v{hash};
	}

	public static macro function getGitHashFull():haxe.macro.Expr
	{
		var hash = runGit(['rev-parse', 'HEAD']);
		return macro $v{hash};
	}

	public static macro function getGitBranch():haxe.macro.Expr
	{
		var branch = runGit(['rev-parse', '--abbrev-ref', 'HEAD']);
		return macro $v{branch};
	}

	public static macro function getGitMessage():haxe.macro.Expr
	{
		var msg = runGit(['log', '-1', '--pretty=format:%s']);
		return macro $v{msg};
	}

	public static macro function getGitAuthor():haxe.macro.Expr
	{
		var author = runGit(['log', '-1', '--pretty=format:%an']);
		return macro $v{author};
	}

	public static macro function getGitDate():haxe.macro.Expr
	{
		var date = runGit(['log', '-1', '--pretty=format:%ci']);
		if (date.length >= 16) date = date.substr(0, 16);
		return macro $v{date};
	}

	public static macro function getGitChangedFiles():haxe.macro.Expr
	{
		var files = runGit(['diff-tree', '--no-commit-id', '-r', '--name-only', 'HEAD']);
		return macro $v{files};
	}

	public static macro function getGitStats():haxe.macro.Expr
	{
		var stats = runGit(['diff-tree', '--no-commit-id', '-r', '--shortstat', 'HEAD']);

		var reg1 = ~/(\d+) files? changed/;
		var reg2 = ~/(\d+) insertion/;
		var reg3 = ~/(\d+) deletion/;
		var files  = reg1.match(stats) ? reg1.matched(1) : '?';
		var ins    = reg2.match(stats) ? reg2.matched(1) : '0';
		var del    = reg3.match(stats) ? reg3.matched(1) : '0';
		var result = '$files files, +$ins −$del';
		return macro $v{result};
	}

	public static macro function getGitSummary():haxe.macro.Expr
	{
		var hash   = runGit(['rev-parse', '--short=7', 'HEAD']);
		var branch = runGit(['rev-parse', '--abbrev-ref', 'HEAD']);
		var msg    = runGit(['log', '-1', '--pretty=format:%s']);
		if (msg.length > 40) msg = msg.substr(0, 37) + '...';
		var result = '$hash | $branch | $msg';
		return macro $v{result};
	}

	#if macro
	static function runGit(args:Array<String>):String
	{
		try
		{
			var proc = new sys.io.Process('git', args);
			var out  = proc.stdout.readAll().toString().trim();
			var code = proc.exitCode();
			proc.close();
			if (code != 0 || out.length == 0) return 'unknown';
			return out;
		}
		catch (e:Dynamic)
		{
			return 'no-git';
		}
	}

	static function pad(n:Int):String
	{
		return n < 10 ? '0$n' : '$n';
	}
	#end
}
