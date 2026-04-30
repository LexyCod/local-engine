package backend;

import haxe.io.Bytes;
import haxe.zip.Entry;
import haxe.zip.Reader;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;

using StringTools;

typedef ZipCache = {
	var entries:Map<String, Entry>;
	var rootPrefix:String;
}

class ZipModManager
{
	static var caches:Map<String, ZipCache> = new Map();

	public static function getModNames():Array<String>
	{
		var result:Array<String> = [];
		var modsFolder = Paths.mods();
		if (!FileSystem.exists(modsFolder)) return result;

		for (file in FileSystem.readDirectory(modsFolder))
		{
			var path = haxe.io.Path.join([modsFolder, file]);
			if (!FileSystem.isDirectory(path) && file.toLowerCase().endsWith(".zip"))
			{
				var modName = file.substr(0, file.length - 4);
				if (modName.length > 0 && !result.contains(modName))
					result.push(modName);
			}
		}
		return result;
	}

	public static function hasZip(modName:String):Bool
	{
		return FileSystem.exists(zipPath(modName));
	}

	public static function exists(modName:String, path:String):Bool
	{
		var entry = getEntry(modName, path);
		return entry != null && !isDirectory(entry);
	}

	public static function getBytes(modName:String, path:String):Bytes
	{
		var entry = getEntry(modName, path);
		if (entry == null || isDirectory(entry)) return null;

		try
		{
			return Reader.unzip(entry);
		}
		catch (e:Dynamic)
		{
			#if (debug || dev) trace('[ZipModManager] Could not read "$path" from "$modName.zip": $e'); #end
		}
		return null;
	}

	public static function getText(modName:String, path:String):String
	{
		var bytes = getBytes(modName, path);
		return bytes != null ? bytes.toString() : null;
	}

	public static function listFiles(modName:String, prefix:String = "", extension:String = null):Array<String>
	{
		var cache = getCache(modName);
		if (cache == null) return [];

		prefix = normalizePath(prefix);
		if (prefix.length > 0 && !prefix.endsWith("/")) prefix += "/";
		if (extension != null && extension.length > 0 && !extension.startsWith("."))
			extension = "." + extension;

		var result:Array<String> = [];
		for (storedPath in cache.entries.keys())
		{
			var entry = cache.entries.get(storedPath);
			if (entry == null || isDirectory(entry)) continue;

			var path = stripRoot(cache, storedPath);
			if (prefix.length > 0 && !path.startsWith(prefix)) continue;
			if (extension != null && extension.length > 0 && !path.toLowerCase().endsWith(extension.toLowerCase())) continue;
			if (!result.contains(path)) result.push(path);
		}
		result.sort(Reflect.compare);
		return result;
	}

	public static function closeAll():Void
	{
		caches.clear();
	}

	static function getEntry(modName:String, path:String):Entry
	{
		var cache = getCache(modName);
		if (cache == null) return null;

		var normalizedPath = normalizePath(path);
		var entry = cache.entries.get(normalizedPath);
		if (entry != null) return entry;

		entry = cache.entries.get(normalizePath(normalizeModName(modName) + "/" + normalizedPath));
		if (entry != null) return entry;

		if (cache.rootPrefix != null && cache.rootPrefix.length > 0)
			return cache.entries.get(cache.rootPrefix + "/" + normalizedPath);

		return null;
	}

	static function getCache(modName:String):ZipCache
	{
		modName = normalizeModName(modName);
		if (modName.length < 1) return null;
		if (caches.exists(modName)) return caches.get(modName);

		var path = zipPath(modName);
		if (!FileSystem.exists(path)) return null;

		var input:FileInput = null;
		try
		{
			input = File.read(path, true);
			var entries:Map<String, Entry> = new Map();
			var roots:Array<String> = [];

			for (entry in Reader.readZip(input))
			{
				if (entry == null || entry.fileName == null) continue;

				var normalizedPath = normalizePath(entry.fileName);
				if (normalizedPath.length < 1) continue;

				entries.set(normalizedPath, entry);

				var slash = normalizedPath.indexOf("/");
				if (slash > 0)
				{
					var root = normalizedPath.substr(0, slash);
					if (!roots.contains(root)) roots.push(root);
				}
			}

			var cache:ZipCache = {
				entries: entries,
				rootPrefix: roots.length == 1 ? roots[0] : ""
			};
			if (input != null)
			{
				try input.close() catch (e:Dynamic) {}
				input = null;
			}
			caches.set(modName, cache);
			return cache;
		}
		catch (e:Dynamic)
		{
			trace('[ZipModManager] Failed to open "$path": $e');
		}
		if (input != null)
		{
			try input.close() catch (e:Dynamic) {}
		}
		return null;
	}

	static function zipPath(modName:String):String
	{
		return Paths.mods(normalizeModName(modName) + ".zip");
	}

	static function normalizeModName(modName:String):String
	{
		if (modName == null) return "";
		modName = normalizePath(modName);
		if (modName.endsWith(".zip")) modName = modName.substr(0, modName.length - 4);
		if (modName.startsWith("mods/")) modName = modName.substr(5);
		return modName;
	}

	static function normalizePath(path:String):String
	{
		if (path == null) return "";
		path = path.replace("\\", "/");
		while (path.startsWith("/")) path = path.substr(1);
		while (path.startsWith("./")) path = path.substr(2);
		return path;
	}

	static function stripRoot(cache:ZipCache, path:String):String
	{
		if (cache.rootPrefix != null && cache.rootPrefix.length > 0 && path.startsWith(cache.rootPrefix + "/"))
			return path.substr(cache.rootPrefix.length + 1);
		return path;
	}

	static function isDirectory(entry:Entry):Bool
	{
		return entry.fileName.endsWith("/") || entry.fileName.endsWith("\\");
	}
}
