package states.editors;

import backend.ZipModManager;
import flixel.addons.ui.FlxUIInputText;
import flixel.ui.FlxButton;
import haxe.io.Path;

class ScriptEditorState extends MusicBeatState
{
	var files:Array<String> = [];
	var curSelected:Int = 0;
	var listText:FlxText;
	var editor:FlxUIInputText;
	var statusText:FlxText;
	var currentPath:String = '';

	override function create()
	{
		super.create();
		FlxG.mouse.visible = true;
		FlxG.camera.bgColor = 0xFF171A20;

		var title = new FlxText(20, 16, FlxG.width - 40, 'LOCAL ENGINE CODE EDITOR', 24);
		title.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, LEFT);
		add(title);

		listText = new FlxText(20, 64, 260, '', 14);
		listText.setFormat(Paths.font('vcr.ttf'), 14, 0xFFE7ECF3, LEFT);
		add(listText);

		editor = new FlxUIInputText(300, 64, Std.int(FlxG.width - 330), '', 14, 0xFFECEFF4, 0xFF10131A);
		editor.lines = Std.int((FlxG.height - 155) / 18);
		editor.fieldBorderColor = 0xFF4E5A6A;
		editor.backgroundColor = 0xFF10131A;
		add(editor);

		var saveButton = new FlxButton(300, FlxG.height - 74, 'Save', saveCurrent);
		var reloadButton = new FlxButton(390, FlxG.height - 74, 'Reload', loadCurrent);
		var newLuaButton = new FlxButton(490, FlxG.height - 74, 'New Lua', function() createNewScript('lua'));
		var newHxButton = new FlxButton(590, FlxG.height - 74, 'New HScript', function() createNewScript('hx'));
		add(saveButton);
		add(reloadButton);
		add(newLuaButton);
		add(newHxButton);

		statusText = new FlxText(20, FlxG.height - 38, FlxG.width - 40, '', 16);
		statusText.setFormat(Paths.font('vcr.ttf'), 16, 0xFFB9C3D0, LEFT);
		add(statusText);

		reloadFiles();
		loadCurrent();
	}

	override function update(elapsed:Float)
	{
		if (controls.BACK)
		{
			MusicBeatState.switchState(new MasterEditorMenu());
			return;
		}

		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);
		if (controls.ACCEPT) loadCurrent();

		super.update(elapsed);
	}

	function reloadFiles():Void
	{
		files = [];
		addPhysicalScriptDirs('content');
		addPhysicalScriptDirs('mods');

		#if MODS_ALLOWED
		for (mod in Mods.parseList().enabled)
		{
			for (zipPath in ZipModManager.listModFiles(mod))
			{
				var lower = zipPath.toLowerCase();
				if ((lower.endsWith('.lua') || lower.endsWith('.hx')) && !files.contains(Paths.getModAssetId(zipPath, mod)))
					files.push(Paths.getModAssetId(zipPath, mod));
			}
		}
		#end

		files.sort(function(a, b) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
		if (files.length < 1) files.push('');
		curSelected = Std.int(FlxMath.bound(curSelected, 0, files.length - 1));
		refreshList();
	}

	function addPhysicalScriptDirs(root:String):Void
	{
		#if sys
		if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) return;
		collectScripts(root);
		#end
	}

	#if sys
	function collectScripts(folder:String):Void
	{
		for (file in FileSystem.readDirectory(folder))
		{
			var path = Path.join([folder, file]).replace('\\', '/');
			if (FileSystem.isDirectory(path))
				collectScripts(path);
			else
			{
				var lower = path.toLowerCase();
				if ((lower.endsWith('.lua') || lower.endsWith('.hx')) && !files.contains(path))
					files.push(path);
			}
		}
	}
	#end

	function changeSelection(change:Int):Void
	{
		if (files.length < 1) return;
		curSelected += change;
		if (curSelected < 0) curSelected = files.length - 1;
		if (curSelected >= files.length) curSelected = 0;
		refreshList();
	}

	function refreshList():Void
	{
		var text = '';
		var start = Std.int(Math.max(0, curSelected - 12));
		var end = Std.int(Math.min(files.length, start + 25));
		for (i in start...end)
			text += (i == curSelected ? '> ' : '  ') + displayPath(files[i]) + '\n';
		listText.text = text;
	}

	function loadCurrent():Void
	{
		if (files.length < 1 || files[curSelected].length < 1)
		{
			editor.text = '';
			currentPath = '';
			status('No scripts found. Create one with New Lua or New HScript.');
			return;
		}

		currentPath = files[curSelected];
		var text = Paths.getTextFromFile(currentPath, true);
		editor.text = text != null ? text : '';
		status('Loaded ' + displayPath(currentPath));
	}

	function saveCurrent():Void
	{
		#if sys
		if (currentPath == null || currentPath.length < 1)
		{
			createNewScript('lua');
			return;
		}

		var savePath = writablePath(currentPath);
		ensureDirectory(Path.directory(savePath));
		File.saveContent(savePath, editor.text);
		if (!files.contains(savePath))
		{
			files.push(savePath);
			curSelected = files.indexOf(savePath);
		}
		currentPath = savePath;
		reloadFiles();
		status('Saved ' + displayPath(savePath));
		#end
	}

	function createNewScript(ext:String):Void
	{
		#if sys
		var mod = (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) ? Mods.currentModDirectory : 'local';
		var folder = 'content/$mod/scripts';
		ensureDirectory(folder);

		var index = 1;
		var path = '$folder/new-script.$ext';
		while (FileSystem.exists(path))
		{
			index++;
			path = '$folder/new-script-$index.$ext';
		}

		var template = ext == 'hx' ? 'function onCreate() {\n\ttrace("hello from hscript");\n}\n' : 'function onCreate()\n\tdebugPrint("hello from lua")\nend\n';
		File.saveContent(path, template);
		reloadFiles();
		curSelected = files.indexOf(path);
		loadCurrent();
		#end
	}

	function writablePath(path:String):String
	{
		if (path.startsWith('zip://mod/'))
		{
			var rest = path.substr('zip://mod/'.length);
			var slash = rest.indexOf('/');
			if (slash > 0)
				return 'content/' + rest.substr(0, slash) + '/' + rest.substr(slash + 1);
		}
		return path;
	}

	#if sys
	function ensureDirectory(folder:String):Void
	{
		if (folder == null || folder.length < 1 || FileSystem.exists(folder)) return;
		ensureDirectory(Path.directory(folder));
		FileSystem.createDirectory(folder);
	}
	#end

	function displayPath(path:String):String
	{
		if (path == null) return '';
		return path.replace('zip://mod/', '[zip] ');
	}

	function status(text:String):Void
	{
		statusText.text = text;
	}
}
