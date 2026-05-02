package backend;

import haxe.io.Bytes;
import haxe.zip.Entry;
import haxe.zip.Reader;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;

using StringTools;

typedef ZipEntry = {
	var fileName:String;
	var data:Bytes;
	var compressed:Bool;
	var compressedSize:Int;
	var fileSize:Int;
	var crc32:Null<Int>;
	var extraFields:haxe.ds.List<haxe.zip.ExtraField>;
}

typedef ZipCache = {
	var entries:Map<String, Entry>;
	var rootPrefix:String;
	var isAssets:Bool;
}

class ZipModManager
{
	static var caches:Map<String, ZipCache> = new Map();
	static var _assetsCacheKey:String = "__assets__";

	public static function getModNames():Array<String>
	{
		var result:Array<String> = [];
		var modsFolder = 'mods/';
		if (!FileSystem.exists(modsFolder)) return result;

		for (file in FileSystem.readDirectory(modsFolder))
		{
			if (!file.toLowerCase().endsWith('.zip')) continue;
			var name = file.substr(0, file.length - 4);
			if (name.toLowerCase() == 'assets') continue;
			if (name.length > 0 && !result.contains(name))
				result.push(name);
		}
		return result;
	}

	public static function hasZip(modName:String):Bool
	{
		return FileSystem.exists(_zipPath(modName));
	}

	public static function hasAssetsZip():Bool
	{
		return FileSystem.exists('mods/assets.zip') || FileSystem.exists('assets.zip');
	}

	public static function exists(modName:String, path:String):Bool
	{
		var entry = _getEntry(modName, path);
		return entry != null && !_isDir(entry);
	}

	public static function getBytes(modName:String, path:String):Bytes
	{
		var entry = _getEntry(modName, path);
		if (entry == null || _isDir(entry)) return null;
		try { return Reader.unzip(entry); }
		catch (e:Dynamic) { trace('[Zip] read error "$path" in "$modName": $e'); }
		return null;
	}

	public static function getText(modName:String, path:String):String
	{
		var b = getBytes(modName, path);
		return b != null ? b.toString() : null;
	}

	public static function listFiles(modName:String, prefix:String = '', extension:String = null):Array<String>
	{
		var cache = _getCache(modName);
		if (cache == null) return [];

		prefix = _norm(prefix);
		if (prefix.length > 0 && !prefix.endsWith('/')) prefix += '/';
		if (extension != null && !extension.startsWith('.')) extension = '.' + extension;

		var result:Array<String> = [];
		for (stored in cache.entries.keys())
		{
			var entry = cache.entries.get(stored);
			if (entry == null || _isDir(entry)) continue;
			var path = _stripRoot(cache, stored);
			if (prefix.length > 0 && !path.startsWith(prefix)) continue;
			if (extension != null && !path.toLowerCase().endsWith(extension.toLowerCase())) continue;
			if (!result.contains(path)) result.push(path);
		}
		result.sort(Reflect.compare);
		return result;
	}

	public static function listAllFiles(modName:String):Array<String>
	{
		return listFiles(modName, '', null);
	}

	public static function getAssetsText(path:String):String
	{
		var b = getAssetsBytes(path);
		return b != null ? b.toString() : null;
	}

	public static function getAssetsBytes(path:String):Bytes
	{
		path = _norm(path);
		var sources = _getAssetsSources();
		for (src in sources)
		{
			var e = _findInCache(src, path);
			if (e != null) try { return Reader.unzip(e); } catch (_) {}
			var e2 = _findInCache(src, 'assets/$path');
			if (e2 != null) try { return Reader.unzip(e2); } catch (_) {}
		}
		return null;
	}

	public static function assetsExists(path:String):Bool
	{
		path = _norm(path);
		for (src in _getAssetsSources())
			if (_findInCache(src, path) != null || _findInCache(src, 'assets/$path') != null) return true;
		return false;
	}

	static function _getAssetsSources():Array<ZipCache>
	{
		var result:Array<ZipCache> = [];
		if (selectedAssetsZip != null)
		{
			var c = _getAssetsCache(selectedAssetsZip);
			if (c != null) result.push(c);
		}
		for (loc in ['mods/assets.zip', 'assets.zip'])
		{
			if (selectedAssetsZip == loc) continue;
			var c = _getAssetsCache(loc);
			if (c != null) result.push(c);
		}
		return result;
	}

	public static var selectedAssetsZip:String = null;

