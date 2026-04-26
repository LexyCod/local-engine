package backend;

/**
 * LOCAL ENGINE - CacheManager
 * usage:
 *   CacheManager.pin("shared/notes");
 *   CacheManager.evictGroup("week1");
 *   CacheManager.clear();
 *   CacheManager.update(elapsed);
 *   trace(CacheManager.getStats());
 */

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;

typedef CacheEntry =
{
	var key:String;
	var lastUsed:Float;
	var sizeBytes:Int;
	var pinned:Bool;
	var hitCount:Int;
}

class CacheManager
{
	/** auto eviction*/
	public static var ramThresholdMB:Int = 768;

	/** MB cleared at a time */
	public static var evictTargetMB:Int = 128;

	public static var checkInterval:Float = 10.0;

	static var _entries:Map<String, CacheEntry> = new Map();
	static var _lastCheck:Float = 0;

	public static var stats = {
		hits: 0,
		misses: 0,
		evictions: 0,
		totalEvictedMB: 0.0
	};

	/**
	 * var g = Paths.image('characters/boyfriend');
	 * CacheManager.track('characters/boyfriend', g);
	 */
	public static function track(key:String, graphic:FlxGraphic):Void
	{
		if (graphic == null) return;

		_touch(key);

		if (!_entries.exists(key))
		{
			var bmp = graphic.bitmap;
			var sizeBytes = (bmp != null) ? bmp.width * bmp.height * 4 : 0;
			_registerEntry(key, sizeBytes);
		}
	}

	public static function pin(key:String):Void
	{
		if (_entries.exists(key))
			_entries[key].pinned = true;
		else
			_entries[key] = _makeEntry(key, true, 0);

		#if debug
		trace('[CacheManager] Pinned: $key');
		#end
	}

	public static function evict(key:String):Bool
	{
		if (!_entries.exists(key)) return false;

		var entry = _entries[key];
		if (entry.pinned)
		{
			#if debug
			trace('[CacheManager] pinned: $key');
			#end
			return false;
		}

		var graphic:FlxGraphic = FlxG.bitmap.get(key);
		if (graphic != null)
		{
			graphic.persist = false;
			graphic.destroyOnNoUse = true;
			FlxG.bitmap.remove(graphic);
		}

		_entries.remove(key);
		stats.evictions++;

		#if debug
		trace('[CacheManager] Evicted: $key');
		#end
		return true;
	}

	public static function update(elapsed:Float):Void
	{
		_lastCheck += elapsed;
		if (_lastCheck < checkInterval) return;
		_lastCheck = 0;
		autoEvict();
	}

	public static function autoEvict():Void
	{
		var currentRAM = getCurrentRAMMB();
		if (currentRAM < ramThresholdMB) return;

		#if debug
		trace('[CacheManager] RAM: ${currentRAM}MB >  ${ramThresholdMB}MB, cleared...');
		#end

		var candidates:Array<CacheEntry> = [];
		for (entry in _entries)
			if (!entry.pinned) candidates.push(entry);

		candidates.sort((a, b) -> Std.int(a.lastUsed - b.lastUsed));

		var freedBytes:Int = 0;
		var targetBytes:Int = evictTargetMB * 1024 * 1024;

		for (entry in candidates)
		{
			if (freedBytes >= targetBytes) break;

			var graphic:FlxGraphic = FlxG.bitmap.get(entry.key);
			if (graphic != null)
			{
				graphic.persist = false;
				graphic.destroyOnNoUse = true;
				FlxG.bitmap.remove(graphic);
			}

			freedBytes += entry.sizeBytes;
			stats.totalEvictedMB += entry.sizeBytes / 1024 / 1024;
			stats.evictions++;
			_entries.remove(entry.key);
		}

		#if debug
		var freedMB = Math.round(freedBytes / 1024 / 1024);
		trace('[CacheManager] free ~${freedMB}MB. RAM ~${currentRAM - freedMB}MB');
		#end

		openfl.system.System.gc();
	}

	public static function evictGroup(groupTag:String):Void
	{
		var toEvict:Array<String> = [];
		for (key in _entries.keys())
			if (key.indexOf(groupTag) != -1 && !_entries[key].pinned)
				toEvict.push(key);

		for (key in toEvict) evict(key);
		openfl.system.System.gc();

		#if debug
		trace('[CacheManager] Group evict "$groupTag": deleted ${toEvict.length}');
		#end
	}

	public static function clear():Void
	{
		var toEvict:Array<String> = [];
		for (key in _entries.keys())
			if (!_entries[key].pinned) toEvict.push(key);
		for (key in toEvict) evict(key);
		openfl.system.System.gc();
	}

	public static function getCurrentRAMMB():Int
	{
		#if cpp
		return Std.int(cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE) / 1024 / 1024);
		#else
		return Std.int(openfl.system.System.totalMemory / 1024 / 1024);
		#end
	}

	public static function getStats():String
	{
		var pinned    = 0;
		var unpinned  = 0;
		var totalSize = 0;
		var count     = 0;

		for (entry in _entries)
		{
			count++;
			if (entry.pinned) pinned++;
			else unpinned++;
			totalSize += entry.sizeBytes;
		}

		var hitRate = (stats.hits + stats.misses > 0)
			? Math.round(stats.hits / (stats.hits + stats.misses) * 100)
			: 0;

		return '[CacheManager]\n'
			+ '  Entries: $count (pinned: $pinned, evictable: $unpinned)\n'
			+ '  Tracked size: ~${Math.round(totalSize / 1024 / 1024)}MB\n'
			+ '  RAM: ~${getCurrentRAMMB()}MB / ${ramThresholdMB}MB\n'
			+ '  Hit rate: $hitRate% (${stats.hits} hits / ${stats.misses} misses)\n'
			+ '  Evictions: ${stats.evictions} (~${Math.round(stats.totalEvictedMB)}MB freed)';
	}

	static function _touch(key:String):Void
	{
		if (_entries.exists(key))
		{
			_entries[key].lastUsed = haxe.Timer.stamp();
			_entries[key].hitCount++;
		}
	}

	static function _registerEntry(key:String, sizeBytes:Int):Void
	{
		if (!_entries.exists(key))
			_entries[key] = _makeEntry(key, false, sizeBytes);
	}

	static function _makeEntry(key:String, pinned:Bool, sizeBytes:Int):CacheEntry
	{
		return {
			key:       key,
			lastUsed:  haxe.Timer.stamp(),
			sizeBytes: sizeBytes,
			pinned:    pinned,
			hitCount:  0
		};
	}
}
