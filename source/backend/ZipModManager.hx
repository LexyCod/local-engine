package backend;

import haxe.io.Bytes;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Reader;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef ZipAsset = {
	var id:String;
	var path:String;
	var source:String;
	var bytes:Bytes;
	@:optional var file:String;
	@:optional var mod:String;
}

typedef ZipCache = {
	var displayName:String;
	var filePath:String;
	var rootPrefix:String;
	var entries:Map<String, Entry>;
}

class ZipModManager
{
	#if sys
	static var modCaches:Map<String, ZipCache> = null;
	static var modOrder:Array<String> = null;
	static var assetCaches:Array<ZipCache> = null;
	#end

	public static function modRootPaths():Array<String>
	{
		return ['mods', 'content'];
	}

	public static function getModNames():Array<String>
	{
		#if (sys && MODS_ALLOWED)
		ensureModCaches();
		return modOrder.copy();
		#else
		return [];
		#end
	}

	public static function hasMod(mod:String):Bool
	{
		#if (sys && MODS_ALLOWED)
		ensureModCaches();
		return modCaches.exists(mod);
		#else
		return false;
		#end
	}

	public static function modFileExists(mod:String, key:String):Bool
	{
		#if (sys && MODS_ALLOWED)
		return findModEntry(mod, key) != null;
		#else
		return false;
		#end
	}

	public static function getModBytes(mod:String, key:String):Bytes
	{
		#if (sys && MODS_ALLOWED)
		var found:Dynamic = findModEntry(mod, key);
		return found != null ? entryBytes(found.entry) : null;
		#else
		return null;
		#end
	}

	public static function getModText(mod:String, key:String):String
	{
		var bytes:Bytes = getModBytes(mod, key);
		return bytes != null ? bytes.toString() : null;
	}

	public static function getModAsset(mod:String, key:String):ZipAsset
	{
		#if (sys && MODS_ALLOWED)
		var found:Dynamic = findModEntry(mod, key);
		if (found == null) return null;

		var path:String = found.path;
		return {
			id: 'zip://mod/$mod/$path',
			path: path,
			source: found.cache.filePath,
			bytes: entryBytes(found.entry),
			mod: mod
		};
		#else
		return null;
		#end
	}

	public static function listModFiles(mod:String, folder:String = '', extension:String = ''):Array<String>
	{
		var files:Array<String> = [];
		#if (sys && MODS_ALLOWED)
		ensureModCaches();
		var cache:ZipCache = modCaches.get(mod);
		if (cache == null) return files;

		folder = normalizeLookupPath(folder);
		if (folder.length > 0 && !folder.endsWith('/')) folder += '/';
		extension = extension.toLowerCase();

		for (entryPath in cache.entries.keys())
		{
			var path:String = logicalModPath(cache, mod, entryPath);
			if (path.length < 1 || path.endsWith('/')) continue;
			if (folder.length > 0 && !path.startsWith(folder)) continue;
			if (extension.length > 0 && !path.toLowerCase().endsWith(extension)) continue;
			if (!files.contains(path)) files.push(path);
		}
		#end
		return files;
	}

	public static function assetExists(path:String):Bool
	{
		#if sys
		return findAssetEntry(path) != null;
		#else
		return false;
		#end
	}

	public static function getAssetBytes(path:String):Bytes
	{
		#if sys
		var found:Dynamic = findAssetEntry(path);
		return found != null ? entryBytes(found.entry) : null;
		#else
		return null;
		#end
	}

	public static function getAssetText(path:String):String
	{
		var bytes:Bytes = getAssetBytes(path);
		return bytes != null ? bytes.toString() : null;
	}

	public static function getBytesFromId(id:String):Bytes
	{
		#if sys
		if (id == null || !id.startsWith('zip://')) return null;

		if (id.startsWith('zip://mod/'))
		{
			var rest:String = id.substr('zip://mod/'.length);
			var slash:Int = rest.indexOf('/');
			if (slash <= 0) return null;
			return getModBytes(rest.substr(0, slash), rest.substr(slash + 1));
		}

		if (id.startsWith('zip://asset/'))
		{
			ensureAssetCaches();
			var rest:String = id.substr('zip://asset/'.length);
			var slash:Int = rest.indexOf('/');
			if (slash <= 0) return null;
			var zipName:String = rest.substr(0, slash);
			var key:String = rest.substr(slash + 1);
			for (cache in assetCaches)
			{
				if (Path.withoutDirectory(cache.filePath) != zipName) continue;
				var found:Dynamic = findEntry(cache, [key]);
				if (found != null) return entryBytes(found.entry);
			}
		}
		#end
		return null;
	}

