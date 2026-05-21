package backend;

import flixel.FlxState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class StartupStateResolver
{
	static var consumed:Bool = false;

	public static function takeStartupState():FlxState
	{
		if (consumed) return null;
		consumed = true;

		var stateName:String = readStateName();
		if (stateName == null || stateName.length < 1) return null;
		return createState(stateName);
	}

	static function readStateName():String
	{
		var rawConfigs:Array<String> = [];

		#if sys
		for (path in ['content/engine.json', 'content/startup.json', 'engine.json', 'startup.json'])
		{
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path))
				rawConfigs.push(File.getContent(path));
		}
		#end

		#if MODS_ALLOWED
		var mod:String = Mods.currentModDirectory;
		if (mod != null && mod.length > 0)
		{
			for (path in ['engine.json', 'startup.json'])
			{
				var modConfig:String = Paths.getModFileText(path, mod);
				if (modConfig != null && modConfig.length > 0)
					rawConfigs.push(modConfig);
			}
		}
		#end

		for (raw in rawConfigs)
		{
			var stateName:String = parseStateName(raw);
			if (stateName != null && stateName.length > 0)
				return stateName;
		}
		return null;
	}

	static function parseStateName(raw:String):String
	{
		if (raw == null || raw.trim().length < 1) return null;

		try
		{
			var data:Dynamic = tjson.TJSON.parse(raw);
			if (Std.isOfType(data, String))
				return Std.string(data);

			for (field in ['firstState', 'startState', 'initialState', 'bootState', 'state'])
			{
				if (Reflect.hasField(data, field))
					return Std.string(Reflect.field(data, field));
			}
		}
		catch (e:Dynamic)
		{
			#if (debug || dev) trace('[StartupStateResolver] Invalid startup config: $e'); #end
		}
		return null;
	}

	static function createState(name:String):FlxState
	{
		var key:String = normalizeName(name);
		switch (key)
		{
			case 'title' | 'titlestate':
				return null;
			case 'main' | 'mainmenu' | 'mainmenustate':
				return new states.MainMenuState();
			case 'freeplay' | 'freeplaystate':
				return new states.FreeplayState();
			case 'story' | 'storymenu' | 'storymenustate':
				return new states.StoryMenuState();
			case 'mods' | 'modsmenu' | 'modmenustate' | 'modsmenustate':
				return new states.ModsMenuState();
			case 'editors' | 'editor' | 'mastereditor' | 'mastereditormenu':
				return new states.editors.MasterEditorMenu();
			case 'chart' | 'charting' | 'charteditor' | 'chartingstate':
				return new states.editors.ChartingState();
			case 'character' | 'charactereditor' | 'charactereditorstate':
				return new states.editors.CharacterEditorState(objects.Character.DEFAULT_CHARACTER, false);
			case 'code' | 'script' | 'codeeditor' | 'scripteditor' | 'scripteditorstate':
				return new states.editors.ScriptEditorState();
		}

		#if (debug || dev) trace('[StartupStateResolver] Unknown firstState "$name"'); #end
		return null;
	}

	static function normalizeName(name:String):String
	{
		var key:String = name == null ? '' : name.toLowerCase().trim();
		key = key.split('states.').join('');
		key = key.split('editors.').join('');
		key = key.split(' ').join('');
		key = key.split('_').join('');
		key = key.split('-').join('');
		key = key.split('.').join('');
		return key;
	}
}
