package states.editors;

import flash.geom.Rectangle;
import haxe.Json;
import haxe.io.Bytes;

import flixel.FlxObject;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup;
import flixel.util.FlxSort;
import lime.media.AudioBuffer;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.Assets as OpenFlAssets;

import backend.Song;
import backend.Section;
import backend.StageData;

import objects.Note;
import objects.StrumNote;
import objects.NoteSplash;
import objects.HealthIcon;
import objects.AttachedSprite;
import objects.Character;
import substates.Prompt;

// HaxeUI
import haxe.ui.Toolkit;
import haxe.ui.core.Component;
import haxe.ui.ComponentBuilder;
import haxe.ui.components.Button;
import haxe.ui.components.CheckBox;
import haxe.ui.components.DropDown;
import haxe.ui.components.TextField;
import haxe.ui.components.Slider;
import haxe.ui.components.NumberStepper;
import haxe.ui.components.Label;
import haxe.ui.containers.VBox;
import haxe.ui.containers.TabView;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)

class ChartingState extends MusicBeatState
{
	public static var noteTypeList:Array<String> = ['', 'Alt Animation', 'Hey!', 'Hurt Note', 'GF Sing', 'No Animation'];
	public static var goToPlayState:Bool  = false;
	public static var curSec:Int          = 0;
	public static var lastSection:Int     = 0;
	public static var GRID_SIZE:Int       = 40;
	public static var quantization:Int    = 16;
	public static var curQuant:Int        = 3;
	public static var vortex:Bool         = false;
	static var lastSong:String            = '';

	public var ignoreWarnings:Bool  = false;
	public var mouseQuant:Bool      = false;
	public var playbackSpeed:Float  = 1;
	public var quantizations:Array<Int> = [4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 192];

	var _song:SwagSong;
	var _file:FileReference;
	var currentSongName:String;
	var vocals:FlxSound         = null;
	var opponentVocals:FlxSound = null;

	var gridBG:FlxSprite;
	var nextGridBG:FlxSprite;
	var gridLayer:FlxTypedGroup<FlxSprite>;
	var waveformSprite:FlxSprite;
	var lastSecBeats:Float     = 0;
	var lastSecBeatsNext:Float = 0;
	var columns:Int            = 9;

	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;
	var nextRenderedNotes:FlxTypedGroup<Note>;
	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;

	var strumLine:FlxSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var quant:AttachedSprite;
	var dummyArrow:FlxSprite;
	var camPos:FlxObject;
	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;
	var bpmTxt:FlxText;
	var zoomTxt:FlxText;

	var zoomList:Array<Float>   = [0.25, 0.5, 1, 2, 3, 4, 6, 8, 12, 16, 24];
	var curZoom:Int             = 2;
	var CAM_OFFSET:Int          = 360;

	var curSelectedNote:Array<Dynamic> = null;
	var curNoteTypes:Array<String>     = [];
	var currentType:Int                = 0;
	var curEventSelected:Int           = 0;
	var sectionToCopy:Int              = 0;
	var notesCopied:Array<Dynamic>;

	var eventStuff:Array<Dynamic> = [
		['', "Nothing. Yep, that's right."],
		['Dadbattle Spotlight', "Value 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"],
		['Hey!', "Value 1: BF / GF / else=Both\nValue 2: Duration (blank = 0.6s)"],
		['Set GF Speed', "Value 1: 1=Normal, 2=Half, 4=Quarter\nMust be integer!"],
		['Add Camera Zoom', "Value 1: Cam zoom (0.015)\nValue 2: UI zoom (0.03)"],
		['Play Animation', "Value 1: Animation name\nValue 2: Character (Dad, BF, GF)"],
		['Camera Follow Pos', "Value 1: X, Value 2: Y\nLeave blank to reset"],
		['Alt Idle Animation', "Value 1: Character\nValue 2: Suffix (blank = disable)"],
		['Screen Shake', "Value 1: Camera\nValue 2: HUD\nFormat: \"duration, intensity\""],
		['Change Character', "Value 1: Dad/BF/GF\nValue 2: New character name"],
		['Change Scroll Speed', "Value 1: Multiplier\nValue 2: Time in seconds"],
		['Set Property', "Value 1: Variable name\nValue 2: New value"],
		['Play Sound', "Value 1: Sound file\nValue 2: Volume (0-1, default 1)"]
	];

	var lastConductorPos:Float   = 0;
	var colorSine:Float          = 0;
	var waveformPrinted:Bool     = true;
	var wavData:Array<Array<Array<Float>>> = [[[0],[0]],[[0],[0]]];
	var lastWaveformHeight:Int   = 0;
	var playtesting:Bool         = false;
	var playtestingTime:Float    = 0;
	var playtestingOnComplete:Void->Void = null;
	var undos:Array<Dynamic>     = [];
	var redos:Array<Dynamic>     = [];
	var missingText:FlxText;
	var missingTextTimer:FlxTimer;

	var characterData:Dynamic = { iconP1: null, iconP2: null, vocalsP1: null, vocalsP2: null };
	var characterFailed:Bool  = false;

	var uiRoot:Component;
	var camHUD:FlxCamera;
	var camMenu:FlxCamera;

	// widget refs
	var txtSongTitle:TextField;
	var stepBPM:NumberStepper;
	var stepSpeed:NumberStepper;
	var chkNeedsVoices:CheckBox;
	var dropPlayer1:DropDown;
	var dropPlayer2:DropDown;
	var dropGF:DropDown;
	var dropStage:DropDown;

	var stepBeats:NumberStepper;
	var chkMustHit:CheckBox;
	var chkGFSection:CheckBox;
	var chkAltAnim:CheckBox;
	var chkChangeBPM:CheckBox;
	var stepSectionBPM:NumberStepper;
	var chkCopyNotes:CheckBox;
	var chkCopyEvents:CheckBox;
	var stepCopyOffset:NumberStepper;

	var txtStrumTime:TextField;
	var stepSusLength:NumberStepper;
	var dropNoteType:DropDown;

	var dropEvent:DropDown;
	var lblSelectedEvent:Label;
	var txtValue1:TextField;
	var txtValue2:TextField;
	var txtEventDesc:Label;

	var chkMetronome:CheckBox;
	var chkDisableScroll:CheckBox;
	var chkVortex:CheckBox;
	var chkMouseQuant:CheckBox;
	var chkIgnoreWarnings:CheckBox;
	var stepMetroBPM:NumberStepper;
	var stepMetroOffset:NumberStepper;
	var chkWaveInst:CheckBox;
	var chkWaveVoices:CheckBox;
	var chkWaveOppVoices:CheckBox;
	var stepInstVol:NumberStepper;
	var stepVocalsVol:NumberStepper;
	var stepOppVol:NumberStepper;
	var chkMuteInst:CheckBox;
	var chkMuteVocals:CheckBox;
	var chkMuteOpp:CheckBox;
	var chkPlaySoundBF:CheckBox;
	var chkPlaySoundDad:CheckBox;
	var sldPlaybackRate:Slider;

	var txtNoteSkin:TextField;
	var txtNoteSplashes:TextField;
	var chkDisableNoteRGB:CheckBox;
	var txtGameOverChar:TextField;
	var txtGameOverSound:TextField;
	var txtGameOverLoop:TextField;
	var txtGameOverEnd:TextField;

