package states;

import flixel.FlxState;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import backend.StageData;
import backend.SpritePreloader;
import backend.LocalAtlasTextures;
import openfl.utils.Assets;
import lime.utils.Assets as LimeAssets;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
import haxe.io.Path;
import lime.app.Promise;
import lime.app.Future;

class LoadingState extends MusicBeatState
{
	static inline var MIN_TIME:Float = 0.0;
	
	var target:FlxState;
	var stopMusic:Bool;
	var directory:String;

	var _manifestReady:Bool = false;
	var _audioReady:Bool    = false;
	var _preloadDone:Bool   = false;
	var _minTimeDone:Bool   = false;
	var _switching:Bool     = false;
	
	var _audioTotal:Int     = 0;
	var _audioLoaded:Int    = 0;

	var load:FlxSprite;
	var loadBar:FlxSprite;
	var _barTarget:Float = 0;

	var _preloader:SpritePreloader;
	var _preloadProgress:Float = 0;

	function new(target:FlxState, stopMusic:Bool, directory:String)
	{
		super();
		this.target    = target;
		this.stopMusic = stopMusic;
		this.directory = directory;
	}

	override function create()
	{
		loadBar = new FlxSprite(0, FlxG.height - 20).makeGraphic(FlxG.width, 10, 0xffff16d2);
		loadBar.screenCenter(X);
		loadBar.scale.x = 0;

		load = new FlxSprite(1100, 540);
		LocalAtlasTextures.applyToSprite(load, 'loading', 'load_group');
		load.animation.addByPrefix('idle', 'load', 24, true);
		load.animation.play('idle');
		load.scale.set(0.5,0.5);
		load.antialiasing = ClientPrefs.data.antialiasing;
		load.alpha = 0;
		FlxTween.tween(load, {alpha: 1}, 0.5);
		add(load);

		if (MIN_TIME <= 0) {
			_minTimeDone = true;
			_tryFinish();
		} else {
			new FlxTimer().start(MIN_TIME, function(_) {
				_minTimeDone = true;
				_tryFinish();
			});
		}

		FlxG.camera.fade(FlxG.camera.bgColor, 0.5, true);
		_startManifest();
		_startSpritePreloader();
	}

	function _startManifest():Void
	{
		_initSongsManifest().onComplete(function(_) {
			_manifestReady = true;
			_startAudio();
		}).onError(function(e) {
			_manifestReady = true;
			_startAudio();
		});
	}

	function _startAudio():Void
	{
		if (PlayState.SONG == null) {
			_audioReady = true;
			_tryFinish();
			return;
		}

		var song = PlayState.SONG;
		_audioTotal = song.needsVoices ? 2 : 1;
		_audioLoaded = 0;

		try {
			Paths.inst(song.song);
			_audioLoaded++;
			if (song.needsVoices) {
				Paths.voices(song.song);
				_audioLoaded++;
			}
		} catch(e:Dynamic) {
			_audioLoaded = _audioTotal;
		}

		_audioReady = true;
		_tryFinish();
	}

	function _startSpritePreloader():Void
	{
		_preloader = new SpritePreloader();
		_preloader.tasksPerTick = 16;
		_preloader.onProgress = function(p) { _preloadProgress = p; };
		_preloader.onComplete = function() {
			_preloadDone = true;
			_tryFinish();
		};

		if (PlayState.SONG != null)
			_preloader.start(PlayState.SONG.song);
		else
			_preloader.startMenuPreload();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (_preloader != null) _preloader.tick();

		var audioP  = (_audioTotal > 0) ? (_audioLoaded / _audioTotal) : (_audioReady ? 1.0 : 0.0);
		var texP    = _preloadProgress;
		var manifestP = _manifestReady ? 1.0 : 0.0;
		_barTarget  = (audioP + texP + manifestP) / 3.0;
		
		if (loadBar != null) loadBar.scale.x += 0.15 * (_barTarget - loadBar.scale.x);
	}

	function _tryFinish():Void
	{
		if (_switching) return;
		if (!_audioReady || !_preloadDone || !_minTimeDone) return;

		_switching = true;
		if (loadBar != null) loadBar.scale.x = 1;

		new FlxTimer().start(3.0, function(tmr:FlxTimer) {

			FlxTween.tween(load, {alpha: 0}, 0.5, {
				onComplete: function(twn:FlxTween) {
					if (stopMusic && FlxG.sound.music != null)
						FlxG.sound.music.stop();

					MusicBeatState.switchState(target);
				}
			});
		});
	}

	override function destroy()
	{
		_preloader = null;
		super.destroy();
	}

	inline static public function loadAndSwitchState(target:FlxState, stopMusic = false)
	{
		MusicBeatState.switchState(getNextState(target, stopMusic));
	}

	static function getNextState(target:FlxState, stopMusic = false):FlxState
	{
		var directory = 'shared';
		var weekDir   = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;
		if (weekDir != null && weekDir.length > 0 && weekDir != '')
			directory = weekDir;

		Paths.setCurrentLevel(directory);
		return new LoadingState(target, stopMusic, directory);
	}

	static function _initSongsManifest():Future<AssetLibrary>
	{
		var id = "songs";
		var existing = LimeAssets.getLibrary(id);
		if (existing != null) return Future.withValue(existing);

		var promise  = new Promise<AssetLibrary>();
		var path     = id;
		var rootPath:String = null;

		@:privateAccess
		var libraryPaths = LimeAssets.libraryPaths;
		if (libraryPaths.exists(id)) {
			path     = libraryPaths[id];
			rootPath = Path.directory(path);
		} else {
			if (StringTools.endsWith(path, ".bundle")) {
				rootPath = path;
				path    += "/library.json";
			} else {
				rootPath = Path.directory(path);
			}
			@:privateAccess
			path = LimeAssets.__cacheBreak(path);
		}

		AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest) {
			if (manifest == null) { promise.error("Cannot parse manifest: $id"); return; }
			var lib = AssetLibrary.fromManifest(manifest);
			if (lib == null) { promise.error("Cannot open library: $id"); return; }
			@:privateAccess LimeAssets.libraries.set(id, lib);
			lib.onChange.add(LimeAssets.onChange.dispatch);
			promise.completeWith(Future.withValue(lib));
		}).onError(function(e) {
			promise.error('No library: $id ($e)');
		});
		return promise.future;
	}
}