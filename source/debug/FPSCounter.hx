package debug;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;
import openfl.display.Sprite;
import openfl.display.Shape;
import backend.LocalEngineVersion;
import backend.AsyncSongLoader;
import states.PlayState;

class FPSCounter extends Sprite
{
	public var textField:TextField;
	public var bg:Shape;

	public var currentFPS(default, null):Int;
	public var memoryMegas(get, never):Float;
	public var highestMem:Float = 0;
	
	@:noCompletion private var times:Array<Float>;

	static var _shortInfo:String   = null;
	static var _commitPanel:String = null;

	var _showCommitPanel:Bool = false;
	var deltaTimeout:Float = 0.0;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF)
	{
		super();

		this.x = x;
		this.y = y;

		bg = new Shape();
		addChild(bg);

		textField = new TextField();
		textField.selectable = false;
		textField.mouseEnabled = false;
		textField.defaultTextFormat = new TextFormat(Paths.font("vcr.ttf"), 14, color);
		textField.autoSize = LEFT;
		textField.multiline = true;
		addChild(textField);

		currentFPS = 0;
		times = [];
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000) times.shift();

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;

		#if (debug || dev)
		if (FlxG.keys.justPressed.TAB)
			_showCommitPanel = !_showCommitPanel;
		#end

		updateText();
		updateBackground();
	}

	public function updateBackground():Void
	{
		bg.graphics.clear();
		bg.graphics.beginFill(0x000000, 0.5);
		bg.graphics.drawRect(-5, -2, textField.width + 10, textField.height + 4);
		bg.graphics.endFill();
	}

	public dynamic function updateText():Void
	{
		if (_shortInfo == null)
			_shortInfo = LocalEngineVersion.SHORT_STRING;

		var memBytes:Float = memoryMegas;
		var memMB:Float = Math.round(memBytes / 1024 / 1024);
		
		if (memMB > highestMem)
			highestMem = memMB;

		var out:String = 'FPS: $currentFPS'
			+ '\nMemory: ${memMB} MB'
			+ '\nMem Peak: ${highestMem} MB'
			+ '\n$_shortInfo'
			+ '\nTAB (commit changes)';

		if (PlayState.instance != null && PlayState.isStoryMode)
		{
			var playlist = PlayState.storyPlaylist;
			if (playlist != null && playlist.length > 1)
			{
				var nextSong = playlist[1];
				var status = AsyncSongLoader.getStatus(nextSong, Difficulty.getFilePath());
				out += '\nNext: $nextSong [$status]';
			}
		}

		if (memMB > 900) out += '\n\u26A0 HIGH MEMORY';

		#if (debug || dev)
		if (_showCommitPanel)
		{
			if (_commitPanel == null) _buildCommitPanel();
			out += '\n' + _commitPanel;
		}
		#end

		textField.text = out;
		textField.textColor = (currentFPS < FlxG.drawFramerate * 0.5) ? 0xFFFF0000 : (memMB > 900 ? 0xFFFF8800 : 0xFFFFFFFF);
	}

	#if (debug || dev)
	static function _buildCommitPanel():Void
	{
		var rawFiles  = LocalEngineVersion.GIT_CHANGED_FILES;
		var fileLines = rawFiles.split('\n');
		var fileList  = fileLines.map(f -> {
			var parts = f.split('/');
			return '  • ' + parts[parts.length - 1];
		}).join('\n');

		_commitPanel = '──── Last Commit ────\n' + LocalEngineVersion.GIT_HASH_FULL + '\n' + fileList;
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
	static function _getNativeMemory():Float {
		var gcMem:Float = cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		return gcMem;
	}
	#end
}