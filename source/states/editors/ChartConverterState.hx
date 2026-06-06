package states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

import flixel.math.FlxMath;
import flixel.util.FlxColor;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import backend.MusicBeatState;
import states.FreeplayState;
import objects.Alphabet;
import moonchart.formats.fnf.legacy.FNFPsych;
import moonchart.formats.fnf.FNFVSlice;
import moonchart.formats.fnf.FNFCodename;
import moonchart.formats.BasicFormat.DynamicFormat;
import moonchart.backend.Util.OneOfArray;
import moonchart.formats.BasicFormat.FormatDifficulty;

import haxe.ui.Toolkit;
import haxe.ui.core.Component;
import haxe.ui.containers.VBox;
import haxe.ui.components.Button;
import haxe.ui.components.Label;

/**
 * Chart converter for Psych Engine 0.7.3
 * Supports: VSlice / Base game, Codename Engine, Psych 1.0
 */
class ChartConverterState extends MusicBeatState
{
	public static var goToFreeplay:Bool = false;

	var bg:FlxSprite;
	var title:Alphabet;
	var optionGroup:FlxTypedGroup<Alphabet>;
	var descBG:FlxSprite;
	var descText:FlxText;
	var curOption:Int = 0;
	var canSelect:Bool = true;
	var targetColor:FlxColor = 0xFF674B6C;

	var uiRoot:Component;

