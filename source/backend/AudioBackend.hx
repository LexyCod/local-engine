package backend;

import haxe.io.Bytes;
import lime.media.AudioBuffer;
import openfl.media.Sound;

#if hxopus
import hxopus.Opus;
#end

using StringTools;

class AudioBackend
{
	public static inline var OPUS_EXT:String = "opus";

	public static function soundExtensions():Array<String>
	{
		var extensions:Array<String> = [];
		#if hxopus
		addUniqueExtension(extensions, OPUS_EXT);
		#end
		addUniqueExtension(extensions, #if web "mp3" #else "ogg" #end);
		addUniqueExtension(extensions, "ogg");
		addUniqueExtension(extensions, "mp3");
		return extensions;
	}

	public static function fromFile(path:String):Sound
	{
		if (path == null || path.length < 1) return null;

		try
		{
			#if hxopus
			if (isOpusPath(path))
				return Opus.toOpenFL(path);
			#end
			return Sound.fromFile(path);
		}
		catch (e:Dynamic)
		{
			#if (debug || dev) trace('[AudioBackend] Could not load "$path": $e'); #end
		}
		return null;
	}

	public static function fromBytes(bytes:Bytes, sourcePath:String):Sound
	{
		if (bytes == null) return null;

		try
		{
			#if hxopus
			if (isOpusPath(sourcePath))
				return Opus.toOpenFL(bytes);
			#end

			var buffer:AudioBuffer = AudioBuffer.fromBytes(bytes);
			return buffer != null ? Sound.fromAudioBuffer(buffer) : null;
		}
		catch (e:Dynamic)
		{
			#if (debug || dev) trace('[AudioBackend] Could not decode "$sourcePath": $e'); #end
		}
		return null;
	}

	public static function isOpusPath(path:String):Bool
	{
		return extensionOf(path) == OPUS_EXT;
	}

	public static function extensionOf(path:String):String
	{
		if (path == null) return "";
		var normalized = path.split("?")[0].split("#")[0];
		var dot = normalized.lastIndexOf(".");
		return dot >= 0 ? normalized.substr(dot + 1).toLowerCase() : "";
	}

	static function addUniqueExtension(extensions:Array<String>, extension:String):Void
	{
		if (extension != null && extension.length > 0 && !extensions.contains(extension))
			extensions.push(extension);
	}
}