	public static function getAvailableAssetsZips():Array<String>
	{
		var result:Array<String> = [];
		for (loc in ['mods/assets.zip', 'assets.zip'])
			if (FileSystem.exists(loc)) result.push(loc);

		if (FileSystem.exists('mods/'))
			for (file in FileSystem.readDirectory('mods/'))
				if (file.toLowerCase().endsWith('.zip') && file.toLowerCase() != 'assets.zip')
				{
					var zipName = file.substr(0, file.length - 4);
					var cache = _loadZip('mods/$file', zipName, false);
					if (cache != null)
						for (k in cache.entries.keys())
							if (_stripRoot(cache, k).startsWith('assets/') || _stripRoot(cache, k).startsWith('images/') || _stripRoot(cache, k).startsWith('data/'))
							{
								if (!result.contains('mods/$file')) result.push('mods/$file');
								break;
							}
				}
		 return result;
	}

	public static function selectAssetsZip(zipPath:String):Void
	{
		selectedAssetsZip = zipPath;
		trace('[Zip] Assets source set to: $zipPath');
	}

	public static function closeAll():Void
	{
		caches.clear();
	}

	public static function diagnose(modName:String):Void
	{
		var cache = _getCache(modName);
		if (cache == null) { trace('[Zip] no cache for: $modName'); return; }
		var count = 0; for (_ in cache.entries) count++;
		trace('[Zip] $modName — $count entries, root="${cache.rootPrefix}"');
		var shown = 0;
		for (k in cache.entries.keys())
		{
			trace('  $k');
			if (++shown >= 40) { trace('  ...more'); break; }
		}
	}

	static function _getEntry(modName:String, path:String):Entry
	{
		var cache = _getCache(modName);
		if (cache == null) return null;
		var n = _norm(path);
		return _findInCache(cache, n);
	}

	static function _findInCache(cache:ZipCache, path:String):Entry
	{
		var e = cache.entries.get(path);
		if (e != null) return e;

		if (cache.rootPrefix != null && cache.rootPrefix.length > 0)
		{
			e = cache.entries.get(cache.rootPrefix + '/' + path);
			if (e != null) return e;
		}

		return null;
	}

	static function _getCache(modName:String):ZipCache
	{
		modName = _normName(modName);
		if (modName.length < 1) return null;
		if (caches.exists(modName)) return caches.get(modName);
		return _loadZip(_zipPath(modName), modName, false);
	}

	static function _getAssetsCache(zipFilePath:String):ZipCache
	{
		var key = _norm(zipFilePath);
		if (caches.exists(key)) return caches.get(key);
		if (!FileSystem.exists(zipFilePath)) return null;
		return _loadZip(zipFilePath, key, true);
	}

	static function _loadZip(filePath:String, cacheKey:String, isAssets:Bool):ZipCache
	{
		if (!FileSystem.exists(filePath)) return null;
		var input:FileInput = null;
		try
		{
			input = File.read(filePath, true);
			var entries:Map<String, Entry> = new Map();
			var roots:Array<String> = [];

			for (entry in Reader.readZip(input))
			{
				if (entry == null || entry.fileName == null) continue;
				var p = _norm(entry.fileName);
				if (p.length < 1) continue;
				entries.set(p, entry);

				var slash = p.indexOf('/');
				if (slash > 0)
				{
					var root = p.substr(0, slash);
					if (!roots.contains(root)) roots.push(root);
				}
			}

			var rootPrefix = '';
			if (roots.length == 1)
			{
				var candidate = roots[0];
				var hasFilesOutsideRoot = false;
				for (k in entries.keys())
					if (!k.startsWith(candidate + '/') && k != candidate) { hasFilesOutsideRoot = true; break; }
				if (!hasFilesOutsideRoot) rootPrefix = candidate;
			}

			try { input.close(); } catch (_) {}

			var cache:ZipCache = { entries: entries, rootPrefix: rootPrefix, isAssets: isAssets };
			caches.set(cacheKey, cache);
			trace('[Zip] loaded $filePath — prefix="$rootPrefix"');
			return cache;
		}
		catch (e:Dynamic)
		{
			trace('[Zip] failed to open "$filePath": $e');
			if (input != null) try { input.close(); } catch (_) {}
		}
		return null;
	}

	static function _stripRoot(cache:ZipCache, path:String):String
	{
		if (cache.rootPrefix != null && cache.rootPrefix.length > 0 && path.startsWith(cache.rootPrefix + '/'))
			return path.substr(cache.rootPrefix.length + 1);
		return path;
	}

	static function _zipPath(modName:String):String
	{
		return 'mods/' + _normName(modName) + '.zip';
	}

	static function _normName(name:String):String
	{
		if (name == null) return '';
		name = _norm(name);
		if (name.endsWith('.zip')) name = name.substr(0, name.length - 4);
		if (name.startsWith('mods/')) name = name.substr(5);
		return name;
	}

	static function _norm(path:String):String
	{
		if (path == null) return '';
		path = path.replace('\\', '/').toLowerCase();
		while (path.startsWith('/')) path = path.substr(1);
		while (path.startsWith('./')) path = path.substr(2);
		return path;
	}

	static function _isDir(entry:Entry):Bool
	{
		return entry.fileName.endsWith('/') || entry.fileName.endsWith('\\');
	}
}