	override function create()
	{
		@:privateAccess haxe.ui.backend.flixel.CursorHelper.mouseLoadFunction = function(id:String) { return null; };
		super.create();
		FlxG.mouse.visible = true;
		Toolkit.init();
		haxe.ui.Toolkit.theme = "dark"; 
		uiRoot = haxe.ui.ComponentBuilder.fromFile("assets/exclude/chart-converter.xml");
		add(uiRoot);

		var btnVSlice = uiRoot.findComponent("btnVSlice", haxe.ui.components.Button);
		var btnCodename = uiRoot.findComponent("btnCodename", haxe.ui.components.Button);
		var btnPsych = uiRoot.findComponent("btnPsych", haxe.ui.components.Button);

		if (btnVSlice != null) {
			btnVSlice.onClick = function(e) {
				var dialog = new lime.ui.FileDialog();
				dialog.onSelectMultiple.add(function(paths:Array<String>) {
					if (paths != null && paths.length >= 2) {
						onVSliceSelected(paths);
					} else {
						showMessage("Please select exactly 2 files (Chart and Meta)!", true);
					}
					canSelect = true;
				});
				dialog.browse(lime.ui.FileDialogType.OPEN_MULTIPLE, "json");
			};
		}

		if (btnCodename != null) {
			btnCodename.onClick = function(e) {
				var dialog = new lime.ui.FileDialog();
				dialog.onSelectMultiple.add(function(paths:Array<String>) {
					if (paths != null && paths.length >= 2) {
						onCodenameSelected(paths);
					} else {
						showMessage("Please select exactly 2 files (Chart and Meta)!", true);
					}
					canSelect = true;
				});
				dialog.browse(lime.ui.FileDialogType.OPEN_MULTIPLE, "json");
			};
		}

		if (btnPsych != null) {
			btnPsych.onClick = function(e) {
				openSingleFile(onPsychSelected);
			};
		}

	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.mouse.justPressed) {
			var clickSounds:Array<String> = [
				"assets/exclude/ui/click1.ogg",
				"assets/exclude/ui/click2.ogg",
				"assets/exclude/ui/click3.ogg"
			];
			
			var randomSound = FlxG.random.getObject(clickSounds);
			FlxG.sound.play(randomSound);
    	}
	}

	function openSingleFile(callback:String->Void)
	{
		var dialog = new FileDialog();
		dialog.onSelect.add(function(path:String)
		{
			if (path != null)
				callback(path);
			else
				onCancel();
			canSelect = true;
		});
		dialog.browse(FileDialogType.OPEN, "json");
	}

	function openMultipleFiles(keywords:Array<String>, callback:Array<String>->Void)
	{
		var dialog = new FileDialog();
		var selected:Array<String> = [];
		dialog.onSelectMultiple.add(function(paths:Array<String>)
		{
			if (paths != null && paths.length > 0)
			{
				for (kw in keywords)
				{
					var found = false;
					for (p in paths)
					{
						if (p.toLowerCase().indexOf(kw) != -1)
						{
							selected.push(p);
							found = true;
							break;
						}
					}
					if (!found)
					{
						showMessage('File with keyword "$kw" not found', true);
						canSelect = true;
						return;
					}
				}
				callback(selected);
			}
			else
			{
				onCancel();
			}
			canSelect = true;
		});
		dialog.browse(FileDialogType.OPEN_MULTIPLE, "json");
	}

	function onVSliceSelected(files:Array<String>)
	{
		var chartPath:String = null;
		var metaPath:String = null;
		for (f in files)
		{
			if (f.toLowerCase().indexOf("chart") != -1)
				chartPath = f;
			else if (f.toLowerCase().indexOf("meta") != -1)
				metaPath = f;
		}
		if (chartPath == null || metaPath == null)
		{
			showMessage("Could not find both files (chart.json and meta.json)", true);
			return;
		}
		try
		{
			var vslice = new FNFVSlice().fromFile(chartPath, metaPath);
			for (diff in vslice.diffs)
			{
				var outPath = chartPath.substr(0, chartPath.length - 5) + "-converted-" + diff + ".json";
				if (diff == "normal") outPath = outPath.replace("-normal", "");
				saveChart(outPath, vslice, diff);
			}
			showMessage("VSlice conversion completed!");
		}
		catch (e)
		{
			showMessage("VSlice error: " + e.message, true);
		}
	}

	function onCodenameSelected(files:Array<String>)
	{
		var chartPath:String = null;
		var metaPath:String = null;
		for (f in files)
		{
			if (f.toLowerCase().indexOf("meta") != -1)
				metaPath = f;
			else
				chartPath = f;
		}
		if (chartPath == null || metaPath == null)
		{
			showMessage("Could not find both files (chart.json and meta.json)", true);
			return;
		}
		try
		{
			var cne = new FNFCodename().fromFile(chartPath, metaPath);
			var outPath = chartPath.substr(0, chartPath.length - 5) + "-converted.json";
			saveChart(outPath, cne);
			showMessage("Codename conversion completed!");
		}
		catch (e)
		{
			showMessage("Codename error: " + e.message, true);
		}
	}

	function onPsychSelected(path:String)
	{
		if (!path.endsWith(".json"))
		{
			showMessage("Please select a JSON file!", true);
			return;
		}
		try
		{
			var psych = new FNFPsych().fromFile(path);
			var outPath = path.substr(0, path.length - 5) + "-converted.json";
			saveChart(outPath, psych);
			showMessage("Psych 1.0 conversion completed!");
		}
		catch (e)
		{
			showMessage("Psych error: " + e.message, true);
		}
	}

	function saveChart(path:String, format:OneOfArray<DynamicFormat>, ?diff:FormatDifficulty)
	{
		var finalChart = new FNFPsych().fromFormat(format, diff);
		finalChart.beautify = true;
		var saved = finalChart.save(path);
		if (saved == null)
			throw "Failed to save file!";
		FlxG.log.notice("Saved: " + saved.dataPath);
	}

	function showMessage(msg:String, isError:Bool = false)
	{
		if (isError)
		{
			FlxG.log.error(msg);
			FlxG.sound.play(Paths.sound("cancelMenu"));
		}
		else
		{
			FlxG.log.notice(msg);
			FlxG.sound.play(Paths.sound("confirmMenu"));
		}
		trace(msg);
	}

	function onCancel()
	{
		FlxG.log.warn("File selection canceled.");
		canSelect = true;
	}

	function goBack()
	{
		canSelect = false;
		FlxG.sound.play(Paths.sound("cancelMenu"));
		if (goToFreeplay)
			FlxG.switchState(new FreeplayState());
		else
			FlxG.switchState(new MasterEditorMenu());
		goToFreeplay = false;
	}

	override function destroy()
	{
		super.destroy();
	}
}