package backend;

import openfl.utils.Assets;

typedef PreloadTask = { path:String, type:TaskType }
enum TaskType { IMAGE; SPARROW; PACKER; }

class SpritePreloader
{
	public var onProgress:Float->Void = null;
	public var onComplete:Void->Void  = null;
	public var tasksPerTick:Int = 8;

	var _queue:Array<PreloadTask> = [];
	var _done:Int    = 0;
	var _total:Int   = 0;
	var _started:Bool = false;
	var _finished:Bool = false;

	public function new() {}

	public function start(songName:String):Void
	{
		if (_started) return;
		_started = true;

		_scanNotes();
		_scanGameplayUI();

		if (PlayState.SONG != null)
		{
			var song = PlayState.SONG;
			#if debug trace('[SpritePreloader] Song: p1=${song.player1} p2=${song.player2} gf=${song.gfVersion} stage=${song.stage}'); #end

			if (song.player1 != null)   _scanCharacter(song.player1);
			if (song.player2 != null)   _scanCharacter(song.player2);
			if (song.gfVersion != null) _scanCharacter(song.gfVersion);
			if (song.stage != null)     _scanStage(song.stage);
		}

		_total = _queue.length;
		#if debug trace('[SpritePreloader] Total: $_total tasks queued'); for (t in _queue) trace('  - ${t.path} (${t.type})'); #end

		if (_total == 0) _finish();
	}

	public function startMenuPreload():Void
	{
		if (_started) return;
		_started = true;
		_enqueueAuto('menuBG');
		_enqueueAuto('menuDesat');
		_enqueueAuto('FNF_main_menu_assets');
		_total = _queue.length;
		if (_total == 0) _finish();
	}

	public function tick():Void
	{
		if (_finished || !_started || _queue.length == 0) return;
		var processed:Int = 0;
		while (_queue.length > 0 && processed < tasksPerTick)
		{
			var task = _queue.shift();
			_execute(task);
			_done++;
			processed++;
		}
		if (onProgress != null && _total > 0) onProgress(_done / _total);
		if (_queue.length == 0) _finish();
	}

	function _scanNotes():Void
	{
		if (PlayState.SONG != null && PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 0)
			_enqueueAuto(PlayState.SONG.arrowSkin);
		if (PlayState.SONG != null && PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0)
			_enqueueAuto(PlayState.SONG.splashSkin);

		for (key in ['noteSkins/NOTE_assets', 'noteSplashes', 'noteSplashes/noteSplashes-electric'])
			_enqueueAuto(key);
	}

	function _scanGameplayUI():Void
	{
		for (r in ['sick', 'good', 'bad', 'shit']) _enqueueAuto(r);
		for (i in 0...10) _enqueueAuto('num$i');
		_enqueueAuto('healthBar');
		_enqueueAuto('iconGrid');
	}

	function _scanCharacter(charName:String):Void
	{
		try {
			var txt:String = Paths.getTextFromFile('characters/$charName.json');
			if (txt == null) {
				#if debug trace('[SpritePreloader] Character not found: $charName'); #end
				return;
			}

			var data:Dynamic = haxe.Json.parse(txt);
			if (data == null || data.image == null) return;

			var imgPath:String = data.image;
			#if debug trace('[SpritePreloader] Scanning character: $charName → $imgPath'); #end

			_enqueueAuto(imgPath);

			var iconName:String = data.healthicon != null ? data.healthicon : charName;
			_enqueueAuto('icons/icon-$iconName');
		}
		catch (e:Dynamic) {
			#if debug trace('[SpritePreloader] ⚠ Character "$charName": $e'); #end
		}
	}

	function _scanStage(stageName:String):Void
	{
		try {
			var txt:String = Paths.getTextFromFile('stages/$stageName.json');
			if (txt == null) return;

			var data:Dynamic = haxe.Json.parse(txt);
			if (data == null || data.objects == null) return;

			for (obj in (data.objects : Array<Dynamic>))
				if (obj.image != null) _enqueueAuto(obj.image);
		}
		catch (e:Dynamic) {
			#if debug trace('[SpritePreloader] ⚠ Stage "$stageName": $e'); #end
		}
	}

	function _enqueueAuto(key:String):Void
	{
		if (Paths.fileExists('images/$key.xml', TEXT)) { _queue.push({path:key, type:SPARROW}); return; }
		if (Paths.fileExists('images/$key.txt', TEXT)) { _queue.push({path:key, type:PACKER}); return; }
		if (Paths.fileExists('images/$key.png', IMAGE)) { _queue.push({path:key, type:IMAGE}); return; }

		#if debug trace('[SpritePreloader] skiped (not found): $key'); #end
	}

	function _execute(task:PreloadTask):Void
	{
		try {
			switch (task.type) {
				case IMAGE:   Paths.image(task.path);
				case SPARROW: Paths.getSparrowAtlas(task.path);
				case PACKER:  Paths.getPackerAtlas(task.path);
			}
			#if debug trace('[SpritePreloader] loaded: ${task.path}'); #end
		}
		catch (e:Dynamic) {
			#if debug trace('[SpritePreloader] ⚠ Error (${task.path}): $e'); #end
		}
	}

	function _finish():Void
	{
		if (_finished) return;
		_finished = true;
		#if debug trace('[SpritePreloader] done $_done'); #end
		if (onComplete != null) onComplete();
	}
}
