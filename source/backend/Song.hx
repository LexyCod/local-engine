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
		var difficultyName:String = formattedSong;
		if (difficultyName.startsWith(formattedFolder + '-'))
			difficultyName = difficultyName.substr(formattedFolder.length + 1);
		if (difficultyName == formattedFolder || difficultyName.length < 1)
			difficultyName = 'normal';

		#if sys
		// Проверяем сначала в папке модов, затем в корневойassets/songs/ напрямую через диск
		var modPath:String = Paths.modsJson('songs/$formattedFolder/chart/$formattedSong');
		var localPath:String = 'assets/songs/$formattedFolder/chart/$formattedSong.json';
		var localDiffPath:String = 'assets/songs/$formattedFolder/chart/$difficultyName.json';

		if (FileSystem.exists(modPath)) {
			rawJson = File.getContent(modPath).trim();
		} else if (FileSystem.exists(localPath)) {
			rawJson = File.getContent(localPath).trim();
		} else if (FileSystem.exists(localDiffPath)) {
			rawJson = File.getContent(localDiffPath).trim();
		}
		#end

		// Если через FileSystem не нашли (например на HTML5 или если пути съехали), пробуем старый массив
		if (rawJson == null) {
			rawJson = firstText([
				'songs/$formattedFolder/chart/$formattedSong.json',
				'songs/$formattedFolder/chart/$difficultyName.json',
				'assets/songs/$formattedFolder/chart/$formattedSong.json'
			]);
		}

		if(rawJson == null) {
			// Если вообще ничего не помогло, выдаем понятную ошибку
			throw 'Could not find chart file for: $formattedSong in songs/$formattedFolder/chart/';
		}
		else rawJson = rawJson.trim();

		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}

		// Точно так же переписываем чтение мета-данных через диск
		var metaRaw:String = null;
		#if sys
		var localMeta:String = 'assets/songs/$formattedFolder/chart/meta.json';
		if (FileSystem.exists(localMeta)) metaRaw = File.getContent(localMeta).trim();
		#end

		if (metaRaw == null) {
			metaRaw = firstText([
				'songs/$formattedFolder/chart/meta.json',
				'songs/$formattedFolder/meta.json'
			]);
		}
		
		var meta:Dynamic = null;
		if (metaRaw != null)
		{
			try meta = Json.parse(metaRaw) catch(e:Dynamic) meta = null;
		}

		var songJson:Dynamic = parseJSONshit(rawJson, formattedFolder, meta);
		if (songJson == null || !Std.is(songJson.notes, Array)) throw 'Invalid song json: missing notes array';
		if (songJson.events == null) songJson.events = [];
		if(jsonInput != 'events') StageData.loadDirectory(songJson);
		onLoadJson(songJson);
		return songJson;
	}

	static function firstText(paths:Array<String>):String
	{
		for (path in paths)
		{
			var raw:String = Paths.getTextFromFile(path);
			if (raw != null && raw.trim().length > 0)
				return raw.trim();
		}
		return null;
	}

	public static function parseJSONshit(rawJson:String, ?fallbackSong:String = 'song', ?meta:Dynamic = null):SwagSong
	{
		var parsed = Json.parse(rawJson);
		if (parsed == null) throw 'invalid json: null result';

		var cleaned:Dynamic = cleanSongData(parsed);
		if (Reflect.hasField(cleaned, 'format') && Std.string(Reflect.field(cleaned, 'format')).startsWith('psych_v1'))
			Reflect.setField(cleaned, 'chartVersion', Std.string(Reflect.field(cleaned, 'format')).substr('psych_v'.length));

		if (Reflect.hasField(cleaned, 'strumLines') || Reflect.field(cleaned, 'codenameChart') == true)
			return cast convertCodenameChart(parsed, fallbackSong, meta);

		var songField = Reflect.field(cleaned, 'song');
		if (songField != null && Std.isOfType(songField, String))
		{
			if (Reflect.hasField(cleaned, 'notes'))
				return cast cleaned;
			throw 'invalid json: missing "notes" field';
		}

		if (songField != null && Reflect.hasField(songField, 'notes'))
			return cast songField;

		if (Reflect.hasField(cleaned, 'notes'))
			return cast cleaned;

		throw 'invalid json: missing "song" or "notes" field';
	}

	static function cleanSongData(data:Dynamic):Dynamic
	{
		if (data != null && Reflect.hasField(data, 'song'))
		{
			var field:Dynamic = Reflect.field(data, 'song');
			if (field != null && !Std.isOfType(field, String))
				return field;
		}
		return data;
	}

	static function convertCodenameChart(chart:Dynamic, fallbackSong:String, ?meta:Dynamic):Dynamic
	{
		chart = cleanSongData(chart);
		var chartMeta:Dynamic = Reflect.field(chart, 'meta');
		if (meta == null) meta = chartMeta;

		var bpm:Float = numField(chart, ['bpm'], numField(meta, ['bpm'], 100));
		var speed:Float = numField(chart, ['scrollSpeed', 'speed'], numField(meta, ['scrollSpeed', 'speed'], 1));
		var songName:String = strField(meta, ['name', 'song', 'displayName'], strField(chart, ['song', 'name'], fallbackSong));
		var player1:String = strField(meta, ['player', 'player1', 'bf'], 'bf');
		var player2:String = strField(meta, ['opponent', 'player2', 'dad'], 'dad');
		var gfVersion:String = strField(meta, ['girlfriend', 'gf', 'player3'], 'gf');
		var stage:String = strField(meta, ['stage'], strField(chart, ['stage'], null));
		var needsVoices:Bool = boolField(meta, ['needsVoices'], boolField(chart, ['needsVoices'], true));
		var noteTypes:Array<String> = [];
		var rawNoteTypes:Dynamic = Reflect.field(chart, 'noteTypes');
		if (Std.isOfType(rawNoteTypes, Array))
			for (noteType in cast(rawNoteTypes, Array<Dynamic>))
				noteTypes.push(Std.string(noteType));

		var sectionLength:Float = (60 / Math.max(1, bpm)) * 4 * 1000;
		var sections:Array<Dynamic> = [];
		var events:Array<Dynamic> = [];
		var maxTime:Float = 0;

		var strumLines:Dynamic = Reflect.field(chart, 'strumLines');
		if (Std.isOfType(strumLines, Array))
		{
			var lines:Array<Dynamic> = cast strumLines;
			for (lineIndex in 0...lines.length)
			{
				var line:Dynamic = lines[lineIndex];
				var mustPress:Bool = codenameLineIsPlayer(line, lineIndex, lines.length);
				var firstCharacter:String = firstArrayString(Reflect.field(line, 'characters'));
				if (firstCharacter != null && firstCharacter.length > 0)
				{
					var lineType:Int = Std.int(numField(line, ['type'], mustPress ? 1 : 0));
					var position:String = strField(line, ['position'], '').toLowerCase();
					if (lineType == 1) player1 = firstCharacter;
					else if (lineType == 0) player2 = firstCharacter;
					else if (position == 'girlfriend' || position == 'gf') gfVersion = firstCharacter;
				}

				var lineNotes:Dynamic = Reflect.field(line, 'notes');
				if (!Std.isOfType(lineNotes, Array)) continue;

				for (note in cast(lineNotes, Array<Dynamic>))
				{
					var time:Float = numField(note, ['time', 'strumTime', 't'], 0);
					var data:Int = Std.int(numField(note, ['id', 'data', 'noteData', 'direction'], 0)) % 4;
					if (data < 0) data += 4;
					var sustain:Float = numField(note, ['length', 'sLen', 'sustainLength', 'duration'], 0);
					var type:String = convertCodenameNoteType(Reflect.field(note, 'type'), noteTypes);
					if (type.length < 1) type = strField(note, ['noteType'], '');
					var psychData:Int = data + (mustPress ? 0 : 4);
					var noteEntry:Array<Dynamic> = [time, psychData, sustain, type];
					getSection(sections, Std.int(Math.floor(time / sectionLength)), bpm).sectionNotes.push(noteEntry);
					maxTime = Math.max(maxTime, time + sustain);
				}
			}
		}

		var rawEvents:Dynamic = Reflect.field(chart, 'events');
		if (Std.isOfType(rawEvents, Array))
		{
			for (event in cast(rawEvents, Array<Dynamic>))
			{
				var time:Float = numField(event, ['time', 'strumTime', 't'], 0);
				var name:String = convertCodenameEventName(event);
				var params:Dynamic = Reflect.field(event, 'params');
				var v1:String = '';
				var v2:String = '';
				if (Std.isOfType(params, Array))
				{
					var arr:Array<Dynamic> = cast params;
					if (arr.length > 0) v1 = Std.string(arr[0]);
					if (arr.length > 1) v2 = Std.string(arr[1]);
				}
				else
				{
					v1 = strField(event, ['value1', 'val1'], '');
					v2 = strField(event, ['value2', 'val2'], '');
				}
				events.push([time, [[name, v1, v2]]]);
				maxTime = Math.max(maxTime, time);
			}
		}

		if (sections.length < 1)
			getSection(sections, 0, bpm);

		return {
			song: songName,
			notes: sections,
			events: events,
			bpm: bpm,
			needsVoices: needsVoices,
			speed: speed,
			player1: player1,
			player2: player2,
			gfVersion: gfVersion,
			stage: stage,
			chartVersion: 'codename'
		};
	}

	static function getSection(sections:Array<Dynamic>, index:Int, bpm:Float):Dynamic
	{
		while (sections.length <= index)
		{
			sections.push({
				sectionNotes: [],
				sectionBeats: 4,
				mustHitSection: true,
				gfSection: false,
				bpm: bpm,
				changeBPM: false,
				altAnim: false
			});
		}
		return sections[index];
	}

	static function codenameLineIsPlayer(line:Dynamic, lineIndex:Int, lineCount:Int):Bool
	{
		var lineType:Float = numField(line, ['type'], -1);
		if (lineType == 1) return true;
		if (lineType == 0 || lineType == 2) return false;

		var explicit:Dynamic = Reflect.field(line, 'mustPress');
		if (explicit == null) explicit = Reflect.field(line, 'player');
		if (Std.isOfType(explicit, Bool)) return explicit;

		var pos:String = strField(line, ['position', 'type', 'character'], '').toLowerCase();
		if (pos == 'boyfriend' || pos == 'bf' || pos == 'player' || pos == 'right') return true;
		if (pos == 'dad' || pos == 'opponent' || pos == 'left') return false;
		return lineCount == 1 || lineIndex > 0;
	}

	static function convertCodenameNoteType(rawType:Dynamic, noteTypes:Array<String>):String
	{
		if (rawType == null) return '';
		var typeNum:Float = Std.parseFloat(Std.string(rawType));
		if (!Math.isNaN(typeNum))
		{
			var index:Int = Std.int(typeNum);
			if (index <= 0) return '';
			return noteTypes != null && noteTypes[index - 1] != null ? noteTypes[index - 1] : '';
		}
		var value:String = Std.string(rawType);
		return value == 'Default Note' ? '' : value;
	}

	static function convertCodenameEventName(event:Dynamic):String
	{
		var rawName:Dynamic = Reflect.field(event, 'name');
		if (rawName == null) rawName = Reflect.field(event, 'event');
		if (rawName != null) return Std.string(rawName);

		var rawType:Dynamic = Reflect.field(event, 'type');
		var type:Int = Std.int(numField(event, ['type'], -999));
		return switch (type)
		{
			case 1: 'Camera Movement';
			case 2: 'BPM Change';
			case 3: 'Alt Animation Toggle';
			default: rawType != null ? Std.string(rawType) : '';
		}
	}

	static function firstArrayString(value:Dynamic):String
	{
		if (Std.isOfType(value, Array))
		{
			var arr:Array<Dynamic> = cast value;
			if (arr.length > 0 && arr[0] != null) return Std.string(arr[0]);
		}
		return null;
	}

	static function numField(obj:Dynamic, names:Array<String>, fallback:Float):Float
	{
		if (obj == null) return fallback;
		for (name in names)
		{
			var value:Dynamic = Reflect.field(obj, name);
			if (value == null) continue;
			var num:Float = Std.parseFloat(Std.string(value));
			if (!Math.isNaN(num)) return num;
		}
		return fallback;
	}

	static function strField(obj:Dynamic, names:Array<String>, fallback:String):String
	{
		if (obj == null) return fallback;
		for (name in names)
		{
			var value:Dynamic = Reflect.field(obj, name);
			if (value != null) return Std.string(value);
		}
		return fallback;
	}

	static function boolField(obj:Dynamic, names:Array<String>, fallback:Bool):Bool
	{
		if (obj == null) return fallback;
		for (name in names)
		{
			var value:Dynamic = Reflect.field(obj, name);
			if (value == null) continue;
			if (Std.isOfType(value, Bool)) return value;
			var text:String = Std.string(value).toLowerCase();
			if (text == 'true') return true;
			if (text == 'false') return false;
		}
		return fallback;
	}
}
