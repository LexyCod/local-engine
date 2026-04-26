package backend;

//LOCAL ENGINE — CacheManager

import flixel.FlxG;
import flixel.graphics.FlxGraphic;

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

	public static var ramThresholdMB:Int = 768;

	public static var evictTargetMB:Int  = 128;

	public static var checkInterval:Float = 8.0;

	static var _entries:Map<String, CacheEntry> = new Map();
	static var _lastCheck:Float = 0;

	public static var stats = {
		hits:           0,
		misses:         0,
		evictions:      0,
		totalEvictedMB: 0.0
	};

	public static function onTextureLoaded(key:String, graphic:FlxGraphic):Void
	{
		if (graphic == null) return;

		if (_entries.exists(key))
		{
			_entries[key].lastUsed = haxe.Timer.stamp();
			_entries[key].hitCount++;
			stats.hits++;
		}
		else
		{
			var bmp = graphic.bitmap;
			var sizeBytes = (bmp != null) ? bmp.width * bmp.height * 4 : 0;
			_entries[key] = {
				key:       key,
				lastUsed:  haxe.Timer.stamp(),
				sizeBytes: sizeBytes,
				pinned:    false,
				hitCount:  1
			};
			stats.misses++;
		}
	}

	public static function pin(keyOrPrefix:String):Void
	{
		var pinned = 0;
		for (key in _entries.keys())
		{
			if (key.indexOf(keyOrPrefix) != -1)
			{
				_entries[key].pinned = true;
				pinned++;
			}
		}
		if (pinned == 0)
		{
			_entries[keyOrPrefix] = {
				key: keyOrPrefix, lastUsed: haxe.Timer.stamp(),
				sizeBytes: 0, pinned: true, hitCount: 0
			};
		}
		#if debug trace('[CacheManager] Pinned: $keyOrPrefix ($pinned entries)'); #end
	}

	public static function evict(key:String):Bool
	{
		if (!_entries.exists(key)) return false;
		var entry = _entries[key];
		if (entry.pinned) { #if debug trace('[CacheManager] not export pinned: $key'); #end return false; }

		_destroyTexture(key);
		stats.evictions++;
		stats.totalEvictedMB += entry.sizeBytes / 1024 / 1024;
		_entries.remove(key);
		#if debug trace('[CacheManager] Evicted: $key'); #end
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

		#if debug trace('[CacheManager] RAM: ${currentRAM}MB > ${ramThresholdMB}MB, LRU...'); #end

		var candidates:Array<CacheEntry> = [];
		for (entry in _entries) if (!entry.pinned) candidates.push(entry);
		candidates.sort((a, b) -> Std.int(a.lastUsed - b.lastUsed));

		var freedBytes  = 0;
		var targetBytes = evictTargetMB * 1024 * 1024;
		var count       = 0;

		for (entry in candidates)
		{
			if (freedBytes >= targetBytes) break;
			_destroyTexture(entry.key);
			freedBytes           += entry.sizeBytes;
			stats.totalEvictedMB += entry.sizeBytes / 1024 / 1024;
			stats.evictions++;
			_entries.remove(entry.key);
			count++;
		}

		#if debug
		trace('[CacheManager] free ~${Math.round(freedBytes/1024/1024)}MB ($count textures)');
		#end
		openfl.system.System.gc();
	}

	public static function evictGroup(groupTag:String):Void
	{
		var toEvict:Array<String> = [];
		for (key in _entries.keys())
			if (key.indexOf(groupTag) != -1 && !_entries[key].pinned)
				toEvict.push(key);

		for (key in toEvict) { _destroyTexture(key); stats.evictions++; _entries.remove(key); }
		openfl.system.System.gc();
		#if debug trace('[CacheManager] evictGroup("$groupTag"): ${toEvict.length} textures'); #end
	}

	public static function clear():Void
	{
		var toEvict = [for (key in _entries.keys()) if (!_entries[key].pinned) key];
		for (key in toEvict) { _destroyTexture(key); stats.evictions++; _entries.remove(key); }
		openfl.system.System.gc();
		#if debug trace('[CacheManager] clear(): ${toEvict.length} textures'); #end
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
		var pinned = 0; var unpinned = 0; var totalSize = 0;
		for (e in _entries) { if (e.pinned) pinned++; else unpinned++; totalSize += e.sizeBytes; }
		var total = stats.hits + stats.misses;
		var hitRate = total > 0 ? Math.round(stats.hits / total * 100) : 0;
		var ram = getCurrentRAMMB();
		return '[CacheManager]\n'
			+ '  Tracked: ${pinned+unpinned} (pinned:$pinned evictable:$unpinned)\n'
			+ '  Size: ~${Math.round(totalSize/1024/1024)}MB\n'
			+ '  RAM: ~${ram}MB / ${ramThresholdMB}MB (${Math.round(ram/ramThresholdMB*100)}%)\n'
			+ '  Hit rate: $hitRate% | Evictions: ${stats.evictions} (~${Math.round(stats.totalEvictedMB)}MB freed)';
	}

	static function _destroyTexture(key:String):Void
	{
		var obj = Paths.currentTrackedAssets.get(key);
		if (obj != null)
		{
			@:privateAccess FlxG.bitmap._cache.remove(key);
			openfl.Assets.cache.removeBitmapData(key);
			Paths.currentTrackedAssets.remove(key);
			obj.persist = false;
			obj.destroyOnNoUse = true;
			obj.destroy();
		}
		else
		{
			@:privateAccess
			var graphic = FlxG.bitmap._cache.get(key);
			if (graphic != null)
			{
				graphic.persist = false;
				graphic.destroyOnNoUse = true;
				@:privateAccess FlxG.bitmap._cache.remove(key);
				openfl.Assets.cache.removeBitmapData(key);
			}
		}
	}
}
