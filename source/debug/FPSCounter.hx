package debug;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;
import backend.LocalEngineVersion;
import backend.AsyncSongLoader;
import states.PlayState;

class FPSCounter extends TextField
{
	public var currentFPS(default, null):Int;

	public var memoryMegas(get, never):Float;

	@:noCompletion private var times:Array<Float>;

	static var _shortInfo:String   = null;
	static var _commitPanel:String = null;

	var _showCommitPanel:Bool = false;

	var deltaTimeout:Float = 0.0;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable    = false;
		mouseEnabled  = false;
		defaultTextFormat = new TextFormat("_sans", 14, color);
		autoSize  = LEFT;
		multiline = true;
		text      = "FPS: ";

		times = [];
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		if (deltaTimeout > 1000) {
			deltaTimeout = 0.0;
			return;
		}

		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000) times.shift();

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;

		#if debug
		if (FlxG.keys.justPressed.TAB)
			_showCommitPanel = !_showCommitPanel;
		#end

		updateText();
		deltaTimeout += deltaTime;
	}

	public dynamic function updateText():Void
	{
		if (_shortInfo == null)
			_shortInfo = LocalEngineVersion.SHORT_STRING;

		var memBytes:Float = memoryMegas;
		var memStr:String  = flixel.util.FlxStringUtil.formatBytes(memBytes);
		var memMB:Float    = memBytes / 1024 / 1024;

		var out:String = 'FPS: $currentFPS'
			+ '\nMemory: $memStr'
			+ '\n$_shortInfo';

		if (PlayState.instance != null && PlayState.isStoryMode)
		{
			var playlist = PlayState.storyPlaylist;
			if (playlist != null && playlist.length > 1)
			{
				var nextSong = playlist[1];
				var status   = AsyncSongLoader.getStatus(nextSong, Difficulty.getFilePath());
				out += '\nNext: $nextSong [$status]';
			}
		}

		if (memMB > 900) out += '\n\u26A0 HIGH MEMORY';

		#if debug
		if (_showCommitPanel)
		{
			if (_commitPanel == null) _buildCommitPanel();
			out += '\n' + _commitPanel;
		}
		else
		{
			out += '\n[Tab] commit info';
		}
		#end

		text      = out;
		textColor = 0xFFFFFFFF;
		if (currentFPS < FlxG.drawFramerate * 0.5)
			textColor = 0xFFFF0000;
		else if (memMB > 900)
			textColor = 0xFFFF8800;
	}

	#if debug
	static function _buildCommitPanel():Void
	{
		var rawFiles  = LocalEngineVersion.GIT_CHANGED_FILES;
		var fileLines = rawFiles.split('\n');
		var fileList  = fileLines.map(f -> {
			var parts = f.split('/');
			return '  • ' + parts[parts.length - 1];
		}).join('\n');

		_commitPanel =
			  '──── Last Commit ────────────────'
			+ '\nCommit(full): ' + LocalEngineVersion.GIT_HASH_FULL
			+ '\nBranch: ' + LocalEngineVersion.GIT_BRANCH
			+ '\nAuthor: ' + LocalEngineVersion.GIT_AUTHOR
			+ '\nDate: ' + LocalEngineVersion.GIT_DATE
			+ '\nDescription: ' + LocalEngineVersion.GIT_MESSAGE
			+ '\nStats: dc' + LocalEngineVersion.GIT_STATS
			+ '\nChanged files:'
			+ '\n' + fileList
			+ '\n─────────────────────────────────';
	}
	#end

	function get_memoryMegas():Float
	{
		#if cpp
		return _getNativeMemory();
		#else
		return cast(System.totalMemory, UInt);
		#end
	}

	#if cpp
	@:noCompletion
	static function _getNativeMemory():Float
	{
		#if !windows
		try {
			var status = sys.io.File.getContent('/proc/self/status');
			var reg = new EReg('VmRSS:\\s*(\\d+)\\s*kB', '');
			if (reg.match(status))
				return Std.parseFloat(reg.matched(1)) * 1024;
		} catch(e:Dynamic) {}
		#end

		var gcMem:Float  = cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		var sysMem:Float = cast(System.totalMemory, UInt);
		return gcMem; // + sysMem варивант странно этот работает порчемуто
	}
	#end
}
