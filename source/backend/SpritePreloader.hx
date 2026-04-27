package backend;

import flixel.FlxG;
import openfl.utils.Assets;

/**
 *   var preloader = new SpritePreloader();
 *   preloader.onProgress = (p) -> loadBar.scale.x = p;
 *   preloader.onComplete = () -> switchState(target);
 *   preloader.start(songName, difficulty);
 */
class SpritePreloader
{
	public var onProgress:Float -> Void = null;

	public var onComplete:Void -> Void = null;

	var _queue:Array<PreloadTask> = [];
	var _total:Int    = 0;
	var _done:Int     = 0;
	var _started:Bool = false;

	public function new() {}

	public function start(songName:String, ?difficulty:String = 'Normal'):Void
	{
		if (_started) return;
		_started = true;

		_queueGameplayUI();
		_queueNotes();
		_queueSong(songName);

		_total = _queue.length;

		#if debug
		trace('[SpritePreloader] Total: $_total for "$songName"');
		#end

		_processNext();
	}

	public function startMenuPreload():Void
	{
		if (_started) return;
		_started = true;

		_queueImage('shared/images/menuBG');
		_queueImage('shared/images/menuDesat');
		_queueAtlas('shared/images/FNF_main_menu_assets');

		_total = _queue.length;
		_processNext();
	}

	function _queueGameplayUI():Void
	{
		for (r in ['sick', 'good', 'bad', 'shit'])
			_queueImage('shared/images/ui/$r');

		for (i in 0...10)
			_queueImage('shared/images/ui/num$i');

		_queueImage('shared/images/healthBar');
		_queueAtlas('shared/images/ui/iconGrid');
	}

	function _queueNotes():Void
	{
		_queueAtlas('shared/images/notes/NOTE_assets');
		_queueAtlas('shared/images/notes/noteSplashes');
		_queueAtlas('shared/images/notes/NOTE_hold_assets');
	}

	function _queueSong(songName:String):Void
	{
		if (PlayState.SONG == null) return;

		var song = PlayState.SONG;
		if (song.player1 != null) _queueCharacter(song.player1);
		if (song.player2 != null) _queueCharacter(song.player2);
		if (song.gfVersion != null) _queueCharacter(song.gfVersion);

		if (song.stage != null) _queueStage(song.stage);
	}

	function _queueCharacter(charName:String):Void
	{
		_queueAtlas('shared/images/characters/$charName/$charName');
		_queueImage('shared/images/icons/icon-$charName');
	}

	function _queueStage(stageName:String):Void
	{
		var stagePath = Paths.getPath('data/stages/$stageName.json', TEXT);
		if (Assets.exists(stagePath))
		{
			try {
				var data = haxe.Json.parse(Assets.getText(stagePath));
				if (data != null && data.objects != null)
				{
					for (obj in (data.objects : Array<Dynamic>))
					{
						if (obj.image != null)
							_queueImage('shared/images/' + obj.image);
					}
				}
			} catch(e:Dynamic) {}
		}
	}

	function _queueImage(path:String):Void
	{
		_queue.push({ type: IMAGE, path: path });
	}

	function _queueAtlas(path:String):Void
	{
		_queue.push({ type: ATLAS, path: path });
	}

	function _processNext():Void
	{
		if (_queue.length == 0)
		{
			_finish();
			return;
		}

		var task = _queue.shift();
		_executeTask(task);
	}

	function _executeTask(task:PreloadTask):Void
	{
		try {
			switch (task.type)
			{
				case IMAGE:
					var imgPath = Paths.getPath('${task.path}.png', IMAGE);
					if (Assets.exists(imgPath))
						Paths.image(task.path);

				case ATLAS:
					var xmlPath = Paths.getPath('${task.path}.xml', TEXT);
					var txtPath = Paths.getPath('${task.path}.txt', TEXT);
					if (Assets.exists(xmlPath))
						LocalAtlasTextures.getSparrow(task.path, 'preload');
					else if (Assets.exists(txtPath))
						LocalAtlasTextures.getPacker(task.path, 'preload');
					else
						Paths.image(task.path);
			}
		} catch(e:Dynamic) {
			#if debug trace('[SpritePreloader] err: ${task.path} — $e'); #end
		}

		_done++;
		var progress = _total > 0 ? _done / _total : 1.0;
		if (onProgress != null) onProgress(progress);

		haxe.Timer.delay(_processNext, 1);
	}

	function _finish():Void
	{
		openfl.system.System.gc();
		#if debug trace('[SpritePreloader] done $_done '); #end
		if (onComplete != null) onComplete();
	}
}

enum PreloadTaskType { IMAGE; ATLAS; }
typedef PreloadTask = { type:PreloadTaskType, path:String }
