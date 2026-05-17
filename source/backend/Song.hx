package backend;

import haxe.Json;
import lime.utils.Assets;

import backend.Section;
import Reflect;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;

	// Psych Engine 1.0+ fields
	@:optional var chartVersion:String;
	@:optional var offsets:Array<Float>;      // [inst, voices] offsets in ms
	@:optional var ratings:Dynamic;           // difficulty ratings map
	@:optional var mania:Int;                 // 0 = 4-key (default)
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';

	private static function onLoadJson(songJson:Dynamic)
	{
		if (songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			songJson.player3 = null;
		}

		var chartVer:String = (songJson.chartVersion != null) ? songJson.chartVersion : '';
		var is10Chart:Bool = _chartVersionAtLeast(chartVer, 1, 0, 0);

		if (is10Chart)
		{
			// 1.0 charts already have a proper events array — nothing extra needed.
			if (songJson.events == null) songJson.events = [];

			for (secNum in 0...songJson.notes.length)
			{
				var sec:Dynamic = songJson.notes[secNum];
				if (sec == null || sec.sectionNotes == null) continue;

				var notes:Array<Dynamic> = sec.sectionNotes;
				var i:Int = 0;
				var len:Int = notes.length;


				if (sec.mustHitSection == null)
				{
					var playerCount:Int = 0;
					var oppCount:Int = 0;
					for (n in notes)
					{
						if (Std.is(n, Array))
						{
							var nd:Int = Std.int(n[1]);
							if (nd >= 4) playerCount++ else oppCount++;
						}
					}
					sec.mustHitSection = (playerCount >= oppCount);
				}

				while (i < len)
				{
					var note:Dynamic = notes[i];
					if (Std.is(note, Array))
					{
						var noteArr:Array<Dynamic> = note;
						var nd:Int = Std.int(noteArr[1]);
						if (nd < 0)
						{
							var eventName:String = (noteArr[2] != null) ? noteArr[2] : '';
							var val1:String     = (noteArr[3] != null) ? noteArr[3] : '';
							var val2:String     = (noteArr[4] != null) ? noteArr[4] : '';
							songJson.events.push([noteArr[0], [[eventName, val1, val2]]]);
							notes.remove(note);
							len = notes.length;
						}
						else
						{
							if (sec.mustHitSection)
							{
								if (nd >= 4)
									noteArr[1] = nd - 4
								else
									noteArr[1] = nd + 4;
							}
							i++;
						}
					}
					else
					{
						notes.remove(note);
						len = notes.length;
					}
				}
			}
			return;
		}

		if (songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while (i < len)
				{
					var note = notes[i];
					if (Std.is(note, Array))
					{
						var noteArr:Array<Dynamic> = note;
						if (noteArr[1] < 0)
						{
							var eventName = (noteArr[2] != null) ? noteArr[2] : '';
							var val1      = (noteArr[3] != null) ? noteArr[3] : '';
							var val2      = (noteArr[4] != null) ? noteArr[4] : '';
							songJson.events.push([noteArr[0], [[eventName, val1, val2]]]);
							notes.remove(note);
							len = notes.length;
						}
						else i++;
					}
					else
					{
						notes.remove(note);
						len = notes.length;
					}
				}
			}
		}
	}

	private static function _chartVersionAtLeast(ver:String, major:Int, minor:Int, patch:Int):Bool
	{
		if (ver == null || ver.length == 0) return false;
		var parts = ver.split('.');
		var _pMaj:Null<Int> = (parts.length > 0) ? Std.parseInt(parts[0]) : null;
		var _pMin:Null<Int> = (parts.length > 1) ? Std.parseInt(parts[1]) : null;
		var _pPat:Null<Int> = (parts.length > 2) ? Std.parseInt(parts[2]) : null;
		var vMaj:Int = (_pMaj != null) ? _pMaj : 0;
		var vMin:Int = (_pMin != null) ? _pMin : 0;
		var vPat:Int = (_pPat != null) ? _pPat : 0;
		if (vMaj != major) return vMaj > major;
		if (vMin != minor) return vMin > minor;
		return vPat >= patch;
	}

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var rawJson = null;
		
		if(folder == null) folder = jsonInput;
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		rawJson = Paths.getTextFromFile('data/$formattedFolder/$formattedSong.json');

		if(rawJson == null) {
			var path:String = Paths.json(formattedFolder + '/' + formattedSong);

			#if sys
			if(FileSystem.exists(path))
				rawJson = File.getContent(path).trim();
			else
			#end
				rawJson = Assets.getText(Paths.json(formattedFolder + '/' + formattedSong)).trim();
		}
		else rawJson = rawJson.trim();

		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
			// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		}

		// FIX THE CASTING ON WINDOWS/NATIVE
		// Windows???
		// trace(songData);

		// trace('LOADED FROM JSON: ' + songData.notes);
		/* 
			for (i in 0...songData.notes.length)
			{
				trace('LOADED FROM JSON: ' + songData.notes[i].sectionNotes);
				// songData.notes[i].sectionNotes = songData.notes[i].sectionNotes
			}

				daNotes = songData.notes;
				daSong = songData.song;
				daBpm = songData.bpm; */

		var songJson:Dynamic = parseJSONshit(rawJson);
		if (songJson == null || !Std.is(songJson.notes, Array)) throw 'Invalid song json: missing notes array';
		if (songJson.events == null) songJson.events = [];
		if(jsonInput != 'events') StageData.loadDirectory(songJson);
		onLoadJson(songJson);
		return songJson;
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var parsed = Json.parse(rawJson);
		if (parsed == null) throw 'invalid json: null result';

		var songField = Reflect.field(parsed, 'song');
		if (songField != null && Std.isOfType(songField, String))
		{
			if (Reflect.hasField(parsed, 'notes'))
				return cast parsed;
			throw 'invalid json: missing "notes" field';
		}

		if (songField != null && Reflect.hasField(songField, 'notes'))
			return cast songField;

		if (Reflect.hasField(parsed, 'notes'))
			return cast parsed;

		throw 'invalid json: missing "song" or "notes" field';
	}
}