	override function create()
	{
		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else {
			Difficulty.resetList();
			_song = { song:'Test', notes:[], events:[], bpm:150.0, needsVoices:true,
			          player1:'bf', player2:'dad', gfVersion:'gf', speed:1, stage:'stage' };
			addSection();
			PlayState.SONG = _song;
		}

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, '-', ' '));
		#end

		// cameras
		var camEditor = initPsychCamera();
		camHUD = new FlxCamera(); camHUD.bgColor.alpha = 0; FlxG.cameras.add(camHUD, false);
		camMenu = new FlxCamera(); camMenu.bgColor.alpha = 0; FlxG.cameras.add(camMenu, false);

		vortex         = FlxG.save.data.chart_vortex;
		ignoreWarnings = FlxG.save.data.ignoreWarnings;

		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(); bg.color = 0xFF222222; add(bg);

		gridLayer = new FlxTypedGroup<FlxSprite>(); add(gridLayer);

		waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(1, 1, 0x00FFFFFF);
		add(waveformSprite);

		var eventIcon:FlxSprite = new FlxSprite(-GRID_SIZE - 5, -90).loadGraphic(Paths.image('eventArrow'));
		eventIcon.antialiasing = ClientPrefs.data.antialiasing;
		leftIcon  = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');
		for (s in [eventIcon, leftIcon, rightIcon]) s.scrollFactor.set(1, 1);
		eventIcon.setGraphicSize(30, 30);
		leftIcon.setGraphicSize(0, 45); rightIcon.setGraphicSize(0, 45);
		add(eventIcon); add(leftIcon); add(rightIcon);
		leftIcon.setPosition(GRID_SIZE + 10, -100);
		rightIcon.setPosition(GRID_SIZE * 5.2, -100);

		curRenderedSustains  = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes     = new FlxTypedGroup<Note>();
		curRenderedNoteType  = new FlxTypedGroup<FlxText>();
		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes    = new FlxTypedGroup<Note>();

		FlxG.mouse.visible = true;
		updateJsonData();
		currentSongName = Paths.formatToSongPath(_song.song);
		loadSong();
		reloadGridLayer();
		Conductor.bpm = _song.bpm;
		Conductor.mapBPMChanges(_song);
		if (curSec >= _song.notes.length) curSec = _song.notes.length - 1;

		bpmTxt = new FlxText(1000, 50, 0, "", 16);
		bpmTxt.scrollFactor.set(); bpmTxt.cameras = [camHUD]; add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4); add(strumLine);

		quant = new AttachedSprite('chart_quant', 'chart_quant');
		quant.animation.addByPrefix('q', 'chart_quant', 0, false);
		quant.animation.play('q', true, false, 0);
		quant.sprTracker = strumLine; quant.xAdd = -32; quant.yAdd = 8; add(quant);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		for (i in 0...8) {
			var n = new StrumNote(GRID_SIZE * (i + 1), strumLine.y, i % 4, 0);
			n.setGraphicSize(GRID_SIZE, GRID_SIZE); n.updateHitbox();
			n.playAnim('static', true); n.scrollFactor.set(1, 1);
			strumLineNotes.add(n);
		}
		add(strumLineNotes);

		camPos = new FlxObject(0, 0, 1, 1);
		camPos.setPosition(strumLine.x + CAM_OFFSET, strumLine.y);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		dummyArrow.antialiasing = ClientPrefs.data.antialiasing; add(dummyArrow);

		Toolkit.init();
		haxe.ui.Toolkit.theme = "dark";
		@:privateAccess haxe.ui.backend.flixel.CursorHelper.mouseLoadFunction = function(_) return null;
		uiRoot = ComponentBuilder.fromFile("assets/exclude/chart-editor.xml");
		uiRoot.cameras = [camMenu];
		add(uiRoot);

		zoomTxt = new FlxText(10, 10, 0, "Zoom: 1 / 1", 16);
		zoomTxt.scrollFactor.set(); zoomTxt.cameras = [camHUD]; add(zoomTxt);

		add(curRenderedSustains); add(curRenderedNotes); add(curRenderedNoteType);
		add(nextRenderedSustains); add(nextRenderedNotes);

		findUIComponents();
		populateDropdowns();
		bindHaxeUI();
		syncUIToSong();
		syncUIToSection();
		updateHeads();
		updateWaveform();

		if (lastSong != currentSongName) changeSection();
		lastSong = currentSongName;
		updateGrid();

		camEditor.follow(camPos, LOCKON, 999);
		super.create();
	}

	function findUIComponents()
	{
		inline function find<T:Component>(id:String, cls:Class<T>):T
			return uiRoot.findComponent(id, cls);

		txtSongTitle    = find("txtSongTitle",    TextField);
		stepBPM         = find("stepBPM",         NumberStepper);
		stepSpeed       = find("stepSpeed",        NumberStepper);
		chkNeedsVoices  = find("chkNeedsVoices",  CheckBox);
		dropPlayer1     = find("dropPlayer1",     DropDown);
		dropPlayer2     = find("dropPlayer2",     DropDown);
		dropGF          = find("dropGF",          DropDown);
		dropStage       = find("dropStage",       DropDown);

		stepBeats      = find("stepBeats",       NumberStepper);
		chkMustHit     = find("chkMustHit",      CheckBox);
		chkGFSection   = find("chkGFSection",    CheckBox);
		chkAltAnim     = find("chkAltAnim",      CheckBox);
		chkChangeBPM   = find("chkChangeBPM",    CheckBox);
		stepSectionBPM = find("stepSectionBPM",  NumberStepper);
		chkCopyNotes   = find("chkCopyNotes",    CheckBox);
		chkCopyEvents  = find("chkCopyEvents",   CheckBox);
		stepCopyOffset = find("stepCopyOffset",  NumberStepper);

		txtStrumTime   = find("txtStrumTime",    TextField);
		stepSusLength  = find("stepSusLength",   NumberStepper);
		dropNoteType   = find("dropNoteType",    DropDown);

		dropEvent        = find("dropEvent",        DropDown);
		lblSelectedEvent = find("lblSelectedEvent", Label);
		txtValue1        = find("txtValue1",        TextField);
		txtValue2        = find("txtValue2",        TextField);
		txtEventDesc     = find("txtEventDesc",     Label);

		chkMetronome      = find("chkMetronome",      CheckBox);
		chkDisableScroll  = find("chkDisableScroll",  CheckBox);
		chkVortex         = find("chkVortex",         CheckBox);
		chkMouseQuant     = find("chkMouseQuant",     CheckBox);
		chkIgnoreWarnings = find("chkIgnoreWarnings", CheckBox);
		stepMetroBPM      = find("stepMetroBPM",      NumberStepper);
		stepMetroOffset   = find("stepMetroOffset",   NumberStepper);
		chkWaveInst       = find("chkWaveInst",       CheckBox);
		chkWaveVoices     = find("chkWaveVoices",     CheckBox);
		chkWaveOppVoices  = find("chkWaveOppVoices",  CheckBox);
		stepInstVol       = find("stepInstVol",        NumberStepper);
		stepVocalsVol     = find("stepVocalsVol",      NumberStepper);
		stepOppVol        = find("stepOppVol",         NumberStepper);
		chkMuteInst       = find("chkMuteInst",        CheckBox);
		chkMuteVocals     = find("chkMuteVocals",      CheckBox);
		chkMuteOpp        = find("chkMuteOpp",         CheckBox);
		chkPlaySoundBF    = find("chkPlaySoundBF",     CheckBox);
		chkPlaySoundDad   = find("chkPlaySoundDad",    CheckBox);
		sldPlaybackRate   = find("sldPlaybackRate",     Slider);

		txtNoteSkin       = find("txtNoteSkin",        TextField);
		txtNoteSplashes   = find("txtNoteSplashes",    TextField);
		chkDisableNoteRGB = find("chkDisableNoteRGB",  CheckBox);
		txtGameOverChar   = find("txtGameOverChar",    TextField);
		txtGameOverSound  = find("txtGameOverSound",   TextField);
		txtGameOverLoop   = find("txtGameOverLoop",    TextField);
		txtGameOverEnd    = find("txtGameOverEnd",     TextField);
	}

	function populateDropdowns()
	{
		#if MODS_ALLOWED
		var charDirs = [Paths.mods('characters/'), Paths.mods(Mods.currentModDirectory + '/characters/'), Paths.getSharedPath('characters/')];
		for (m in Mods.getGlobalMods()) charDirs.push(Paths.mods(m + '/characters/'));
		#else
		var charDirs = [Paths.getSharedPath('characters/')];
		#end
		var characters:Array<String> = Mods.mergeAllTextsNamed('data/characterList.txt', Paths.getSharedPath());
		#if MODS_ALLOWED
		for (dir in charDirs) {
			if (!FileSystem.exists(dir)) continue;
			for (file in FileSystem.readDirectory(dir)) {
				var path = haxe.io.Path.join([dir, file]);
				if (FileSystem.isDirectory(path) || !file.endsWith('.json')) continue;
				var name = file.substr(0, file.length - 5);
				if (name.trim().length > 0 && !name.endsWith('-dead') && !characters.contains(name))
					characters.push(name);
			}
		}
		#end
		for (d in [dropPlayer1, dropPlayer2, dropGF]) {
			if (d == null) continue;
			for (c in characters) d.dataSource.add({ text: c });
		}
		if (dropPlayer1 != null) dropPlayer1.text = _song.player1;
		if (dropPlayer2 != null) dropPlayer2.text = _song.player2;
		if (dropGF      != null) dropGF.text      = _song.gfVersion;

		#if MODS_ALLOWED
		var stageDirs = [Paths.mods('stages/'), Paths.mods(Mods.currentModDirectory + '/stages/'), Paths.getSharedPath('stages/')];
		for (m in Mods.getGlobalMods()) stageDirs.push(Paths.mods(m + '/stages/'));
		#else
		var stageDirs = [Paths.getSharedPath('stages/')];
		#end
		var stages:Array<String> = [];
		for (s in Mods.mergeAllTextsNamed('data/stageList.txt', Paths.getSharedPath()))
			if (s.trim().length > 0 && !stages.contains(s)) stages.push(s);
		#if MODS_ALLOWED
		for (dir in stageDirs) {
			if (!FileSystem.exists(dir)) continue;
			for (file in FileSystem.readDirectory(dir)) {
				var path = haxe.io.Path.join([dir, file]);
				if (FileSystem.isDirectory(path) || !file.endsWith('.json')) continue;
				var name = file.substr(0, file.length - 5);
				if (name.trim().length > 0 && !stages.contains(name)) stages.push(name);
			}
		}
		#end
		if (stages.length < 1) stages.push('stage');
		if (dropStage != null) {
			for (s in stages) dropStage.dataSource.add({ text: s });
			dropStage.text = _song.stage;
		}

		for (nt in noteTypeList) curNoteTypes.push(nt);
		#if sys
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'custom_notetypes/'))
			for (file in FileSystem.readDirectory(folder)) {
				var fn = file.toLowerCase().trim(); var wl = 4;
				if ((#if LUA_ALLOWED fn.endsWith('.lua') || #end
				     #if HSCRIPT_ALLOWED (fn.endsWith('.hx') && (wl = 3) == 3) || #end
				     fn.endsWith('.txt')) && fn != 'readme.txt') {
					var name = file.substr(0, file.length - wl);
					if (!curNoteTypes.contains(name)) curNoteTypes.push(name);
				}
			}
		#end
		if (dropNoteType != null)
			for (i in 0...curNoteTypes.length)
				dropNoteType.dataSource.add({ text: i == 0 ? '' : i + '. ' + curNoteTypes[i] });

		#if LUA_ALLOWED
		var evMap:Map<String, Bool> = new Map();
		var evDirs:Array<String> = [];
		#if MODS_ALLOWED
		evDirs.push(Paths.mods('custom_events/'));
		evDirs.push(Paths.mods(Mods.currentModDirectory + '/custom_events/'));
		for (m in Mods.getGlobalMods()) evDirs.push(Paths.mods(m + '/custom_events/'));
		#end
		for (dir in evDirs) {
			if (!FileSystem.exists(dir)) continue;
			for (file in FileSystem.readDirectory(dir)) {
				var path = haxe.io.Path.join([dir, file]);
				if (FileSystem.isDirectory(path) || file == 'readme.txt' || !file.endsWith('.txt')) continue;
				var name = file.substr(0, file.length - 4);
				if (!evMap.exists(name)) { evMap.set(name, true); eventStuff.push([name, File.getContent(path)]); }
			}
		}
		evMap.clear();
		#end
		if (dropEvent != null)
			for (ev in eventStuff) dropEvent.dataSource.add({ text: ev[0] });
	}

	function syncUIToSong()
	{
		if (txtSongTitle   != null) txtSongTitle.text         = _song.song;
		if (stepBPM        != null) stepBPM.pos               = Conductor.bpm;
		if (stepSpeed      != null) stepSpeed.pos             = _song.speed;
		if (chkNeedsVoices != null) chkNeedsVoices.selected  = _song.needsVoices;
		if (stepMetroBPM   != null) stepMetroBPM.pos          = _song.bpm;
		if (stepInstVol    != null) stepInstVol.pos           = 1;
		if (stepVocalsVol  != null) stepVocalsVol.pos         = 1;
		if (stepOppVol     != null) stepOppVol.pos            = 1;
		if (sldPlaybackRate!= null) sldPlaybackRate.pos       = 1;
		if (chkVortex         != null) chkVortex.selected         = vortex;
		if (chkIgnoreWarnings != null) chkIgnoreWarnings.selected  = ignoreWarnings;
		if (chkWaveInst      != null) chkWaveInst.selected      = FlxG.save.data.chart_waveformInst      == true;
		if (chkWaveVoices    != null) chkWaveVoices.selected    = FlxG.save.data.chart_waveformVoices    == true;
		if (chkWaveOppVoices != null) chkWaveOppVoices.selected = FlxG.save.data.chart_waveformOppVoices == true;
		if (chkMetronome     != null) chkMetronome.selected     = FlxG.save.data.chart_metronome     == true;
		if (chkDisableScroll != null) chkDisableScroll.selected = FlxG.save.data.chart_noAutoScroll  == true;
		if (chkMouseQuant    != null) chkMouseQuant.selected    = FlxG.save.data.mouseScrollingQuant == true;
		if (chkPlaySoundBF   != null) chkPlaySoundBF.selected   = FlxG.save.data.chart_playSoundBf   == true;
		if (chkPlaySoundDad  != null) chkPlaySoundDad.selected  = FlxG.save.data.chart_playSoundDad  == true;
		if (txtNoteSkin      != null) txtNoteSkin.text          = _song.arrowSkin     != null ? _song.arrowSkin     : '';
		if (txtNoteSplashes  != null) txtNoteSplashes.text      = _song.splashSkin    != null ? _song.splashSkin    : '';
		if (txtGameOverChar  != null) txtGameOverChar.text      = _song.gameOverChar  != null ? _song.gameOverChar  : '';
		if (txtGameOverSound != null) txtGameOverSound.text     = _song.gameOverSound != null ? _song.gameOverSound : '';
		if (txtGameOverLoop  != null) txtGameOverLoop.text      = _song.gameOverLoop  != null ? _song.gameOverLoop  : '';
		if (txtGameOverEnd   != null) txtGameOverEnd.text       = _song.gameOverEnd   != null ? _song.gameOverEnd   : '';
		if (chkDisableNoteRGB!= null) chkDisableNoteRGB.selected = (_song.disableNoteRGB == true);
	}

	// called updateSectionUI in original — kept as alias
	function syncUIToSection()
	{
		if (_song.notes[curSec] == null) return;
		var sec = _song.notes[curSec];
		if (stepBeats      != null) stepBeats.pos             = getSectionBeats();
		if (chkMustHit     != null) chkMustHit.selected       = sec.mustHitSection;
		if (chkGFSection   != null) chkGFSection.selected     = sec.gfSection;
		if (chkAltAnim     != null) chkAltAnim.selected       = sec.altAnim;
		if (chkChangeBPM   != null) chkChangeBPM.selected     = sec.changeBPM;
		if (stepSectionBPM != null) stepSectionBPM.pos        = sec.changeBPM ? sec.bpm : Conductor.bpm;
		updateHeads();
	}

	function syncUIToNote()
	{
		if (curSelectedNote == null) return;
		if (curSelectedNote[2] != null) { // normal note
			if (stepSusLength != null) stepSusLength.pos = curSelectedNote[2];
			if (curSelectedNote[3] != null) {
				var idx = curNoteTypes.indexOf(curSelectedNote[3]);
				currentType = idx < 0 ? 0 : idx;
				if (dropNoteType != null)
					dropNoteType.text = idx <= 0 ? '' : idx + '. ' + curSelectedNote[3];
			}
		} else { // event note
			var ev = curSelectedNote[1][curEventSelected];
			if (ev != null) {
				if (dropEvent    != null) dropEvent.text  = ev[0];
				if (txtValue1    != null) txtValue1.text  = ev[1];
				if (txtValue2    != null) txtValue2.text  = ev[2];
				for (es in eventStuff)
					if (es[0] == ev[0]) { if (txtEventDesc != null) txtEventDesc.text = es[1]; break; }
			}
		}
		if (txtStrumTime != null) txtStrumTime.text = '' + curSelectedNote[0];
	}

	public inline function updateNoteUI():Void    syncUIToNote();
	public inline function updateSectionUI():Void syncUIToSection();

	function bindHaxeUI()
	{
		// Song
		if (txtSongTitle   != null) txtSongTitle.onChange   = function(_) _song.song        = txtSongTitle.text;
		if (chkNeedsVoices != null) chkNeedsVoices.onChange = function(_) _song.needsVoices = chkNeedsVoices.selected;
		if (stepBPM != null) stepBPM.onChange = function(_) {
			_song.bpm = stepBPM.pos;
			Conductor.mapBPMChanges(_song); Conductor.bpm = stepBPM.pos;
			if (stepSusLength != null) stepSusLength.step = Math.ceil(Conductor.stepCrochet / 2);
			updateGrid();
		};
		if (stepSpeed != null) stepSpeed.onChange = function(_) _song.speed = stepSpeed.pos;
		if (dropPlayer1 != null) dropPlayer1.onChange = function(_) { _song.player1  = dropPlayer1.text; updateJsonData(); updateHeads(); };
		if (dropPlayer2 != null) dropPlayer2.onChange = function(_) { _song.player2  = dropPlayer2.text; updateJsonData(); updateHeads(); };
		if (dropGF      != null) dropGF.onChange      = function(_) { _song.gfVersion= dropGF.text;      updateJsonData(); updateHeads(); };
		if (dropStage   != null) dropStage.onChange   = function(_) _song.stage = dropStage.text;

		bindBtn("btnSave",        saveLevel);
		bindBtn("btnSaveEvents",  saveEvents);
		bindBtn("btnReloadAudio", function() {
			currentSongName = Paths.formatToSongPath(txtSongTitle != null ? txtSongTitle.text : _song.song);
			updateJsonData(); loadSong(); updateWaveform();
		});
		bindBtn("btnReloadJson", function() {
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0,
				function() loadJson(_song.song.toLowerCase()), null, ignoreWarnings));
		});
		bindBtn("btnLoadAutosave", function() {
			PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
			MusicBeatState.resetState();
		});
		bindBtn("btnLoadEvents", function() {
			var sn = Paths.formatToSongPath(_song.song);
			var fi = Paths.json(sn + '/events');
			#if sys
			if (#if MODS_ALLOWED FileSystem.exists(Paths.modsJson(sn + '/events')) || #end FileSystem.exists(fi))
			#else
			if (OpenFlAssets.exists(fi))
			#end
			{ clearEvents(); var ev = Song.loadFromJson('events', sn); _song.events = ev.events; changeSection(curSec); }
		});
		bindBtn("btnClearNotes", function() {
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, clearSong, null, ignoreWarnings));
		});
		bindBtn("btnClearEvents", function() {
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, clearEvents, null, ignoreWarnings));
		});

		// Section
		if (stepBeats != null) stepBeats.onChange = function(_) { _song.notes[curSec].sectionBeats = stepBeats.pos; reloadGridLayer(); };
		if (chkMustHit   != null) chkMustHit.onChange   = function(_) { _song.notes[curSec].mustHitSection = chkMustHit.selected;   updateGrid(); updateHeads(); };
		if (chkGFSection != null) chkGFSection.onChange = function(_) { _song.notes[curSec].gfSection      = chkGFSection.selected; updateGrid(); updateHeads(); };
		if (chkAltAnim   != null) chkAltAnim.onChange   = function(_) _song.notes[curSec].altAnim   = chkAltAnim.selected;
		if (chkChangeBPM != null) chkChangeBPM.onChange = function(_) _song.notes[curSec].changeBPM = chkChangeBPM.selected;
		if (stepSectionBPM != null) stepSectionBPM.onChange = function(_) { _song.notes[curSec].bpm = stepSectionBPM.pos; updateGrid(); };

		bindBtn("btnCopySection", function() {
			notesCopied = []; sectionToCopy = curSec;
			for (n in _song.notes[curSec].sectionNotes) notesCopied.push(n);
			var st = sectionStartTime(); var et = sectionStartTime(1);
			for (ev in _song.events) if (et > ev[0] && ev[0] >= st) {
				var ca:Array<Dynamic> = []; for (e in (ev[1] : Array<Dynamic>)) ca.push([e[0], e[1], e[2]]);
				notesCopied.push([ev[0], -1, ca]);
			}
		});
		bindBtn("btnPasteSection", function() {
			if (notesCopied == null || notesCopied.length < 1) return;
			var add = Conductor.stepCrochet * (getSectionBeats() * 4 * (curSec - sectionToCopy));
			for (note in notesCopied) {
				var nt = note[0] + add;
				if (note[1] < 0) {
					if (chkCopyEvents != null && chkCopyEvents.selected) {
						var ca:Array<Dynamic> = []; for (e in (note[2] : Array<Dynamic>)) ca.push([e[0],e[1],e[2]]);
						_song.events.push([nt, ca]);
					}
				} else if (chkCopyNotes != null && chkCopyNotes.selected) {
					_song.notes[curSec].sectionNotes.push(note[4] != null
						? [nt, note[1], note[2], note[3], note[4]]
						: [nt, note[1], note[2], note[3]]);
				}
			}
			updateGrid();
		});
		bindBtn("btnClearSection", function() {
			if (chkCopyNotes  != null && chkCopyNotes.selected)  _song.notes[curSec].sectionNotes = [];
			if (chkCopyEvents != null && chkCopyEvents.selected) {
				var st = sectionStartTime(); var et = sectionStartTime(1);
				var i = _song.events.length - 1;
				while (i > -1) { var ev = _song.events[i]; if (ev != null && et > ev[0] && ev[0] >= st) _song.events.remove(ev); --i; }
			}
			updateGrid(); syncUIToNote();
		});
		bindBtn("btnSwapSection", function() {
			for (n in _song.notes[curSec].sectionNotes) n[1] = (n[1] + 4) % 8;
			updateGrid();
		});
		bindBtn("btnMirrorNotes", function() {
			for (note in _song.notes[curSec].sectionNotes) {
				var b = note[1] % 4; b = 3 - b; if (note[1] > 3) b += 4; note[1] = b;
			}
			updateGrid();
		});
		bindBtn("btnDuetNotes", function() {
			var duet:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes) {
				var b = note[1] > 3 ? note[1] - 4 : note[1] + 4;
				duet.push([note[0], b, note[2], note[3]]);
			}
			for (n in duet) _song.notes[curSec].sectionNotes.push(n);
			updateGrid();
		});
		bindBtn("btnCopyLast", function() {
			var val = stepCopyOffset != null ? Std.int(stepCopyOffset.pos) : 1;
			if (val == 0) return;
			var daSec = FlxMath.maxInt(curSec, val);
			for (note in _song.notes[daSec - val].sectionNotes) {
				var st = note[0] + Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * val);
				_song.notes[daSec].sectionNotes.push([st, note[1], note[2], note[3]]);
			}
			var startT = sectionStartTime(-val); var endT = sectionStartTime(-val + 1);
			for (ev in _song.events) if (endT > ev[0] && ev[0] >= startT) {
				var nt = ev[0] + Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * val);
				var ca:Array<Dynamic> = []; for (e in (ev[1] : Array<Dynamic>)) ca.push([e[0],e[1],e[2]]);
				_song.events.push([nt, ca]);
			}
			updateGrid();
		});

		// Note
		if (txtStrumTime != null) txtStrumTime.onChange = function(_) {
			if (curSelectedNote == null) return;
			var v = Std.parseFloat(txtStrumTime.text);
			if (Math.isNaN(v)) v = 0;
			curSelectedNote[0] = v; updateGrid();
		};
		if (stepSusLength != null) stepSusLength.onChange = function(_) {
			if (curSelectedNote != null && curSelectedNote[2] != null) { curSelectedNote[2] = stepSusLength.pos; updateGrid(); }
		};
		if (dropNoteType != null) dropNoteType.onChange = function(_) {
			currentType = dropNoteType.selectedIndex;
			if (curSelectedNote != null && curSelectedNote[1] > -1) { curSelectedNote[3] = curNoteTypes[currentType]; updateGrid(); }
		};

		// Events
		if (dropEvent != null) dropEvent.onChange = function(_) {
			var idx = dropEvent.selectedIndex;
			if (curSelectedNote != null && curSelectedNote[2] == null && idx >= 0 && idx < eventStuff.length) {
				curSelectedNote[1][curEventSelected][0] = eventStuff[idx][0];
				if (txtEventDesc != null) txtEventDesc.text = eventStuff[idx][1];
				updateGrid();
			}
		};
		if (txtValue1 != null) txtValue1.onChange = function(_) {
			if (curSelectedNote != null && curSelectedNote[2] == null && curSelectedNote[1][curEventSelected] != null)
			{ curSelectedNote[1][curEventSelected][1] = txtValue1.text; updateGrid(); }
		};
		if (txtValue2 != null) txtValue2.onChange = function(_) {
			if (curSelectedNote != null && curSelectedNote[2] == null && curSelectedNote[1][curEventSelected] != null)
			{ curSelectedNote[1][curEventSelected][2] = txtValue2.text; updateGrid(); }
		};
		bindBtn("btnAddEvent", function() {
			if (curSelectedNote != null && curSelectedNote[2] == null) {
				curSelectedNote[1].push(['','','']); changeEventSelected(1); updateGrid();
			}
		});
		bindBtn("btnRemoveEvent", function() {
			if (curSelectedNote == null || curSelectedNote[2] != null) return;
			if (curSelectedNote[1].length < 2) { _song.events.remove(curSelectedNote); curSelectedNote = null; }
			else { curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]); --curEventSelected; if (curEventSelected < 0) curEventSelected = 0; }
			changeEventSelected(); updateGrid();
		});
		bindBtn("btnPrevEvent", function() changeEventSelected(-1));
		bindBtn("btnNextEvent", function() changeEventSelected(1));

		// Charting
		if (chkVortex != null) chkVortex.onChange = function(_) {
			vortex = chkVortex.selected; FlxG.save.data.chart_vortex = vortex; reloadGridLayer();
		};
		if (chkMouseQuant != null) chkMouseQuant.onChange = function(_) {
			mouseQuant = chkMouseQuant.selected; FlxG.save.data.mouseScrollingQuant = mouseQuant;
		};
		if (chkIgnoreWarnings != null) chkIgnoreWarnings.onChange = function(_) {
			ignoreWarnings = chkIgnoreWarnings.selected; FlxG.save.data.ignoreWarnings = ignoreWarnings;
		};
		if (chkMetronome     != null) chkMetronome.onChange     = function(_) FlxG.save.data.chart_metronome    = chkMetronome.selected;
		if (chkDisableScroll != null) chkDisableScroll.onChange = function(_) FlxG.save.data.chart_noAutoScroll  = chkDisableScroll.selected;
		if (chkPlaySoundBF   != null) chkPlaySoundBF.onChange   = function(_) FlxG.save.data.chart_playSoundBf   = chkPlaySoundBF.selected;
		if (chkPlaySoundDad  != null) chkPlaySoundDad.onChange  = function(_) FlxG.save.data.chart_playSoundDad  = chkPlaySoundDad.selected;

		// waveform – mutually exclusive
		if (chkWaveInst != null) chkWaveInst.onChange = function(_) {
			if (chkWaveInst.selected) { if (chkWaveVoices != null) chkWaveVoices.selected = false; if (chkWaveOppVoices != null) chkWaveOppVoices.selected = false; FlxG.save.data.chart_waveformVoices = false; FlxG.save.data.chart_waveformOppVoices = false; }
			FlxG.save.data.chart_waveformInst = chkWaveInst.selected; updateWaveform();
		};
		if (chkWaveVoices != null) chkWaveVoices.onChange = function(_) {
			if (chkWaveVoices.selected) { if (chkWaveInst != null) chkWaveInst.selected = false; if (chkWaveOppVoices != null) chkWaveOppVoices.selected = false; FlxG.save.data.chart_waveformInst = false; FlxG.save.data.chart_waveformOppVoices = false; }
			FlxG.save.data.chart_waveformVoices = chkWaveVoices.selected; updateWaveform();
		};
		if (chkWaveOppVoices != null) chkWaveOppVoices.onChange = function(_) {
			if (chkWaveOppVoices.selected) { if (chkWaveInst != null) chkWaveInst.selected = false; if (chkWaveVoices != null) chkWaveVoices.selected = false; FlxG.save.data.chart_waveformInst = false; FlxG.save.data.chart_waveformVoices = false; }
			FlxG.save.data.chart_waveformOppVoices = chkWaveOppVoices.selected; updateWaveform();
		};

		// volumes
		if (stepInstVol  != null) stepInstVol.onChange  = function(_) { FlxG.sound.music.volume = stepInstVol.pos; if (chkMuteInst != null && chkMuteInst.selected) FlxG.sound.music.volume = 0; };
		if (chkMuteInst  != null) chkMuteInst.onChange  = function(_) { FlxG.sound.music.volume = chkMuteInst.selected ? 0 : (stepInstVol != null ? stepInstVol.pos : 1); };
		if (stepVocalsVol!= null) stepVocalsVol.onChange = function(_) { if (vocals != null) { vocals.volume = stepVocalsVol.pos; if (chkMuteVocals != null && chkMuteVocals.selected) vocals.volume = 0; } };
		if (chkMuteVocals!= null) chkMuteVocals.onChange = function(_) { if (vocals != null) vocals.volume = chkMuteVocals.selected ? 0 : (stepVocalsVol != null ? stepVocalsVol.pos : 1); };
		if (stepOppVol   != null) stepOppVol.onChange   = function(_) { if (opponentVocals != null) { opponentVocals.volume = stepOppVol.pos; if (chkMuteOpp != null && chkMuteOpp.selected) opponentVocals.volume = 0; } };
		if (chkMuteOpp   != null) chkMuteOpp.onChange   = function(_) { if (opponentVocals != null) opponentVocals.volume = chkMuteOpp.selected ? 0 : (stepOppVol != null ? stepOppVol.pos : 1); };
		if (sldPlaybackRate != null) sldPlaybackRate.onChange = function(_) playbackSpeed = sldPlaybackRate.pos;

		// Data
		if (txtNoteSkin      != null) txtNoteSkin.onChange      = function(_) _song.arrowSkin     = txtNoteSkin.text;
		if (txtNoteSplashes  != null) txtNoteSplashes.onChange  = function(_) _song.splashSkin    = txtNoteSplashes.text;
		if (chkDisableNoteRGB!= null) chkDisableNoteRGB.onChange= function(_) { _song.disableNoteRGB = chkDisableNoteRGB.selected; updateGrid(); };
		if (txtGameOverChar  != null) txtGameOverChar.onChange  = function(_) _song.gameOverChar  = txtGameOverChar.text;
		if (txtGameOverSound != null) txtGameOverSound.onChange = function(_) _song.gameOverSound = txtGameOverSound.text;
		if (txtGameOverLoop  != null) txtGameOverLoop.onChange  = function(_) _song.gameOverLoop  = txtGameOverLoop.text;
		if (txtGameOverEnd   != null) txtGameOverEnd.onChange   = function(_) _song.gameOverEnd   = txtGameOverEnd.text;
		bindBtn("btnChangeNotes", function() { _song.arrowSkin = txtNoteSkin != null ? txtNoteSkin.text : ''; updateGrid(); });
	}

	inline function bindBtn(id:String, cb:Void->Void)
	{
		var btn = uiRoot.findComponent(id, Button);
		if (btn != null) btn.onClick = function(_) cb();
	}

	override function update(elapsed:Float)
	{
		curStep = recalculateSteps();

		if (FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause(); FlxG.sound.music.time = 0;
		} else if (FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause(); FlxG.sound.music.time = 0; changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		if (txtSongTitle != null) _song.song = txtSongTitle.text;

		strumLineUpdateY();
		for (i in 0...8) strumLineNotes.members[i].y = strumLine.y;
		FlxG.mouse.visible = true;
		camPos.y = strumLine.y;

		// autoscroll
		if (chkDisableScroll == null || !chkDisableScroll.selected) {
			if (Math.ceil(strumLine.y) >= gridBG.height) {
				if (_song.notes[curSec + 1] == null) addSection();
				changeSection(curSec + 1, false);
			} else if (strumLine.y < -10) {
				changeSection(curSec - 1, false);
			}
		}

		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		// grid mouse
		var inGrid = FlxG.mouse.x > gridBG.x && FlxG.mouse.x < gridBG.x + gridBG.width
		          && FlxG.mouse.y > gridBG.y
		          && FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom];

		if (inGrid) {
			dummyArrow.visible = true;
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.SHIFT) dummyArrow.y = FlxG.mouse.y;
			else { var gm = GRID_SIZE / (quantization / 16); dummyArrow.y = Math.floor(FlxG.mouse.y / gm) * gm; }
		} else {
			dummyArrow.visible = false;
		}

		if (FlxG.mouse.justPressed) {
			if (FlxG.mouse.overlaps(curRenderedNotes)) {
				curRenderedNotes.forEachAlive(function(note:Note) {
					if (FlxG.mouse.overlaps(note)) {
						if      (FlxG.keys.pressed.CONTROL) selectNote(note);
						else if (FlxG.keys.pressed.ALT)    { selectNote(note); curSelectedNote[3] = curNoteTypes[currentType]; updateGrid(); }
						else                               deleteNote(note);
					}
				});
			} else if (inGrid) addNote();
		}

		// block keyboard when HaxeUI has focus
		var blockInput = haxe.ui.focus.FocusManager.instance.focus != null;

		if (!blockInput) {
			ClientPrefs.toggleVolumeKeys(true);
			handleKeyboard(elapsed);
		} else {
			ClientPrefs.toggleVolumeKeys(false);
			// unfocus on Enter
			if (FlxG.keys.justPressed.ENTER)
				haxe.ui.focus.FocusManager.instance.focus = null;
		}

		strumLineNotes.visible = quant.visible = vortex;
		for (i in 0...8) {
			strumLineNotes.members[i].y     = strumLine.y;
			strumLineNotes.members[i].alpha  = FlxG.sound.music.playing ? 1 : 0.35;
		}

		#if FLX_PITCH
		FlxG.sound.music.pitch = playbackSpeed;
		if (vocals         != null) vocals.pitch         = playbackSpeed;
		if (opponentVocals != null) opponentVocals.pitch = playbackSpeed;
		#end

		// note colors + hitsound
		var playedSound:Array<Bool> = [false, false, false, false];
		curRenderedNotes.forEachAlive(function(note:Note) {
			note.alpha = 1;
			if (curSelectedNote != null) {
				var nd = note.noteData;
				if (nd > -1 && note.mustPress != _song.notes[curSec].mustHitSection) nd += 4;
				if (curSelectedNote[0] == note.strumTime
					&& ((curSelectedNote[2] == null && nd < 0) || (curSelectedNote[2] != null && curSelectedNote[1] == nd))) {
					colorSine += elapsed;
					var cv = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
					note.color = FlxColor.fromRGBFloat(cv, cv, cv, 0.999);
				}
			}
			if (note.strumTime <= Conductor.songPosition) {
				note.alpha = 0.4;
				if (note.strumTime > lastConductorPos && FlxG.sound.music.playing && note.noteData > -1) {
					var data = note.noteData % 4;
					var nd   = note.noteData;
					if (nd > -1 && note.mustPress != _song.notes[curSec].mustHitSection) nd += 4;
					strumLineNotes.members[nd].playAnim('confirm', true);
					strumLineNotes.members[nd].resetAnim = ((note.sustainLength / 1000) + 0.15) / playbackSpeed;
					if (!playedSound[data]) {
						var bfOk  = chkPlaySoundBF  != null && chkPlaySoundBF.selected;
						var dadOk = chkPlaySoundDad != null && chkPlaySoundDad.selected;
						if (note.hitsoundChartEditor && ((bfOk && note.mustPress) || (dadOk && !note.mustPress))) {
							var snd = note.hitsound;
							if (_song.player1 == 'gf') snd = 'GF_' + Std.string(data + 1);
							FlxG.sound.play(Paths.sound(snd)).pan = note.noteData < 4 ? -0.3 : 0.3;
							playedSound[data] = true;
						}
						data = note.noteData;
						if (note.mustPress != _song.notes[curSec].mustHitSection) data += 4;
					}
				}
			}
		});

		// metronome
		if (chkMetronome != null && chkMetronome.selected && lastConductorPos != Conductor.songPosition) {
			var offset:Float = stepMetroOffset != null ? stepMetroOffset.pos : 0;
			var bpmM:Float   = stepMetroBPM   != null ? stepMetroBPM.pos    : _song.bpm;
			var interval = 60 / bpmM;
			var step     = Math.floor(((Conductor.songPosition + offset) / interval) / 1000);
			var lastStep = Math.floor(((lastConductorPos       + offset) / interval) / 1000);
			if (step != lastStep) FlxG.sound.play(Paths.sound('Metronome_Tick'));
		}
		lastConductorPos = Conductor.songPosition;

		bpmTxt.text =
			Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2)) + " / " +
			Std.string(FlxMath.roundDecimal(FlxG.sound.music.length  / 1000, 2)) +
			"\nSection: " + curSec +
			"\n\nBeat: "  + Std.string(curDecBeat).substring(0, 4) +
			"\n\nStep: "  + curStep +
			"\n\nBeat Snap: " + quantization + "th";

		super.update(elapsed);
	}

	function handleKeyboard(elapsed:Float)
	{
		if (FlxG.keys.justPressed.ESCAPE) {
			if (FlxG.sound.music != null) FlxG.sound.music.stop();
			if (vocals         != null) { vocals.pause();         vocals.volume         = 0; }
			if (opponentVocals != null) { opponentVocals.pause(); opponentVocals.volume = 0; }
			autosaveSong();
			playtesting = true; playtestingTime = Conductor.songPosition;
			playtestingOnComplete = FlxG.sound.music.onComplete;
			openSubState(new states.editors.EditorPlayState(playbackSpeed)); return;
		}
		if (FlxG.keys.justPressed.ENTER) {
			autosaveSong(); FlxG.mouse.visible = false;
			PlayState.SONG = _song; FlxG.sound.music.stop();
			if (vocals != null) vocals.stop(); if (opponentVocals != null) opponentVocals.stop();
			StageData.loadDirectory(_song); LoadingState.loadAndSwitchState(new PlayState()); return;
		}
		if (FlxG.keys.justPressed.BACKSPACE) {
			autosaveSong(); PlayState.chartingMode = false;
			MusicBeatState.switchState(new states.editors.MasterEditorMenu());
			FlxG.sound.playMusic(Paths.music('freakyMenu')); FlxG.mouse.visible = false; return;
		}

		if (FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL) undo();
		if (FlxG.keys.justPressed.Z && curZoom > 0 && !FlxG.keys.pressed.CONTROL) { --curZoom; updateZoom(); }
		if (FlxG.keys.justPressed.X && curZoom < zoomList.length - 1)             { ++curZoom; updateZoom(); }

		if (curSelectedNote != null && curSelectedNote[1] > -1) {
			if (FlxG.keys.justPressed.E) changeNoteSustain( Conductor.stepCrochet);
			if (FlxG.keys.justPressed.Q) changeNoteSustain(-Conductor.stepCrochet);
		}

		if (FlxG.keys.justPressed.SPACE) {
			if (vocals != null) vocals.play(); if (opponentVocals != null) opponentVocals.play();
			pauseAndSetVocalsTime();
			if (!FlxG.sound.music.playing) {
				FlxG.sound.music.play();
				if (vocals != null) vocals.play(); if (opponentVocals != null) opponentVocals.play();
			} else FlxG.sound.music.pause();
		}
		if (!FlxG.keys.pressed.ALT && FlxG.keys.justPressed.R)
			resetSection(FlxG.keys.pressed.SHIFT);

		if (FlxG.mouse.wheel != 0) {
			FlxG.sound.music.pause();
			if (!mouseQuant) FlxG.sound.music.time -= FlxG.mouse.wheel * Conductor.stepCrochet * 0.8;
			else {
				var snap = quantization / 4; var inc = 1 / snap;
				var dir  = FlxG.mouse.wheel > 0 ? -inc : inc;
				FlxG.sound.music.time = Conductor.beatToSeconds(CoolUtil.quantize(curDecBeat, snap) + dir);
			}
			pauseAndSetVocalsTime();
		}
		if (FlxG.keys.pressed.W || FlxG.keys.pressed.S) {
			FlxG.sound.music.pause();
			var mul:Float = FlxG.keys.pressed.CONTROL ? 0.25 : (FlxG.keys.pressed.SHIFT ? 4 : 1);
			FlxG.sound.music.time += 700 * FlxG.elapsed * mul * (FlxG.keys.pressed.W ? -1 : 1);
			pauseAndSetVocalsTime();
		}

		if (!vortex && (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)) {
			FlxG.sound.music.pause();
			var snap = quantization / 4; var inc = 1 / snap;
			var dir  = FlxG.keys.pressed.UP ? -inc : inc;
			FlxG.sound.music.time = Conductor.beatToSeconds(CoolUtil.quantize(curDecBeat, snap) + dir);
		}

		if (FlxG.keys.justPressed.LEFT)  { --curQuant; if (curQuant < 0) curQuant = quantizations.length - 1; quantization = quantizations[curQuant]; }
		if (FlxG.keys.justPressed.RIGHT) { ++curQuant; if (curQuant > quantizations.length - 1) curQuant = 0; quantization = quantizations[curQuant]; }
		quant.animation.play('q', true, false, curQuant);

		var shift = FlxG.keys.pressed.SHIFT ? 4 : 1;
		if (FlxG.keys.justPressed.D) changeSection(curSec + shift);
		if (FlxG.keys.justPressed.A) changeSection(curSec <= 0 ? _song.notes.length - 1 : curSec - shift);

		if (vortex) {
			var ctrl = [FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
			            FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT];
			var style = FlxG.keys.pressed.SHIFT ? 3 : currentType;
			for (i in 0...ctrl.length) if (ctrl[i]) doANoteThing(Conductor.songPosition, i, style);

			if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN) {
				FlxG.sound.music.pause();
				var snap = quantization / 4; var inc = 1 / snap;
				var dir  = FlxG.keys.pressed.UP ? -inc : inc;
				var feces = Conductor.beatToSeconds(CoolUtil.quantize(curDecBeat, snap) + dir);
				FlxTween.tween(FlxG.sound.music, { time: feces }, 0.1, { ease: FlxEase.circOut });
				pauseAndSetVocalsTime();

				if (curSelectedNote != null) {
					var secStart = sectionStartTime();
					var datime = (feces - secStart) - (curSelectedNote[0] - secStart);
					var held = [FlxG.keys.pressed.ONE, FlxG.keys.pressed.TWO, FlxG.keys.pressed.THREE, FlxG.keys.pressed.FOUR,
					            FlxG.keys.pressed.FIVE, FlxG.keys.pressed.SIX, FlxG.keys.pressed.SEVEN, FlxG.keys.pressed.EIGHT];
					if (held.contains(true)) {
						for (i in 0...held.length)
							if (held[i] && curSelectedNote[1] == i)
								curSelectedNote[2] += datime - curSelectedNote[2] - Conductor.stepCrochet;
						updateGrid(); syncUIToNote();
					}
				}
			}
		}

		#if FLX_PITCH
		var holdingShift = FlxG.keys.pressed.SHIFT;
		var pressedLB = FlxG.keys.justPressed.LBRACKET; var holdingLB = FlxG.keys.pressed.LBRACKET;
		var pressedRB = FlxG.keys.justPressed.RBRACKET; var holdingRB = FlxG.keys.pressed.RBRACKET;
		if (!holdingShift && pressedLB || holdingShift && holdingLB) playbackSpeed -= 0.01;
		if (!holdingShift && pressedRB || holdingShift && holdingRB) playbackSpeed += 0.01;
		if (FlxG.keys.pressed.ALT && (pressedLB || pressedRB || holdingLB || holdingRB)) playbackSpeed = 1;
		playbackSpeed = FlxMath.bound(playbackSpeed, 0.5, 3);
		if (sldPlaybackRate != null) sldPlaybackRate.pos = playbackSpeed;
		#end
	}

	override function closeSubState()
	{
		if (playtesting) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = playtestingTime;
			FlxG.sound.music.onComplete = playtestingOnComplete;
			if (stepInstVol  != null) FlxG.sound.music.volume = stepInstVol.pos;
			if (chkMuteInst  != null && chkMuteInst.selected) FlxG.sound.music.volume = 0;
			if (vocals != null) {
				vocals.pause(); vocals.time = playtestingTime;
				if (stepVocalsVol != null) vocals.volume = stepVocalsVol.pos;
				if (chkMuteVocals != null && chkMuteVocals.selected) vocals.volume = 0;
			}
			if (opponentVocals != null) {
				opponentVocals.pause(); opponentVocals.time = playtestingTime;
				if (stepOppVol != null) opponentVocals.volume = stepOppVol.pos;
				if (chkMuteOpp != null && chkMuteOpp.selected) opponentVocals.volume = 0;
			}
			#if DISCORD_ALLOWED
			DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, '-', ' '));
			#end
		}
		super.closeSubState();
	}

	function changeEventSelected(change:Int = 0)
	{
		if (curSelectedNote != null && curSelectedNote[2] == null) {
			curEventSelected += change;
			if (curEventSelected < 0) curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if (curEventSelected >= curSelectedNote[1].length) curEventSelected = 0;
			if (lblSelectedEvent != null)
				lblSelectedEvent.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedNote[1].length;
		} else {
			curEventSelected = 0;
			if (lblSelectedEvent != null) lblSelectedEvent.text = 'Selected Event: None';
		}
		syncUIToNote();
	}

	function loadSong():Void
	{
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		if (vocals         != null) { vocals.stop();         vocals.destroy(); }
		if (opponentVocals != null) { opponentVocals.stop(); opponentVocals.destroy(); }

		vocals         = new FlxSound();
		opponentVocals = new FlxSound();
		try {
			var pv = Paths.voices(currentSongName, (characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? 'Player' : characterData.vocalsP1);
			vocals.loadEmbedded(pv != null ? pv : Paths.voices(currentSongName));
		}
		vocals.autoDestroy = false; FlxG.sound.list.add(vocals);
		try {
			var ov = Paths.voices(currentSongName, (characterData.vocalsP2 == null || characterData.vocalsP2.length < 1) ? 'Opponent' : characterData.vocalsP2);
			if (ov != null) opponentVocals.loadEmbedded(ov);
		}
		opponentVocals.autoDestroy = false; FlxG.sound.list.add(opponentVocals);

		generateSong();
		FlxG.sound.music.pause();
		Conductor.songPosition = sectionStartTime();
		FlxG.sound.music.time  = Conductor.songPosition;

		var curTime:Float = 0;
		if (_song.notes.length <= 1) {
			while (curTime < FlxG.sound.music.length) { addSection(); curTime += (60 / _song.bpm) * 4000; }
		}
	}

	function generateSong()
	{
		FlxG.sound.playMusic(Paths.inst(currentSongName), 0.6);
		FlxG.sound.music.autoDestroy = false;
		if (stepInstVol != null) FlxG.sound.music.volume = stepInstVol.pos;
		if (chkMuteInst != null && chkMuteInst.selected) FlxG.sound.music.volume = 0;
		FlxG.sound.music.onComplete = function() {
			FlxG.sound.music.pause(); Conductor.songPosition = 0;
			if (vocals         != null) { vocals.pause();         vocals.time         = 0; }
			if (opponentVocals != null) { opponentVocals.pause(); opponentVocals.time = 0; }
			changeSection(); curSec = 0; updateGrid(); syncUIToSection();
			if (vocals != null) vocals.play(); if (opponentVocals != null) opponentVocals.play();
		};
	}

	function sectionStartTime(add:Int = 0):Float
	{
		var bpm:Float = _song.bpm; var pos:Float = 0;
		for (i in 0...curSec + add) {
			if (_song.notes[i] != null) {
				if (_song.notes[i].changeBPM) bpm = _song.notes[i].bpm;
				pos += getSectionBeats(i) * (1000 * 60 / bpm);
			}
		}
		return pos;
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		if (_song.notes[sec] == null) { changeSection(); return; }
		var waveChanged = false; curSec = sec;
		if (updateMusic) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = sectionStartTime();
			pauseAndSetVocalsTime(); updateCurStep();
		}
		var b1 = getSectionBeats();
		var b2 = sectionStartTime(1) > FlxG.sound.music.length ? 0.0 : getSectionBeats(curSec + 1);
		if (b1 != lastSecBeats || b2 != lastSecBeatsNext) { reloadGridLayer(); waveChanged = true; }
		else updateGrid();
		syncUIToSection();
		Conductor.songPosition = FlxG.sound.music.time;
		if (!waveChanged) updateWaveform();
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();
		FlxG.sound.music.pause(); FlxG.sound.music.time = sectionStartTime();
		if (songBeginning) { FlxG.sound.music.time = 0; curSec = 0; }
		pauseAndSetVocalsTime(); updateCurStep();
		updateGrid(); syncUIToSection(); updateWaveform();
	}

	private function addSection(sectionBeats:Float = 4):Void
	{
		_song.notes.push({
			sectionBeats: sectionBeats, bpm: _song.bpm, changeBPM: false,
			mustHitSection: true, gfSection: false, sectionNotes: [], altAnim: false
		});
	}

	function reloadGridLayer()
	{
		gridLayer.clear();
		gridBG = FlxGridOverlay.create(1, 1, columns, Std.int(getSectionBeats() * 4 * zoomList[curZoom]));
		gridBG.antialiasing = false; gridBG.scale.set(GRID_SIZE, GRID_SIZE); gridBG.updateHitbox();

		#if desktop
		if (FlxG.save.data.chart_waveformInst || FlxG.save.data.chart_waveformVoices || FlxG.save.data.chart_waveformOppVoices)
			updateWaveform();
		#end

		var leHeight = Std.int(gridBG.height);
		var foundNextSec = sectionStartTime(1) <= FlxG.sound.music.length;
		if (foundNextSec) {
			nextGridBG = FlxGridOverlay.create(1, 1, columns, Std.int(getSectionBeats(curSec + 1) * 4 * zoomList[curZoom]));
			nextGridBG.antialiasing = false; nextGridBG.scale.set(GRID_SIZE, GRID_SIZE); nextGridBG.updateHitbox();
			leHeight = Std.int(gridBG.height + nextGridBG.height);
		} else nextGridBG = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		nextGridBG.y = gridBG.height;

		gridLayer.add(nextGridBG);
		gridLayer.add(gridBG);

		if (foundNextSec) {
			var black = new FlxSprite(0, gridBG.height).makeGraphic(1, 1, FlxColor.BLACK);
			black.setGraphicSize(Std.int(GRID_SIZE * 9), Std.int(nextGridBG.height));
			black.updateHitbox(); black.antialiasing = false; black.alpha = 0.4;
			gridLayer.add(black);
		}

		var midLine = new FlxSprite(gridBG.x + gridBG.width - (GRID_SIZE * 4)).makeGraphic(1, 1, FlxColor.BLACK);
		midLine.setGraphicSize(2, leHeight); midLine.updateHitbox(); midLine.antialiasing = false;
		gridLayer.add(midLine);

		for (i in 1...Std.int(getSectionBeats())) {
			var sep = new FlxSprite(gridBG.x, (GRID_SIZE * (4 * zoomList[curZoom])) * i).makeGraphic(1, 1, 0x44FF0000);
			sep.scale.x = gridBG.width; sep.updateHitbox();
			if (vortex) gridLayer.add(sep);
		}

		var sideLine = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(1, 1, FlxColor.BLACK);
		sideLine.setGraphicSize(2, leHeight); sideLine.updateHitbox(); sideLine.antialiasing = false;
		gridLayer.add(sideLine);

		updateGrid();
		lastSecBeats     = getSectionBeats();
		lastSecBeatsNext = foundNextSec ? getSectionBeats(curSec + 1) : 0;
	}

	function updateGrid():Void
	{
		curRenderedNotes.forEachAlive(function(s) s.destroy());     curRenderedNotes.clear();
		curRenderedSustains.forEachAlive(function(s) s.destroy());  curRenderedSustains.clear();
		curRenderedNoteType.forEachAlive(function(s) s.destroy());  curRenderedNoteType.clear();
		nextRenderedNotes.forEachAlive(function(s) s.destroy());    nextRenderedNotes.clear();
		nextRenderedSustains.forEachAlive(function(s) s.destroy()); nextRenderedSustains.clear();

		if (_song.notes[curSec].changeBPM && _song.notes[curSec].bpm > 0)
			Conductor.bpm = _song.notes[curSec].bpm;
		else {
			var bpm = _song.bpm;
			for (i in 0...curSec) if (_song.notes[i].changeBPM) bpm = _song.notes[i].bpm;
			Conductor.bpm = bpm;
		}

		var beats = getSectionBeats();
		for (i in _song.notes[curSec].sectionNotes) {
			var note = setupNoteData(i, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0) curRenderedSustains.add(setupSusNote(note, beats));
			if (i[3] != null && note.noteType != null && note.noteType.length > 0) {
				var ti = curNoteTypes.indexOf(i[3]);
				var t = new AttachedFlxText(0, 0, 100, ti < 0 ? '?' : '' + ti, 24);
				t.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				t.xAdd = -32; t.yAdd = 6; t.borderSize = 1; t.sprTracker = note;
				curRenderedNoteType.add(t);
			}
			note.mustPress = _song.notes[curSec].mustHitSection;
			if (i[1] > 3) note.mustPress = !note.mustPress;
		}

		var st = sectionStartTime(); var et = sectionStartTime(1);
		for (i in _song.events) if (et > i[0] && i[0] >= st) {
			var note = setupNoteData(i, false); curRenderedNotes.add(note);
			var txt = 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)\nValue 1: ' + note.eventVal1 + '\nValue 2: ' + note.eventVal2;
			if (note.eventLength > 1) txt = note.eventLength + ' Events:\n' + note.eventName;
			var t = new AttachedFlxText(0, 0, 400, txt, 12);
			t.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
			t.xAdd = -410; t.borderSize = 1; if (note.eventLength > 1) t.yAdd += 8; t.sprTracker = note;
			curRenderedNoteType.add(t);
		}

		beats = getSectionBeats(1);
		if (curSec < _song.notes.length - 1)
			for (i in _song.notes[curSec + 1].sectionNotes) {
				var note = setupNoteData(i, true); note.alpha = 0.6; nextRenderedNotes.add(note);
				if (note.sustainLength > 0) nextRenderedSustains.add(setupSusNote(note, beats));
			}

		st = sectionStartTime(1); et = sectionStartTime(2);
		for (i in _song.events) if (et > i[0] && i[0] >= st) {
			var note = setupNoteData(i, true); note.alpha = 0.6; nextRenderedNotes.add(note);
		}
	}

	function setupNoteData(i:Array<Dynamic>, isNext:Bool):Note
	{
		var daNoteInfo = i[1]; var daStrumTime = i[0]; var daSus:Dynamic = i[2];
		var note = new Note(daStrumTime, daNoteInfo % 4, null, null, true);
		if (daSus != null) {
			if (!Std.isOfType(i[3], String)) i[3] = curNoteTypes[i[3]];
			if (i.length > 3 && (i[3] == null || i[3].length < 1)) i.remove(i[3]);
			note.sustainLength = daSus; note.noteType = i[3];
		} else {
			note.loadGraphic(Paths.image('eventArrow')); note.rgbShader.enabled = false;
			note.eventName = getEventName(i[1]); note.eventLength = i[1].length;
			if (i[1].length < 2) { note.eventVal1 = i[1][0][1]; note.eventVal2 = i[1][0][2]; }
			note.noteData = -1; daNoteInfo = -1;
		}
		note.setGraphicSize(GRID_SIZE, GRID_SIZE); note.updateHitbox();
		note.x = Math.floor(daNoteInfo * GRID_SIZE) + GRID_SIZE;
		if (isNext && _song.notes[curSec].mustHitSection != _song.notes[curSec + 1].mustHitSection) {
			if (daNoteInfo > 3) note.x -= GRID_SIZE * 4;
			else if (daSus != null) note.x += GRID_SIZE * 4;
		}
		var beats = getSectionBeats(isNext ? 1 : 0);
		note.y = getYfromStrumNotes(daStrumTime - sectionStartTime(), beats);
		if (note.y < -150) note.y = -150;
		return note;
	}

	function getEventName(names:Array<Dynamic>):String
	{
		var out = ''; var first = true;
		for (n in names) { if (!first) out += ', '; out += n[0]; first = false; }
		return out;
	}

	function setupSusNote(note:Note, beats:Float):FlxSprite
	{
		var h = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.stepCrochet * 16, 0, GRID_SIZE * 16 * zoomList[curZoom])
		         + (GRID_SIZE * zoomList[curZoom]) - GRID_SIZE / 2);
		var minH = Std.int((GRID_SIZE * zoomList[curZoom] / 2) + GRID_SIZE / 2);
		if (h < minH) h = minH; if (h < 1) h = 1;
		return new FlxSprite(note.x + (GRID_SIZE * 0.5) - 4, note.y + GRID_SIZE / 2).makeGraphic(8, h);
	}

	private function addNote(strum:Null<Float> = null, data:Null<Int> = null, type:Null<Int> = null):Void
	{
		var noteStrum = getStrumTime(dummyArrow.y * (getSectionBeats() / 4), false) + sectionStartTime();
		var noteData  = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		var daType    = currentType;
		if (strum != null) noteStrum = strum; if (data != null) noteData = data; if (type != null) daType = type;
		if (noteData > -1) {
			_song.notes[curSec].sectionNotes.push([noteStrum, noteData, 0, curNoteTypes[daType]]);
			curSelectedNote = _song.notes[curSec].sectionNotes[_song.notes[curSec].sectionNotes.length - 1];
		} else {
			var evName = eventStuff[dropEvent != null ? dropEvent.selectedIndex : 0][0];
			var v1 = txtValue1 != null ? txtValue1.text : '';
			var v2 = txtValue2 != null ? txtValue2.text : '';
			_song.events.push([noteStrum, [[evName, v1, v2]]]);
			curSelectedNote = _song.events[_song.events.length - 1]; curEventSelected = 0;
		}
		changeEventSelected();
		if (FlxG.keys.pressed.CONTROL && noteData > -1)
			_song.notes[curSec].sectionNotes.push([noteStrum, (noteData + 4) % 8, 0, curNoteTypes[daType]]);
		if (txtStrumTime != null) txtStrumTime.text = '' + curSelectedNote[0];
		updateGrid(); syncUIToNote();
	}

	function deleteNote(note:Note):Void
	{
		var nd = note.noteData;
		if (nd > -1 && note.mustPress != _song.notes[curSec].mustHitSection) nd += 4;
		if (note.noteData > -1) {
			for (i in _song.notes[curSec].sectionNotes)
				if (i[0] == note.strumTime && i[1] == nd) {
					if (i == curSelectedNote) curSelectedNote = null;
					_song.notes[curSec].sectionNotes.remove(i); break;
				}
		} else {
			for (i in _song.events)
				if (i[0] == note.strumTime) {
					if (i == curSelectedNote) { curSelectedNote = null; changeEventSelected(); }
					_song.events.remove(i); break;
				}
		}
		updateGrid();
	}

	function selectNote(note:Note):Void
	{
		var nd = note.noteData;
		if (nd > -1) {
			if (note.mustPress != _song.notes[curSec].mustHitSection) nd += 4;
			for (i in _song.notes[curSec].sectionNotes)
				if (i != curSelectedNote && i.length > 2 && i[0] == note.strumTime && i[1] == nd) { curSelectedNote = i; break; }
		} else {
			for (i in _song.events)
				if (i != curSelectedNote && i[0] == note.strumTime) {
					curSelectedNote = i; curEventSelected = Std.int(curSelectedNote[1].length) - 1; break;
				}
		}
		changeEventSelected(); updateGrid(); syncUIToNote();
	}

	public function doANoteThing(cs:Float, d:Int, style:Int)
	{
		var del = false;
		if (strumLineNotes.members[d].overlaps(curRenderedNotes))
			curRenderedNotes.forEachAlive(function(note:Note) {
				if (!del && note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1, strumLine.y + 1)) && note.noteData == d % 4)
				{ deleteNote(note); del = true; }
			});
		if (!del) addNote(cs, d, style);
	}

	function changeNoteSustain(value:Float):Void
	{
		if (curSelectedNote != null && curSelectedNote[2] != null)
			curSelectedNote[2] = Math.max(curSelectedNote[2] + Math.ceil(value), 0);
		syncUIToNote(); updateGrid();
	}

	function updateZoom()
	{
		var z = zoomList[curZoom];
		zoomTxt.text = 'Zoom: ' + (z < 1 ? Math.round(1 / z) + ' / 1' : '1 / ' + z);
		reloadGridLayer();
	}

	function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom]
			% (Conductor.stepCrochet * 16)) / (getSectionBeats() / 4);
	}

	function getStrumTime(yPos:Float, doZoom:Bool = true):Float
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height * (doZoom ? zoomList[curZoom] : 1), 0, 16 * Conductor.stepCrochet);

	function getYfromStrum(strumTime:Float, doZoom:Bool = true):Float
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height * (doZoom ? zoomList[curZoom] : 1));

	function getYfromStrumNotes(strumTime:Float, beats:Float):Float
		return GRID_SIZE * beats * 4 * zoomList[curZoom] * (strumTime / (beats * 4 * Conductor.stepCrochet)) + gridBG.y;

	function pauseAndSetVocalsTime()
	{
		if (vocals         != null) { vocals.pause();         vocals.time         = FlxG.sound.music.time; }
		if (opponentVocals != null) { opponentVocals.pause(); opponentVocals.time = FlxG.sound.music.time; }
	}

	function recalculateSteps(add:Float = 0):Int
	{
		var last:BPMChangeEvent = { stepTime: 0, songTime: 0, bpm: 0 };
		for (ev in Conductor.bpmChangeMap) if (FlxG.sound.music.time > ev.songTime) last = ev;
		curStep = last.stepTime + Math.floor((FlxG.sound.music.time - last.songTime + add) / Conductor.stepCrochet);
		updateBeat(); return curStep;
	}

	function getSectionBeats(?section:Null<Int> = null):Float
	{
		if (section == null) section = curSec;
		var val:Null<Float> = _song.notes[section] != null ? _song.notes[section].sectionBeats : null;
		return val != null ? val : 4;
	}

	function updateJsonData():Void
	{
		for (i in 1...3) {
			var data:CharacterFile = loadCharacterFile(Reflect.field(_song, 'player$i'));
			Reflect.setField(characterData, 'iconP$i', !characterFailed ? data.healthicon : 'face');
			Reflect.setField(characterData, 'vocalsP$i', data.vocals_file != null ? data.vocals_file : '');
		}
	}

	function updateHeads():Void
	{
		if (_song.notes[curSec].mustHitSection) {
			leftIcon.changeIcon(characterData.iconP1); rightIcon.changeIcon(characterData.iconP2);
			if (_song.notes[curSec].gfSection) leftIcon.changeIcon('gf');
		} else {
			leftIcon.changeIcon(characterData.iconP2); rightIcon.changeIcon(characterData.iconP1);
			if (_song.notes[curSec].gfSection) leftIcon.changeIcon('gf');
		}
	}

	function loadCharacterFile(char:String):CharacterFile
	{
		characterFailed = false;
		var path = 'characters/' + char + '.json';
		#if MODS_ALLOWED
		var p = Paths.modFolders(path);
		if (!FileSystem.exists(p)) p = Paths.getSharedPath(path);
		if (!FileSystem.exists(p)) { p = Paths.getSharedPath('characters/' + Character.DEFAULT_CHARACTER + '.json'); characterFailed = true; }
		var raw = File.getContent(p);
		#else
		var p = Paths.getSharedPath(path);
		if (!OpenFlAssets.exists(p)) { p = Paths.getSharedPath('characters/' + Character.DEFAULT_CHARACTER + '.json'); characterFailed = true; }
		var raw = OpenFlAssets.getText(p);
		#end
		return cast Json.parse(raw);
	}

	function updateWaveform()
	{
		#if desktop
		if (waveformPrinted) {
			var w = Std.int(GRID_SIZE * 8); var h = Std.int(gridBG.height);
			if (lastWaveformHeight != h && waveformSprite.pixels != null) {
				waveformSprite.pixels.dispose(); waveformSprite.pixels.disposeImage();
				waveformSprite.makeGraphic(w, h, 0x00FFFFFF); lastWaveformHeight = h;
			}
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, w, h), 0x00FFFFFF);
		}
		waveformPrinted = false;
		if (!FlxG.save.data.chart_waveformInst && !FlxG.save.data.chart_waveformVoices && !FlxG.save.data.chart_waveformOppVoices) return;
		wavData[0][0] = []; wavData[0][1] = []; wavData[1][0] = []; wavData[1][1] = [];
		var steps = Math.round(getSectionBeats() * 4);
		var st = sectionStartTime(); var et = st + (Conductor.stepCrochet * steps);
		var sound:FlxSound = FlxG.sound.music;
		if (FlxG.save.data.chart_waveformVoices)    sound = vocals;
		if (FlxG.save.data.chart_waveformOppVoices) sound = opponentVocals;
		if (sound != null && sound._sound != null && sound._sound.__buffer != null) {
			var bytes = sound._sound.__buffer.data.toBytes();
			wavData = waveformData(sound._sound.__buffer, bytes, st, et, 1, wavData, Std.int(gridBG.height));
		}
		var gSize = Std.int(GRID_SIZE * 8); var hSize = Std.int(gSize / 2);
		var ll = wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length;
		var rl = wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length;
		var len = ll > rl ? ll : rl;
		for (idx in 0...len) {
			var lmin = FlxMath.bound((idx < wavData[0][0].length ? wavData[0][0][idx] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var lmax = FlxMath.bound((idx < wavData[0][1].length ? wavData[0][1][idx] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var rmin = FlxMath.bound((idx < wavData[1][0].length ? wavData[1][0][idx] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var rmax = FlxMath.bound((idx < wavData[1][1].length ? wavData[1][1][idx] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), idx, (lmin + rmin) + (lmax + rmax), 1), FlxColor.BLUE);
		}
		waveformPrinted = true;
		#end
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float,
		multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0],[0]],[[0],[0]]];
		var khz = buffer.sampleRate / 1000; var channels = buffer.channels;
		var index = Std.int(time * khz);
		var samples = (endTime - time) * khz;
		if (steps == null) steps = 1280;
		var spr = samples / steps; var sprI = Std.int(spr);
		var gotIdx = 0; var lmin = 0.0; var lmax = 0.0; var rmin = 0.0; var rmax = 0.0; var rows = 0.0;
		if (array == null) array = [[[0],[0]],[[0],[0]]];
		while (index < bytes.length - 1) {
			if (index >= 0) {
				var b = bytes.getUInt16(index * channels * 2);
				if (b > 32767) b -= 65535; var s = b / 65535.0;
				if (s > 0 && s > lmax) lmax = s; else if (s < 0 && s < lmin) lmin = s;
				if (channels >= 2) {
					b = bytes.getUInt16((index * channels * 2) + 2);
					if (b > 32767) b -= 65535; s = b / 65535.0;
					if (s > 0 && s > rmax) rmax = s; else if (s < 0 && s < rmin) rmin = s;
				}
			}
			var v1 = sprI > 0 ? (index % sprI == 0) : false;
			while (v1) {
				v1 = false; rows -= spr; gotIdx++;
				var lRMin = Math.abs(lmin) * multiply; var lRMax = lmax * multiply;
				var rRMin = Math.abs(rmin) * multiply; var rRMax = rmax * multiply;
				inline function push(arr:Array<Float>, v:Float) { if (gotIdx > arr.length) arr.push(v); else arr[gotIdx - 1] += v; }
				push(array[0][0], lRMin); push(array[0][1], lRMax);
				if (channels >= 2) { push(array[1][0], rRMin); push(array[1][1], rRMax); }
				else               { push(array[1][0], lRMin); push(array[1][1], lRMax); }
				lmin = 0; lmax = 0; rmin = 0; rmax = 0;
			}
			index++; rows++;
			if (gotIdx > steps) break;
		}
		return array;
		#else
		return [[[0],[0]],[[0],[0]]];
		#end
	}

	private function saveLevel()
	{
		if (_song.events != null && _song.events.length > 1) _song.events.sort(sortByTime);
		var data = haxe.Json.stringify({ "song": _song }, "\t");
		if (data != null && data.length > 0) {
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Paths.formatToSongPath(_song.song) + ".json");
		}
	}

	private function saveEvents()
	{
		if (_song.events != null && _song.events.length > 1) _song.events.sort(sortByTime);
		var data = haxe.Json.stringify({ "song": { events: _song.events } }, "\t");
		if (data != null && data.length > 0) {
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "events.json");
		}
	}

	function sortByTime(a:Array<Dynamic>, b:Array<Dynamic>):Int
		return FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]);

	function autosaveSong():Void
	{
		FlxG.save.data.autosave = haxe.Json.stringify({ "song": _song });
		FlxG.save.flush();
	}

	function loadJson(song:String):Void
	{
		try {
			PlayState.SONG = (Difficulty.getString() != Difficulty.getDefault() && Difficulty.getString() != null)
				? Song.loadFromJson(song + '-' + Difficulty.getString(), song)
				: Song.loadFromJson(song, song);
			MusicBeatState.resetState();
		} catch (e) {
			var err = e.toString();
			if (err.startsWith('[file_contents,assets/data/')) err = 'Missing file: ' + err.substring(27, err.length - 1);
			if (missingText == null) {
				missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
				missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				missingText.scrollFactor.set(); add(missingText);
			} else missingTextTimer.cancel();
			missingText.text = 'ERROR WHILE LOADING CHART:\n$err';
			missingText.screenCenter(Y);
			missingTextTimer = new FlxTimer().start(5, function(_) { remove(missingText); missingText.destroy(); });
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length) _song.notes[daSection].sectionNotes = [];
		updateGrid();
	}

	function clearEvents()
	{
		_song.events = []; updateGrid();
	}

	function getNotes():Array<Dynamic>
	{
		var out:Array<Dynamic> = [];
		for (i in _song.notes) out.push(i.sectionNotes);
		return out;
	}

	function onSaveComplete(_):Void  { cleanFile(); FlxG.log.notice("Saved."); }
	function onSaveCancel(_):Void    { cleanFile(); }
	function onSaveError(_):Void     { cleanFile(); FlxG.log.error("Save error."); }
	function cleanFile():Void
	{
		_file.removeEventListener(Event.COMPLETE,        onSaveComplete);
		_file.removeEventListener(Event.CANCEL,          onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	function undo() { undos.pop(); }
	function redo() {}

	override function destroy()
	{
		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();
		super.destroy();
	}
}

class AttachedFlxText extends FlxText
{
	public var sprTracker:FlxSprite;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;

	public function new(X:Float = 0, Y:Float = 0, W:Float = 0, ?T:String, S:Int = 8, Emb:Bool = true)
		super(X, Y, W, T, S, Emb);

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (sprTracker != null) {
			setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
			angle = sprTracker.angle;
			alpha = sprTracker.alpha;
		}
	}
}
