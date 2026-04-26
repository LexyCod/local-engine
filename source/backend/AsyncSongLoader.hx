package backend;

import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import openfl.media.Sound;
import sys.thread.Thread;
import sys.thread.Mutex;

class AsyncSongLoader
{
	static var _states:Map<String, LoadState> = new Map();
	static var _mutex:Mutex = new Mutex();

	public static function preload(songName:String, ?difficulty:String = 'Normal'):Void
	{
		var key = _makeKey(songName, difficulty);

		_mutex.acquire();
		var alreadyLoading = _states.exists(key);
		_mutex.release();

		if (alreadyLoading)
		{
			#if debug trace('[AsyncSongLoader] $key loading Start'); #end
			return;
		}

		_mutex.acquire();
		_states.set(key, Loading);
		_mutex.release();

		#if debug trace('[AsyncSongLoader] Preload startes: $key'); #end

		Thread.create(function()
		{
			try
			{
				_loadSongAssets(songName, difficulty, key);
			}
			catch (e:Dynamic)
			{
				#if debug trace('[AsyncSongLoader] Error $key: $e'); #end
				_mutex.acquire();
				_states.set(key, Failed);
				_mutex.release();
			}
		});
	}

	public static function isReady(songName:String, ?difficulty:String = 'Normal'):Bool
	{
		var key = _makeKey(songName, difficulty);
		_mutex.acquire();
		var state = _states.get(key);
		_mutex.release();
		return state == Ready;
	}

	public static function isLoading(songName:String, ?difficulty:String = 'Normal'):Bool
	{
		var key = _makeKey(songName, difficulty);
		_mutex.acquire();
		var state = _states.get(key);
		_mutex.release();
		return state == Loading;
	}

	public static function getStatus(songName:String, ?difficulty:String = 'Normal'):String
	{
		var key = _makeKey(songName, difficulty);
		_mutex.acquire();
		var state = _states.get(key);
		_mutex.release();
		return switch (state) {
			case null:    'not queued';
			case Loading: 'loading...';
			case Ready:   'READY';
			case Failed:  'FAILED';
		};
	}

	public static function clear():Void
	{
		_mutex.acquire();
		_states.clear();
		_mutex.release();
		#if debug trace('[AsyncSongLoader] Cash cleared'); #end
	}

	public static function getStats():String
	{
		_mutex.acquire();
		var ready = 0;
		var loading = 0;
		var failed = 0;
		for (s in _states)
		{
			switch (s) {
				case Ready:   ready++;
				case Loading: loading++;
				case Failed:  failed++;
				default:
			}
		}
		_mutex.release();
		return '[AsyncSongLoader] Ready: $ready | Loading: $loading | Failed: $failed';
	}


	static function _makeKey(song:String, diff:String):String
	{
		return '${song.toLowerCase()}_${diff.toLowerCase()}';
	}

	static function _loadSongAssets(songName:String, difficulty:String, key:String):Void
	{
		var formatSong = Paths.formatToSongPath(songName);

		var instPath = Paths.inst(songName);
		if (OpenFlAssets.exists(instPath, SOUND))
		{
			OpenFlAssets.getSound(instPath);
		}

		var voicesPath = Paths.voices(songName);
		if (OpenFlAssets.exists(voicesPath, SOUND))
		{
			OpenFlAssets.getSound(voicesPath);
		}

		var chartPath = Paths.json('${formatSong}/${formatSong}');
		if (OpenFlAssets.exists(chartPath, TEXT))
		{
			OpenFlAssets.getText(chartPath);
		}

		_mutex.acquire();
		_states.set(key, Ready);
		_mutex.release();

		#if debug trace('[AsyncSongLoader]  $key ready'); #end
	}
}

enum LoadState
{
	Loading;
	Ready;
	Failed;
}
