package backend;

import haxe.zip.Reader;
import haxe.zip.Entry;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class ZipModManager {
    static var caches:Map<String, {reader:Reader, entries:Map<String, Entry>}> = new Map();

    static function getCache(modName:String):Dynamic {
        if (caches.exists(modName)) return caches.get(modName);

        var zipPath:String = Paths.mods(modName + '.zip');
        if (!FileSystem.exists(zipPath)) return null;

        var file:FileInput = null;
        var reader:Reader = null;
        try {
            file = File.read(zipPath, true);
            reader = new Reader(file);
            var entriesMap:Map<String, Entry> = new Map();
            for (entry in reader.entries) {
                if (entry.fileName != null) entriesMap.set(entry.fileName, entry);
            }
            var cache = {reader: reader, entries: entriesMap};
            caches.set(modName, cache);
            return cache;
        }
        catch (e:Dynamic) {
            trace('failed to open zip $modName: $e');
            if (reader != null) reader.close();
            if (file != null) file.close();
            return null;
        }
    }

    static function isDir(entry:Entry):Bool {
        return entry.fileName.endsWith('/') || entry.fileName.endsWith('\\');
    }

    static function getEntry(modName:String, path:String):Entry {
        var cache = getCache(modName);
        if (cache == null) return null;
        var normz = StringTools.replace(path, '\\', '/'); // нормализовать слеши
        return cache.entries.get(normz);
    }
    
    public static function getBytes(modName:String, path:String):Bytes {
        var cache = getCache(modName);
        if (cache == null) return null;

        var entry = cache.entries.get(path);
        if (entry == null || isDir(entry)) return null;

        try {
            var output = new BytesOutput();
            cache.reader.read(output, entry);
            return output.getBytes();
        }
        catch (e:Dynamic) {
            trace('error reading $path from zip $modName: $e');
            return null;
        }
    }

    public static function exists(modName:String, path:String):Bool {
        var entry = getEntry(modName, path);
        return entry != null && !isDir(entry);
    }

    public static function getText(modName:String, path:String):String {
        var bytes = getBytes(modName, path);
        if (bytes == null) return null;
        return bytes.toString();
    }

    public static function closeAll() {
        for (cache in caches) {
            try {
                cache.reader.close();
            }
            catch (e:Dynamic) {}
        }
        caches.clear();
    }
}
