package backend;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;

import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.ByteArray;
import openfl.system.System;
import openfl.geom.Rectangle;
import openfl.media.Sound;

import lime.utils.Assets;

import haxe.Json;
import haxe.io.Bytes;


#if MODS_ALLOWED
import backend.Mods;
#end
import backend.CacheManager;
import backend.AudioBackend;
#if MODS_ALLOWED
#end

class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	static function normalizePath(key:String):String
	{
		if (key == null) return '';
		key = key.replace('\\', '/');
		while (key.startsWith('./')) key = key.substr(2);
		return key;
	}

	public static function getModRootPaths():Array<String>
	{
		return ZipModManager.modRootPaths();
	}

	static function stripLibraryPrefix(path:String):String
	{
		var colon:Int = path.indexOf(':');
		return colon >= 0 ? path.substr(colon + 1) : path;
	}

	public static var dumpExclusions:Array<String> = ['assets/shared/music/freakyMenu.$SOUND_EXT'];
	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory() {
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys()) {
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key)) {
				var obj = currentTrackedAssets.get(key);
				@:privateAccess
				if (obj != null) {
					// remove the key from all cache maps
					FlxG.bitmap._cache.remove(key);
					openfl.Assets.cache.removeBitmapData(key);
					currentTrackedAssets.remove(key);

					// and get rid of the object
					obj.persist = false; // make sure the garbage collector actually clears it up
					obj.destroyOnNoUse = true;
					obj.destroy();
				}
			}
		}

		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];
	public static function clearStoredMemory() {
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedAssets.exists(key))
			{
				openfl.Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, ?type:AssetType = TEXT, ?library:Null<String> = null, ?modsAllowed:Bool = false):String
	{
		#if MODS_ALLOWED
		if(modsAllowed)
		{
			var customFile:String = file;
			if (library != null)
				customFile = '$library/$file';

			var modded:String = modFolders(customFile);
			if(FileSystem.exists(modded)) return modded;
		}
		#end

		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(file, 'week_assets', currentLevel);
				if (OpenFlAssets.exists(levelPath, type))
					return levelPath;
			}
		}

		return getSharedPath(file);
	}

	static public function getLibraryPath(file:String, library = "shared")
	{
		return if (library == "shared") getSharedPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String, ?level:String)
	{
		if(level == null) level = library;
		var returnPath = '$library:assets/$level/$file';
		return returnPath;
	}

	inline public static function getSharedPath(file:String = '')
	{
		return 'assets/shared/$file';
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline static public function shaderFragment(key:String, ?library:String)
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}
	inline static public function shaderVertex(key:String, ?library:String)
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}
	inline static public function lua(key:String, ?library:String)
	{
		return getPath('$key.lua', TEXT, library);
	}

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	static public function sound(key:String, ?library:String):Sound
	{
		var sound:Sound = returnSound('sounds', key, library);
		return sound;
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String):Sound
	{
		var file:Sound = returnSound('music', key, library);
		return file;
	}

	inline static public function voices(song:String, postfix:String = null):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		if(postfix != null) songKey += '-' + postfix;
		//trace('songKey test: $songKey');
		var voices = returnSound(null, songKey, 'songs');
		return voices;
	}

	inline static public function inst(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Inst';
		var inst = returnSound(null, songKey, 'songs');
		return inst;
	}

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	static public function image(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		var bitmap:BitmapData = null;
		var file:String = null;

		#if MODS_ALLOWED
		var modImageKey = 'images/$key.png';
		file = getModAssetId(modImageKey);
		if (currentTrackedAssets.exists(file))
		{
			localTrackedAssets.push(file);
			return currentTrackedAssets.get(file);
		}
		else
			bitmap = bitmapFromBytes(getModFileBytes(modImageKey));

		if (bitmap == null && FileSystem.exists(modsImages(key)))
		{
			file = modsImages(key);
			bitmap = BitmapData.fromFile(file);
		}
		#end

		if (bitmap == null)
		{
			file = getPath('images/$key.png', IMAGE, library);
			if (currentTrackedAssets.exists(file))
			{
				localTrackedAssets.push(file);
				return currentTrackedAssets.get(file);
			}
			else if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);
			else
			{
				var assetBytes = ZipModManager.getAssetBytes(file);
				if (assetBytes != null)
				{
					bitmap = bitmapFromBytes(assetBytes);
					file = ZipModManager.getAssetId(file);
				}
			}
		}

		if (bitmap != null)
		{
			var retVal = cacheBitmap(file, bitmap, allowGPU);
			if(retVal != null) return retVal;
		}

		trace('oh no its returning null NOOOO ($file)');
		return null;
	}

	static public function cacheBitmap(file:String, ?bitmap:BitmapData = null, ?allowGPU:Bool = true)
	{
		if(bitmap == null)
		{
			#if MODS_ALLOWED
			if (FileSystem.exists(file))
				bitmap = BitmapData.fromFile(file);
			#end

			if (bitmap == null)
			{
				if (OpenFlAssets.exists(file, IMAGE))
					bitmap = OpenFlAssets.getBitmapData(file);
				else
				{
					var assetBytes = ZipModManager.getAssetBytes(file);
					if (assetBytes != null)
					{
						bitmap = bitmapFromBytes(assetBytes);
						file = ZipModManager.getAssetId(file);
					}
				}
			}

			if(bitmap == null) return null;
		}

		localTrackedAssets.push(file);
		if (allowGPU && ClientPrefs.data.cacheOnGPU)
		{
			var texture:RectangleTexture = FlxG.stage.context3D.createRectangleTexture(bitmap.width, bitmap.height, BGRA, true);
			texture.uploadFromBitmapData(bitmap);
			bitmap.image.data = null;
			bitmap.dispose();
			bitmap.disposeImage();
			bitmap = BitmapData.fromTexture(texture);
		}
		var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, file);
		newGraphic.persist = true;
		newGraphic.destroyOnNoUse = false;
		currentTrackedAssets.set(file, newGraphic);
		CacheManager.onTextureLoaded(file, newGraphic);
		return newGraphic;
	}

	static function bitmapFromBytes(bytes:Bytes):BitmapData
	{
		return bytes != null ? BitmapData.fromBytes(ByteArray.fromBytes(bytes)) : null;
	}

	static public function getBytesFromFile(key:String, ?ignoreMods:Bool = false):Bytes
	{
		key = normalizePath(key);
		if (key.startsWith('zip://'))
			return ZipModManager.getBytesFromId(key);

		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			var modBytes = getModFileBytes(key);
			if (modBytes != null) return modBytes;
		}
		#end

		if (FileSystem.exists(key) && !FileSystem.isDirectory(key))
			return File.getBytes(key);

		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			var modPath:String = modFolders(key);
			if (FileSystem.exists(modPath) && !FileSystem.isDirectory(modPath))
				return File.getBytes(modPath);
		}
		#end

		var sharedPath:String = getSharedPath(key);
		if (FileSystem.exists(sharedPath) && !FileSystem.isDirectory(sharedPath))
			return File.getBytes(sharedPath);

		if (currentLevel != null && currentLevel != 'shared')
		{
			var levelPath:String = stripLibraryPrefix(getLibraryPathForce(key, 'week_assets', currentLevel));
			if (FileSystem.exists(levelPath) && !FileSystem.isDirectory(levelPath))
				return File.getBytes(levelPath);
		}
		#end

		var path:String = getPath(key, BINARY);
		try
		{
			if(OpenFlAssets.exists(path, BINARY) || OpenFlAssets.exists(path, TEXT))
				return OpenFlAssets.getBytes(path);
			if(OpenFlAssets.exists(key, BINARY) || OpenFlAssets.exists(key, TEXT))
				return OpenFlAssets.getBytes(key);
		}
		catch(e:Dynamic) {}

		#if sys
		var assetBytes = ZipModManager.getAssetBytes(path);
		if (assetBytes != null) return assetBytes;
		assetBytes = ZipModManager.getAssetBytes(key);
		if (assetBytes != null) return assetBytes;
		#end

		return null;
	}

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		key = normalizePath(key);
		var bytes:Bytes = getBytesFromFile(key, ignoreMods);
		if (bytes != null) return bytes.toString();

		var path:String = getPath(key, TEXT);
		if(OpenFlAssets.exists(path, TEXT)) return Assets.getText(path);
		if(OpenFlAssets.exists(key, TEXT)) return Assets.getText(key);

		#if sys
		var assetText = ZipModManager.getAssetText(path);
		if (assetText != null) return assetText;
		assetText = ZipModManager.getAssetText(key);
		if (assetText != null) return assetText;
		#end
		return null;
	}

	inline static public function font(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsFont(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/fonts/$key';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String = null)
	{
		key = normalizePath(key);
		#if MODS_ALLOWED
		if(!ignoreMods)
		{
			if (modFileExists(key))
				return true;

			for(mod in Mods.getGlobalMods())
				if (FileSystem.exists(mods('$mod/$key')))
					return true;

			if (FileSystem.exists(mods(Mods.currentModDirectory + '/' + key)) || FileSystem.exists(mods(key)))
				return true;
			
			if (FileSystem.exists(mods('$key')))
				return true;
		}
		#end

		#if sys
		if(FileSystem.exists(key))
			return true;
		var sharedPath:String = getSharedPath(key);
		if(FileSystem.exists(sharedPath))
			return true;
		#end

		if(OpenFlAssets.exists(getPath(key, type, library, false))) {
			return true;
		}
		#if sys
		if(ZipModManager.assetExists(getPath(key, type, library, false)) || ZipModManager.assetExists(key))
			return true;
		#end
		return false;
	}

	static function getImageText(key:String, extension:String, ?library:String = null):String
	{
		var relativePath = 'images/$key.$extension';
		#if MODS_ALLOWED
		var modText = getModFileText(relativePath);
		if (modText != null) return modText;

		#end

		#if sys
		var sharedPath = getSharedPath(relativePath);
		if (FileSystem.exists(sharedPath)) return File.getContent(sharedPath);
		#end

		var assetPath = getPath(relativePath, TEXT, library);
		if (OpenFlAssets.exists(assetPath, TEXT)) return OpenFlAssets.getText(assetPath);
		var zipText = ZipModManager.getAssetText(assetPath);
		if (zipText != null) return zipText;
		zipText = ZipModManager.getAssetText(relativePath);
		if (zipText != null) return zipText;
		return null;
	}

	static public function getAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, library, allowGPU);

		var myXml:String = getImageText(key, 'xml', library);
		if(myXml != null)
		{
			return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
		}
		else
		{
			var myJson:String = getImageText(key, 'json', library);
			if(myJson != null)
			{
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
			}
		}
		return getPackerAtlas(key, library);
	}

	static public function getSparrowAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, library, allowGPU);
		var xml = getImageText(key, 'xml', library);
		return FlxAtlasFrames.fromSparrow(imageLoaded, xml != null ? xml : getPath('images/$key.xml', TEXT, library));
	}

	static public function getPackerAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, library, allowGPU);
		var txt = getImageText(key, 'txt', library);
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, txt != null ? txt : getPath('images/$key.txt', TEXT, library));
	}

	static public function getAsepriteAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, library, allowGPU);
		var json = getImageText(key, 'json', library);
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, json != null ? json : getPath('images/$key.json', TEXT, library));
	}

	inline static public function formatToSongPath(path:String) {
		var invalidChars = ~/[~&\\;:<>#]/;
		var hideChars = ~/[.,'"%?!]/;

		var path = invalidChars.split(path.replace(' ', '-')).join("-");
		return hideChars.split(path).join("").toLowerCase();
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(path:Null<String>, key:String, ?library:String):Sound {
		var relativeBase:String = key;
		if(path != null && path.length > 0) relativeBase = '$path/$key';

		#if MODS_ALLOWED
		var modLibPath:String = '';
		if (library != null && library.length > 0) modLibPath = '$library/';
		if (path != null && path.length > 0) modLibPath += path;

		var modBase:String = modLibPath.length > 0 ? '$modLibPath/$key' : key;
		for (extension in AudioBackend.soundExtensions())
		{
			var modSoundKey:String = '$modBase.$extension';
			var asset = findModAsset(modSoundKey);
			if (asset == null) continue;

			var cacheKey:String = asset.id;
			if(!currentTrackedSounds.exists(cacheKey))
			{
				var sound:Sound = null;
				if (Reflect.hasField(asset, "bytes") && asset.bytes != null)
					sound = AudioBackend.fromBytes(asset.bytes, asset.id);
				else if (Reflect.hasField(asset, "file") && asset.file != null)
					sound = AudioBackend.fromFile(asset.file);
				if (sound != null)
					currentTrackedSounds.set(cacheKey, sound);
			}

			if(currentTrackedSounds.exists(cacheKey))
			{
				localTrackedAssets.push(cacheKey);
				return currentTrackedSounds.get(cacheKey);
			}
		}
		#end

		for (extension in AudioBackend.soundExtensions())
		{
			var assetPath:String = getPath('$relativeBase.$extension', SOUND, library);
			var cacheKey:String = assetPath;
			if (cacheKey.indexOf(':') >= 0)
				cacheKey = cacheKey.substring(cacheKey.indexOf(':') + 1, cacheKey.length);

			if(!currentTrackedSounds.exists(cacheKey))
			{
				var sound:Sound = null;

				try
				{
					if(!AudioBackend.isOpusPath(assetPath) && OpenFlAssets.exists(assetPath, SOUND))
						sound = OpenFlAssets.getSound(assetPath);
					else if(OpenFlAssets.exists(assetPath, BINARY) || OpenFlAssets.exists(assetPath, SOUND))
						sound = AudioBackend.fromBytes(OpenFlAssets.getBytes(assetPath), assetPath);
				}
				catch(e:Dynamic)
				{
					#if (debug || dev) trace('[Paths] Could not load sound asset "$assetPath": $e'); #end
				}

				#if sys
				if(sound == null)
				{
					var filePath:String = assetPath;
					if (filePath.indexOf(':') >= 0)
						filePath = filePath.substring(filePath.indexOf(':') + 1, filePath.length);
					if(FileSystem.exists(filePath))
						sound = AudioBackend.fromFile(filePath);
				}

				if(sound == null)
				{
					var assetBytes = ZipModManager.getAssetBytes(assetPath);
					if (assetBytes != null)
					{
						cacheKey = ZipModManager.getAssetId(assetPath);
						sound = AudioBackend.fromBytes(assetBytes, assetPath);
					}
				}
				#end

				if(sound != null)
					currentTrackedSounds.set(cacheKey, sound);
			}

			if(currentTrackedSounds.exists(cacheKey))
			{
				localTrackedAssets.push(cacheKey);
				return currentTrackedSounds.get(cacheKey);
			}
		}
		return null;
	}

	#if MODS_ALLOWED
	static function findModAsset(key:String, ?folder:String):Dynamic
	{
		key = normalizePath(key);

		var strippedKey = key;
		if (key.startsWith("assets/")) strippedKey = key.substr(7);

		var rooted:Dynamic = splitModRootedKey(strippedKey);
		if (rooted != null)
		{
			strippedKey = rooted.key;
			if (rooted.mod != null)
			{
				var rootedAsset = findAssetInMod(rooted.mod, strippedKey);
				if (rootedAsset != null) return rootedAsset;
			}
		}

		if (folder != null && folder.length > 0)
			return findAssetInMod(folder, strippedKey);

		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var current = findAssetInMod(Mods.currentModDirectory, strippedKey);
			if (current != null) return current;
		}

		for(mod in Mods.getGlobalMods())
		{
			var global = findAssetInMod(mod, strippedKey);
			if (global != null) return global;
		}


		var looseFile = findLooseModFile(strippedKey);
		if (looseFile != null)
			return {id: looseFile, file: looseFile};

		return null;
	}

	static function findAssetInMod(mod:String, key:String):Dynamic
	{
		if (mod == null || mod.length < 1) return null;

		var file = findPhysicalModFile(mod, key);
		if (file != null)
			return {id: file, file: file};

		var zipAsset = ZipModManager.getModAsset(mod, key);
		if (zipAsset != null)
			return zipAsset;

		return null;
	}

	static function splitModRootedKey(key:String):Dynamic
	{
		for (root in getModRootPaths())
		{
			var prefix = root + '/';
			if (!key.startsWith(prefix)) continue;

			var rest = key.substr(prefix.length);
			var slash = rest.indexOf('/');
			if (slash > 0)
			{
				var mod = rest.substr(0, slash);
				var inside = rest.substr(slash + 1);
				if (Mods.modExists(mod))
					return {mod: mod, key: inside};
			}
			return {mod: null, key: rest};
		}
		return null;
	}

	static function findPhysicalModFile(mod:String, key:String):String
	{
		if (mod == null || mod.length < 1) return null;

		for (root in getModRootPaths())
		{
			var file = root + '/' + mod + '/' + key;
			if (FileSystem.exists(file) && !FileSystem.isDirectory(file))
				return file;
		}
		return null;
	}

	static function findLooseModFile(key:String):String
	{
		for (root in getModRootPaths())
		{
			var file = root + '/' + key;
			if (FileSystem.exists(file) && !FileSystem.isDirectory(file))
				return file;
		}
		return null;
	}

	public static function modFileExists(key:String, ?folder:String):Bool
	{
		return findModAsset(key, folder) != null;
	}

	public static function getModFileBytes(key:String, ?folder:String):Bytes
	{
		var asset = findModAsset(key, folder);
		if (asset == null) return null;
		if (Reflect.hasField(asset, "bytes") && asset.bytes != null)
			return asset.bytes;
		if (Reflect.hasField(asset, "file") && asset.file != null)
			return File.getBytes(asset.file);
		return null;
	}

	public static function getModFileText(key:String, ?folder:String):String
	{
		var asset = findModAsset(key, folder);
		if (asset == null) return null;
		if (Reflect.hasField(asset, "bytes") && asset.bytes != null)
			return asset.bytes.toString();
		if (Reflect.hasField(asset, "file") && asset.file != null)
			return File.getContent(asset.file);
		return null;
	}

	public static function getModAssetId(key:String, ?folder:String):String
	{
		var asset = findModAsset(key, folder);
		return asset != null ? asset.id : mods(key);
	}

	inline static public function mods(key:String = '') {
		return 'content/' + key;
	}

	inline static public function modsFont(key:String) {
		return modFolders('fonts/' + key);
	}

	inline static public function modsJson(key:String) {
		return modFolders('data/' + key + '.json');
	}

	inline static public function modsVideo(key:String) {
		return modFolders('videos/' + key + '.' + VIDEO_EXT);
	}

	inline static public function modsSounds(path:String, key:String) {
		return modFolders(path + '/' + key + '.' + SOUND_EXT);
	}

	inline static public function modsImages(key:String) {
		return modFolders('images/' + key + '.png');
	}

	inline static public function modsXml(key:String) {
		return modFolders('images/' + key + '.xml');
	}

	inline static public function modsTxt(key:String) {
		return modFolders('images/' + key + '.txt');
	}

	inline static public function modsImagesJson(key:String) {
		return modFolders('images/' + key + '.json');
	}

	/* Goes unused for now

	inline static public function modsShaderFragment(key:String, ?library:String)
	{
		return modFolders('shaders/'+key+'.frag');
	}
	inline static public function modsShaderVertex(key:String, ?library:String)
	{
		return modFolders('shaders/'+key+'.vert');
	}
	inline static public function modsAchievements(key:String) {
		return modFolders('achievements/' + key + '.json');
	}*/

	static public function modFolders(key:String) {
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) {
			var fileToCheck:String = findPhysicalModFile(Mods.currentModDirectory, key);
			if(fileToCheck != null) {
				return fileToCheck;
			}
		}

		for(mod in Mods.getGlobalMods()){
			var fileToCheck:String = findPhysicalModFile(mod, key);
			if(fileToCheck != null)
				return fileToCheck;
		}
		var looseFile:String = findLooseModFile(key);
		return looseFile != null ? looseFile : 'content/' + key;
	}
	#end

	#if flxanimate
	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
	{
		var changedAnimJson = false;
		var changedAtlasJson = false;
		var changedImage = false;
		
		if(spriteJson != null)
		{
			changedAtlasJson = true;
			spriteJson = File.getContent(spriteJson);
		}

		if(animationJson != null) 
		{
			changedAnimJson = true;
			animationJson = File.getContent(animationJson);
		}

		// is folder or image path
		if(Std.isOfType(folderOrImg, String))
		{
			var originalPath:String = folderOrImg;
			for (i in 0...10)
			{
				var st:String = '$i';
				if(i == 0) st = '';

				if(!changedAtlasJson)
				{
					spriteJson = getTextFromFile('images/$originalPath/spritemap$st.json');
					if(spriteJson != null)
					{
						//trace('found Sprite Json');
						changedImage = true;
						changedAtlasJson = true;
						folderOrImg = Paths.image('$originalPath/spritemap$st');
						break;
					}
				}
				else if(Paths.fileExists('images/$originalPath/spritemap$st.png', IMAGE))
				{
					//trace('found Sprite PNG');
					changedImage = true;
					folderOrImg = Paths.image('$originalPath/spritemap$st');
					break;
				}
			}

			if(!changedImage)
			{
				//trace('Changing folderOrImg to FlxGraphic');
				changedImage = true;
				folderOrImg = Paths.image(originalPath);
			}

			if(!changedAnimJson)
			{
				//trace('found Animation Json');
				changedAnimJson = true;
				animationJson = getTextFromFile('images/$originalPath/Animation.json');
			}
		}

		//trace(folderOrImg);
		//trace(spriteJson);
		//trace(animationJson);
		spr.loadAtlasEx(folderOrImg, spriteJson, animationJson);
	}

	/*private static function getContentFromFile(path:String):String
	{
		var onAssets:Bool = false;
		var path:String = Paths.getPath(path, TEXT, true);
		if(FileSystem.exists(path) || (onAssets = true && Assets.exists(path, TEXT)))
		{
			//trace('Found text: $path');
			return !onAssets ? File.getContent(path) : Assets.getText(path);
		}
		return null;
	}*/
	#end
}
