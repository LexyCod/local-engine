package backend;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

/**
 *   // Sparrow (PNG+XML)
 *   var frames = LocalAtlasTextures.getSparrow("images/notes/NOTE_assets");
 *
 *   // Adobe Animate атлас
 *   var sprite = LocalAtlasTextures.getAnimateSprite(x, y, "images/characters/dad");
 *
 *   // Something
 *   var frames = LocalAtlasTextures.getAuto("images/something");
 *
 *   // Groups
 *   LocalAtlasTextures.registerGroup("characters", "images/characters/dad");
 *   LocalAtlasTextures.unloadGroup("characters");
 */

#if flxanimate
import flxanimate.FlxAnimate;
#end

typedef AtlasEntry = {
	var key:String;
	var group:String;
	var format:AtlasFormat;
	var frames:FlxAtlasFrames;
	var sizeBytes:Int;
	var loadTime:Float;
	var hitCount:Int;
	var lastUsed:Float;
}

enum AtlasFormat {
	SPARROW;    // PNG + XML
	PACKER;     // PNG + TXT
	ANIMATE;    // Adobe Animate: Animation.json + spritemap1.json + spritemap1.png
	UNKNOWN;
}

class LocalAtlasTextures
{
	static var _cache:Map<String, AtlasEntry>        = new Map();
	static var _groups:Map<String, Array<String>>    = new Map();
	static var _pinnedGroups:Array<String>           = [];

	static var _totalLoaded:Int  = 0;
	static var _totalHits:Int    = 0;
	static var _totalMisses:Int  = 0;

	public static function init()
	{
		_defineGroup('notes', [
			'images/notes/NOTE_assets',
			'images/notes/noteSplashes',
			'images/notes/NOTE_hold_assets',
		], true);

		_defineGroup('gameplay_ui', [
			'images/ui/sick', 'images/ui/good',
			'images/ui/bad',  'images/ui/shit',
			'images/ui/num0', 'images/ui/num1', 'images/ui/num2',
			'images/ui/num3', 'images/ui/num4', 'images/ui/num5',
			'images/ui/num6', 'images/ui/num7', 'images/ui/num8',
			'images/ui/num9', 'images/healthBar',
		], true);

		#if debug
		trace('[LocalAtlasTextures] Init');
		#end
	}

	public static function getSparrow(path:String, ?group:String):FlxAtlasFrames
	{
		return _getFrames(path, SPARROW, group);
	}


	public static function getPacker(path:String, ?group:String):FlxAtlasFrames
	{
		return _getFrames(path, PACKER, group);
	}

	public static function getAuto(path:String, ?group:String):FlxAtlasFrames
	{
		var fmt = _detectFormat(path);
		if (fmt == ANIMATE)
		{
			#if debug trace('[LocalAtlasTextures] getAuto: $path → ANIMATE (use getAnimateSprite)'); #end
			return null;
		}
		return _getFrames(path, fmt, group);
	}


	public static function applyToSprite(sprite:FlxSprite, path:String, ?group:String)
	{
		var fmt = _detectFormat(path);
		switch (fmt)
		{
			case SPARROW:
				sprite.frames = getSparrow(path, group);
			case PACKER:
				sprite.frames = getPacker(path, group);
			case ANIMATE:
				#if debug
				trace('[LocalAtlasTextures] ⚠ $path — Adobe Animate atlas. use getAnimateSprite()');
				#end
			default:
				sprite.frames = getSparrow(path, group);
		}
	}

	#if flxanimate

	public static function getAnimateSprite(x:Float, y:Float, folderPath:String, ?group:String):FlxAnimate
	{
		var resolvedPath = _resolveAnimatePath(folderPath);

		var sprite = new FlxAnimate(x, y, resolvedPath);

		if (group != null) registerGroup(group, folderPath);

		CacheManager.onTextureLoaded(folderPath, null);

		#if debug
		trace('[LocalAtlasTextures] FlxAnimate: $folderPath → $resolvedPath');
		#end

		return sprite;
	}
	#else
	public static function getAnimateSprite(x:Float, y:Float, folderPath:String, ?group:String):FlxSprite
	{
		return new FlxSprite(x, y);
	}
	#end

	public static function detectFormat(path:String):String
	{
		return switch (_detectFormat(path)) {
			case SPARROW:  'SPARROW';
			case PACKER:   'PACKER';
			case ANIMATE:  'ANIMATE';
			default:       'UNKNOWN';
		};
	}

	public static function registerGroup(groupName:String, path:String):Void
	{
		if (!_groups.exists(groupName)) _groups.set(groupName, []);
		var arr = _groups.get(groupName);
		if (arr.indexOf(path) == -1) arr.push(path);
		if (_cache.exists(path)) _cache.get(path).group = groupName;
	}

