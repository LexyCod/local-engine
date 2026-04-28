package states;

import flixel.FlxState;
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

//переделано с нуля нахуй пдорас н рабочий
class LoadingState extends MusicBeatState
{
	static inline var MIN_TIME:Float = 0.5;

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

	var funkay:FlxSprite;
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
		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xffcaff4d);
		bg.antialiasing = ClientPrefs.data.antialiasing;
		//add(bg);

		funkay = new FlxSprite().loadGraphic(Paths.getPath('images/funkay.png', IMAGE));
		funkay.setGraphicSize(0, FlxG.height);
		funkay.updateHitbox();
		funkay.antialiasing = ClientPrefs.data.antialiasing;
		funkay.scrollFactor.set();
		funkay.screenCenter();
		//add(funkay);

		loadBar = new FlxSprite(0, FlxG.height - 20).makeGraphic(FlxG.width, 10, 0xffff16d2);
		loadBar.screenCenter(X);
		loadBar.scale.x = 0;
		//add(loadBar);

		new FlxTimer().start(MIN_TIME, function(_) {
			_minTimeDone = true;
			_tryFinish();
		});

		FlxG.camera.fade(FlxG.camera.bgColor, 0.5, true);

		_startManifest();
		_startSpritePreloader();
	}

	function _startManifest():Void
	{
		_initSongsManifest().onComplete(function(_) {
			#if debug trace('[LoadingState] Manifest ready'); #end
			_manifestReady = true;
			_startAudio(); // аудио только после manifest
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
		var paths:Array<String> = [Paths.inst(song.song)];
		if (song.needsVoices) paths.push(Paths.voices(song.song));

		var toLoad = paths.filter(p -> p != null && !Assets.cache.hasSound(p));

		if (toLoad.length == 0) {
			#if debug trace('[LoadingState] Audio already cached'); #end
			_audioReady = true;
			_tryFinish();
			return;
		}

		_audioTotal  = toLoad.length;
		_audioLoaded = 0;

		for (path in toLoad) {
			#if debug trace('[LoadingState] Loading audio: $path'); #end
			Assets.loadSound(path).onComplete(function(_) {
				_audioLoaded++;
				#if debug trace('[LoadingState] Audio done: $_audioLoaded/$_audioTotal'); #end
				if (_audioLoaded >= _audioTotal) {
					_audioReady = true;
					_tryFinish();
				}
			}).onError(function(e) {
				trace('[LoadingState] ⚠ Audio error: $e');
				_audioLoaded++;
				if (_audioLoaded >= _audioTotal) {
					_audioReady = true;
					_tryFinish();
				}
			});
		}
	}

	function _startSpritePreloader():Void
	{
		_preloader = new SpritePreloader();
		_preloader.onProgress = function(p) { _preloadProgress = p; };
		_preloader.onComplete = function() {
			_preloadDone = true;
			#if debug trace('[LoadingState] Preload done'); #end
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
		loadBar.scale.x += 0.15 * (_barTarget - loadBar.scale.x);

		_tryFinish();
	}

	function _tryFinish():Void
	{
		if (_switching) return;
		if (!_audioReady || !_preloadDone || !_minTimeDone) return;

		_switching = true;
		loadBar.scale.x = 1;

		#if debug trace('[LoadingState] ✓ All ready — switching!'); #end

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		MusicBeatState.switchState(target);
	}

	override function destroy()
	{
		super.destroy();
		_preloader = null;
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
		#if debug trace('[LoadingState] asset folder: $directory'); #end

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