	public static function getTextFromId(id:String):String
	{
		var bytes:Bytes = getBytesFromId(id);
		return bytes != null ? bytes.toString() : null;
	}

	public static function getAssetId(path:String):String
	{
		#if sys
		var found:Dynamic = findAssetEntry(path);
		if (found != null)
			return 'zip://asset/${Path.withoutDirectory(found.cache.filePath)}/${found.path}';
		#end
		return path;
	}

	public static function invalidate():Void
	{
		#if sys
		modCaches = null;
		modOrder = null;
		assetCaches = null;
		#end
	}

	#if sys
	static function ensureModCaches():Void
	{
		if (modCaches != null) return;

		modCaches = [];
		modOrder = [];

		for (root in modRootPaths())
		{
			if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) continue;

			for (file in FileSystem.readDirectory(root))
			{
				if (!file.toLowerCase().endsWith('.zip')) continue;

				var fullPath:String = Path.join([root, file]);
				if (FileSystem.isDirectory(fullPath)) continue;

				var name:String = file.substr(0, file.length - 4);
				var cache:ZipCache = loadZip(fullPath, name);
				if (cache == null) continue;

				registerModCache(name, cache, true);
				if (cache.rootPrefix.length > 0)
				{
					var rootName:String = cache.rootPrefix.substr(0, cache.rootPrefix.length - 1);
					registerModCache(rootName, cache, false);
				}
			}
		}
	}

	static function registerModCache(name:String, cache:ZipCache, showInList:Bool):Void
	{
		if (name == null || name.trim().length < 1 || modCaches.exists(name)) return;
		modCaches.set(name, cache);
		if (showInList && !modOrder.contains(name))
			modOrder.push(name);
	}

	static function ensureAssetCaches():Void
	{
		if (assetCaches != null) return;

		assetCaches = [];
		var zipFiles:Array<String> = [];
		collectZipFiles('assets', zipFiles);

		for (file in zipFiles)
		{
			var cache:ZipCache = loadZip(file, Path.withoutExtension(Path.withoutDirectory(file)));
			if (cache != null)
				assetCaches.push(cache);
		}
	}

	static function collectZipFiles(folder:String, output:Array<String>):Void
	{
		if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return;

		for (file in FileSystem.readDirectory(folder))
		{
			var fullPath:String = Path.join([folder, file]);
			if (FileSystem.isDirectory(fullPath))
				collectZipFiles(fullPath, output);
			else if (file.toLowerCase().endsWith('.zip') && !output.contains(fullPath))
				output.push(fullPath);
		}
	}

	static function loadZip(filePath:String, displayName:String):ZipCache
	{
		try
		{
			var input = File.read(filePath, true);
			var rawEntries = Reader.readZip(input);
			input.close();

			var entries:Map<String, Entry> = [];
			for (entry in rawEntries)
			{
				var path:String = normalizeEntryPath(entry.fileName);
				if (path.length < 1 || path.endsWith('/') || isJunkEntry(path)) continue;

				entries.set(path, entry);
			}

			var cache:ZipCache = {
				displayName: displayName,
				filePath: filePath,
				rootPrefix: '',
				entries: entries
			};
			cache.rootPrefix = detectRootPrefix(cache);
			return cache;
		}
		catch (e:Dynamic)
		{
			#if (debug || dev) trace('[ZipModManager] Could not read "$filePath": $e'); #end
		}
		return null;
	}

	static function detectRootPrefix(cache:ZipCache):String
	{
		var root:String = null;
		for (entryPath in cache.entries.keys())
		{
			var slash:Int = entryPath.indexOf('/');
			if (slash <= 0) return '';

			var currentRoot:String = entryPath.substr(0, slash);
			if (currentRoot == '__MACOSX') continue;
			if (root == null)
				root = currentRoot;
			else if (root != currentRoot)
				return '';
		}
		return root != null ? '$root/' : '';
	}

	static function findModEntry(mod:String, key:String):Dynamic
	{
		if (mod == null || mod.length < 1) return null;

		ensureModCaches();
		var cache:ZipCache = modCaches.get(mod);
		if (cache == null) return null;

		return findEntry(cache, modLookupKeys(mod, key));
	}

	static function findAssetEntry(path:String):Dynamic
	{
		ensureAssetCaches();
		var keys:Array<String> = assetLookupKeys(path);
		for (cache in assetCaches)
		{
			var found:Dynamic = findEntry(cache, keys);
			if (found != null) return found;
		}
		return null;
	}

	static function findEntry(cache:ZipCache, keys:Array<String>):Dynamic
	{
		for (key in keys)
		{
			var direct:Entry = cache.entries.get(key);
			if (direct != null) return {cache: cache, entry: direct, path: key};

			if (cache.rootPrefix.length > 0)
			{
				var rooted:String = cache.rootPrefix + key;
				var rootedEntry:Entry = cache.entries.get(rooted);
				if (rootedEntry != null) return {cache: cache, entry: rootedEntry, path: key};
			}
		}
		return null;
	}

	static function entryBytes(entry:Entry):Bytes
	{
		if (entry == null) return null;
		try
		{
			return Reader.unzip(entry);
		}
		catch (e:Dynamic)
		{
			#if (debug || dev) trace('[ZipModManager] Could not unzip "${entry.fileName}": $e'); #end
			return null;
		}
	}

	static function modLookupKeys(mod:String, path:String):Array<String>
	{
		var keys:Array<String> = [];
		var base:String = normalizeLookupPath(path);
		var variants:Array<String> = [];
		addLookupKey(variants, base);

		if (base.startsWith('assets/'))
			addLookupKey(variants, base.substr(7));

		var snapshot:Array<String> = variants.copy();
		for (variant in snapshot)
		{
			addLookupKey(variants, 'assets/$variant');
			if (!variant.startsWith('songs/') && !variant.startsWith('music/') && !variant.startsWith('videos/'))
				addLookupKey(variants, 'assets/shared/$variant');
		}

		for (variant in variants)
		{
			addLookupKey(keys, variant);
			addLookupKey(keys, '$mod/$variant');
			for (root in modRootPaths())
				addLookupKey(keys, '$root/$mod/$variant');
		}
		return keys;
	}

	static function assetLookupKeys(path:String):Array<String>
	{
		var keys:Array<String> = [];
		var key:String = stripLibraryPrefix(normalizeLookupPath(path));
		addLookupKey(keys, key);

		var withoutAssets:String = key;
		if (withoutAssets.startsWith('assets/'))
		{
			withoutAssets = withoutAssets.substr(7);
			addLookupKey(keys, withoutAssets);
		}

		for (prefix in ['shared/', 'songs/', 'week_assets/', 'videos/', 'fonts/'])
		{
			if (withoutAssets.startsWith(prefix))
				addLookupKey(keys, withoutAssets.substr(prefix.length));
		}

		return keys;
	}

	static function addLookupKey(keys:Array<String>, key:String):Void
	{
		if (key != null && key.length > 0 && !keys.contains(key))
			keys.push(key);
	}

	static function stripLibraryPrefix(path:String):String
	{
		var colon:Int = path.indexOf(':');
		return colon >= 0 ? path.substr(colon + 1) : path;
	}

	static function stripRootPrefix(cache:ZipCache, path:String):String
	{
		return cache.rootPrefix.length > 0 && path.startsWith(cache.rootPrefix) ? path.substr(cache.rootPrefix.length) : path;
	}

	static function logicalModPath(cache:ZipCache, mod:String, path:String):String
	{
		path = stripRootPrefix(cache, path);

		for (root in modRootPaths())
		{
			var rooted:String = '$root/$mod/';
			if (path.startsWith(rooted))
			{
				path = path.substr(rooted.length);
				break;
			}
		}

		var modPrefix:String = '$mod/';
		if (path.startsWith(modPrefix))
			path = path.substr(modPrefix.length);

		if (path.startsWith('assets/shared/'))
			path = path.substr('assets/shared/'.length);
		else if (path.startsWith('assets/'))
			path = path.substr('assets/'.length);

		return path;
	}

	static function normalizeEntryPath(path:String):String
	{
		return normalizeLookupPath(path);
	}

	static function normalizeLookupPath(path:String):String
	{
		if (path == null) return '';
		path = path.replace('\\', '/');
		while (path.startsWith('./')) path = path.substr(2);
		while (path.startsWith('/')) path = path.substr(1);
		return path;
	}

	static function isJunkEntry(path:String):Bool
	{
		var lower:String = path.toLowerCase();
		return lower.startsWith('__macosx/') || lower.endsWith('/.ds_store') || lower == '.ds_store';
	}
	#end
}