	public static function preloadGroup(groupName:String)
	{
		var paths = _groups.get(groupName);
		if (paths == null) { #if debug trace('[LocalAtlasTextures] Group not found: $groupName'); #end return; }

		for (path in paths)
			if (!_cache.exists(path))
				getAuto(path, groupName);

		#if debug trace('[LocalAtlasTextures] preloadGroup("$groupName") ready'); #end
	}

	public static function unloadGroup(groupName:String):Void
	{
		if (_pinnedGroups.indexOf(groupName) != -1)
		{
			#if debug trace('[LocalAtlasTextures] "$groupName" pinned — skip'); #end
			return;
		}

		var keys = _groups.get(groupName);
		if (keys == null) return;

		var count = 0;
		for (key in keys)
		{
			if (_cache.exists(key)) { CacheManager.evict(key); _cache.remove(key); count++; }
		}
		_groups.remove(groupName);
		openfl.system.System.gc();

		#if debug trace('[LocalAtlasTextures] unloadGroup("$groupName"): $count atlas'); #end
	}

	public static function clearNonPinned():Void
	{
		for (key in _cache.keys())
		{
			var e = _cache.get(key);
			if (_pinnedGroups.indexOf(e.group) == -1)
			{
				CacheManager.evict(key);
				_cache.remove(key);
			}
		}
		openfl.system.System.gc();
	}

	public static function getStats():String
	{
		var count = 0; var totalMB = 0;
		var formats = [SPARROW => 0, PACKER => 0, ANIMATE => 0];
		for (e in _cache) {
			count++; totalMB += e.sizeBytes;
			if (formats.exists(e.format)) formats[e.format]++;
		}
		var hitRate = (_totalHits+_totalMisses) > 0
			? Math.round(_totalHits/(_totalHits+_totalMisses)*100) : 0;
		return '[LocalAtlasTextures]\n'
			+ '  Cached: $count (~${Math.round(totalMB/1024/1024)}MB)\n'
			+ '  Sparrow:${formats[SPARROW]} Packer:${formats[PACKER]} Animate:${formats[ANIMATE]}\n'
			+ '  Hit rate: $hitRate% | Groups: ${Lambda.count(_groups)}';
	}

	static function _getFrames(path:String, fmt:AtlasFormat, ?group:String):FlxAtlasFrames
	{
		if (_cache.exists(path))
		{
			var e = _cache.get(path);
			e.hitCount++; e.lastUsed = haxe.Timer.stamp();
			if (group != null && e.group == '') e.group = group;
			_totalHits++;
			return e.frames;
		}

		_totalMisses++; _totalLoaded++;
		var t = haxe.Timer.stamp();

		var frames:FlxAtlasFrames = switch (fmt) {
			case PACKER:  Paths.getPackerAtlas(path);
			default:      Paths.getSparrowAtlas(path);
		}

		if (frames == null) { #if debug trace('[LocalAtlasTextures] not found: $path'); #end return null; }

		var sizeBytes = 0;
		if (frames.parent != null && frames.parent.bitmap != null)
			sizeBytes = frames.parent.bitmap.width * frames.parent.bitmap.height * 4;

		_cache.set(path, {
			key: path, group: group ?? '', format: fmt, frames: frames,
			sizeBytes: sizeBytes, loadTime: haxe.Timer.stamp()-t,
			hitCount: 1, lastUsed: haxe.Timer.stamp()
		});

		if (group != null) registerGroup(group, path);

		#if debug
		var ms = Math.round((haxe.Timer.stamp()-t)*1000);
		trace('[LocalAtlasTextures] +${switch(fmt){case PACKER:"PKR";default:"SRW";}} $path (~${Math.round(sizeBytes/1024/1024)}MB, ${ms}ms)');
		#end

		return frames;
	}

	static function _detectFormat(path:String):AtlasFormat
	{
		var animPath = Paths.getPath('$path/Animation.json', TEXT);
		if (openfl.utils.Assets.exists(animPath)) return ANIMATE;

		var xmlPath = Paths.getPath('$path.xml', TEXT);
		if (openfl.utils.Assets.exists(xmlPath)) return SPARROW;

		var txtPath = Paths.getPath('$path.txt', TEXT);
		if (openfl.utils.Assets.exists(txtPath)) return PACKER;

		return SPARROW;
	}

	static function _resolveAnimatePath(folderPath:String):String
	{
		var modPath = Paths.getPath('$folderPath/Animation.json', TEXT);
		if (openfl.utils.Assets.exists(modPath))
		{
			var parts = modPath.split('/');
			parts.pop();
			return parts.join('/');
		}
		return folderPath;
	}

	static function _defineGroup(name:String, paths:Array<String>, pinned:Bool):Void
	{
		_groups.set(name, paths.copy());
		if (pinned && _pinnedGroups.indexOf(name) == -1)
			_pinnedGroups.push(name);
	}
}
