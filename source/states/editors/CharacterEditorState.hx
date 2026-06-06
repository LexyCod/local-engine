package states.editors;

import flixel.FlxObject;
import flixel.graphics.FlxGraphic;
import flixel.animation.FlxAnimation;
import flixel.system.debug.interaction.tools.Pointer.GraphicCursorCross;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.*;
import flixel.ui.FlxButton;
import flixel.util.FlxDestroyUtil;

import openfl.net.FileReference;
import openfl.net.FileFilter;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.utils.Assets;
import lime.system.Clipboard;

import backend.ZipModManager;
import objects.Character;
import objects.HealthIcon;
import objects.Bar;

import haxe.ui.Toolkit;
import haxe.ui.core.Component;
import haxe.ui.ComponentBuilder;
import haxe.ui.components.Button;
import haxe.ui.components.CheckBox;
import haxe.ui.components.DropDown;
import haxe.ui.components.TextField;
import haxe.ui.components.Slider;
import haxe.ui.containers.ListView;
import haxe.ui.containers.TabView;
import haxe.ui.containers.VBox;
import haxe.ui.containers.HBox;
import haxe.ui.focus.FocusManager;

#if sys
import sys.FileSystem;
#end

class CharacterEditorState extends MusicBeatState
{
	var character:Character;
	var ghost:FlxSprite;
	var cameraFollowPointer:FlxSprite;

	var silhouettes:FlxSpriteGroup;
	var dadPosition = FlxPoint.weak();
	var bfPosition = FlxPoint.weak();

	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;
	var cameraZoomText:FlxText;
	var frameAdvanceText:FlxText;
	var notifText:FlxText;

	var healthBar:Bar;
	var healthIcon:HealthIcon;
	var uiIcon:HealthIcon; 
	
	var colorWheel:FlxSprite;
	var isSelectingColor:Bool = false;
	var tempColor:FlxColor = FlxColor.WHITE;

	var copiedOffset:Array<Float> = [0, 0];
	var _char:String = null;
	var _goToPlayState:Bool = true;
	var anims:Array<Dynamic> = null;
	var curAnim:Int = 0;

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;
	private var camMenu:FlxCamera;

	var undoStack:Array<Array<Float>> = [];
	var redoStack:Array<Array<Float>> = [];
	final MAX_UNDO:Int = 25;
	var notifTimer:Float = 0;
	var uiRoot:Component;
	var listAnimations:ListView;
	var iconBrowseFile:FileReference;
	
	var dragTarget:Component = null;
	var dragOffsetX:Float = 0;
	var dragOffsetY:Float = 0;

	public function new(char:String = null, goToPlayState:Bool = true)
	{
		this._char = char;
		this._goToPlayState = goToPlayState;
		if(this._char == null) this._char = Character.DEFAULT_CHARACTER;
		super();
	}

	override function create()
	{
		@:privateAccess haxe.ui.backend.flixel.CursorHelper.mouseLoadFunction = function(id:String) { return null; };
		if(ClientPrefs.data.cacheOnGPU) Paths.clearStoredMemory();

		FlxG.mouse.visible = true;

		FlxG.sound.music.stop();
		camEditor = initPsychCamera();

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		camMenu = new FlxCamera();
		camMenu.bgColor.alpha = 0;
		FlxG.cameras.add(camMenu, false);

		Toolkit.init();
		haxe.ui.Toolkit.theme = "dark";

		loadBG();
		silhouettes = new FlxSpriteGroup();
		add(silhouettes);
		try {
			var dad:FlxSprite = new FlxSprite(dadPosition.x, dadPosition.y).loadGraphic(Paths.image('editors/silhouetteDad'));
			dad.antialiasing = ClientPrefs.data.antialiasing;
			dad.active = false;
			dad.offset.set(-4, 1);
			silhouettes.add(dad);
		} catch(e:Dynamic) {}

		try {
			var boyfriend:FlxSprite = new FlxSprite(bfPosition.x, bfPosition.y + 350).loadGraphic(Paths.image('editors/silhouetteBF'));
			boyfriend.antialiasing = ClientPrefs.data.antialiasing;
			boyfriend.active = false;
			boyfriend.offset.set(-6, 2);
			silhouettes.add(boyfriend);
		} catch(e:Dynamic) {}
		silhouettes.alpha = 0.25;

		ghost = new FlxSprite();
		ghost.visible = false;
		ghost.alpha = ghostAlpha;
		add(ghost);

		uiRoot = ComponentBuilder.fromFile("assets/exclude/character-editor.xml");
		uiRoot.cameras = [camMenu]; 
		add(uiRoot);

		colorWheel = new FlxSprite().loadGraphic(Paths.image('noteColorMenu/colorWheel'));
		colorWheel.setGraphicSize(120, 120);
		colorWheel.updateHitbox();
		colorWheel.visible = false;
		colorWheel.cameras = [camMenu];
		add(colorWheel);

		listAnimations = uiRoot.findComponent("listAnimations", ListView);

		addCharacter();
		setupDragAndDrop();

		cameraFollowPointer = new FlxSprite().loadGraphic(FlxGraphic.fromClass(GraphicCursorCross));
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
		add(cameraFollowPointer);

		healthBar = new Bar(30, FlxG.height - 75);
		healthBar.scrollFactor.set();
		add(healthBar);
		healthBar.cameras = [camHUD];

		var iconName:String = (character != null && character.healthIcon != null) ? character.healthIcon : 'face';

		healthIcon = new HealthIcon(iconName, false, false);
		healthIcon.y = FlxG.height - 150;
		add(healthIcon);
		healthIcon.cameras = [camHUD];

		uiIcon = new HealthIcon(iconName, false, false);
		uiIcon.cameras = [camMenu];
		add(uiIcon);
		updateUIIconScale();

		reloadCharacterDropDown();
		bindHaxeUI();
		updateUIFields();

		var tipText:FlxText = new FlxText(FlxG.width - 300, FlxG.height - 24, 300, "F1 - Help | F12 - Silhouettes", 16);
		tipText.cameras = [camHUD];
		tipText.setFormat(null, 16, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		tipText.scrollFactor.set();
		add(tipText);

		cameraZoomText = new FlxText(0, 50, 200, 'Camera Zoom: 1x');
		cameraZoomText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		cameraZoomText.screenCenter(X);
		cameraZoomText.cameras = [camHUD];
		add(cameraZoomText);

		frameAdvanceText = new FlxText(0, 75, 350, '');
		frameAdvanceText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		frameAdvanceText.screenCenter(X);
		frameAdvanceText.cameras = [camHUD];
		add(frameAdvanceText);

		notifText = new FlxText(10, 10, 350, '', 14);
		notifText.setFormat(null, 14, FlxColor.LIME, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		notifText.cameras = [camHUD];
		notifText.visible = false;
		add(notifText);

		addHelpScreen();

		FlxG.mouse.visible = true;
		updatePointerPos();
		updateHealthBar();
		character.finishAnimation();
		super.create();
	}

	function setupDragAndDrop()
	{
		var dragSettings = uiRoot.findComponent("dragSettings", HBox);
		var winSettings = uiRoot.findComponent("windowSettings", VBox);
		
		var dragCharacter = uiRoot.findComponent("dragCharacter", HBox);
		var winCharacter = uiRoot.findComponent("windowCharacter", VBox);
		
		var dragColorPicker = uiRoot.findComponent("dragColorPicker", HBox);
		var colorPickerPanel = uiRoot.findComponent("colorPickerPanel", VBox);

		if(dragSettings != null && winSettings != null) {
			dragSettings.registerEvent(haxe.ui.events.MouseEvent.MOUSE_DOWN, function(e) {
				dragTarget = winSettings;
				dragOffsetX = FlxG.mouse.screenX - winSettings.left;
				dragOffsetY = FlxG.mouse.screenY - winSettings.top;
			});
		}
		if(dragCharacter != null && winCharacter != null) {
			dragCharacter.registerEvent(haxe.ui.events.MouseEvent.MOUSE_DOWN, function(e) {
				dragTarget = winCharacter;
				dragOffsetX = FlxG.mouse.screenX - winCharacter.left;
				dragOffsetY = FlxG.mouse.screenY - winCharacter.top;
			});
		}
		if(dragColorPicker != null && colorPickerPanel != null) {
			dragColorPicker.registerEvent(haxe.ui.events.MouseEvent.MOUSE_DOWN, function(e) {
				dragTarget = colorPickerPanel;
				dragOffsetX = FlxG.mouse.screenX - colorPickerPanel.left;
				dragOffsetY = FlxG.mouse.screenY - colorPickerPanel.top;
			});
		}

		uiRoot.registerEvent(haxe.ui.events.MouseEvent.MOUSE_UP, function(e) {
			dragTarget = null;
		});
	}

	function addCharacter(reload:Bool = false)
	{
		var pos:Int = -1;
		if(character != null)
		{
			pos = members.indexOf(character);
			remove(character);
			character.destroy();
		}

		var isPlayer = (reload ? character.isPlayer : !predictCharacterIsNotPlayer(_char));
		try {
			character = new Character(0, 0, _char, isPlayer);
		} catch(e:Dynamic) {
			character = new Character(0, 0, Character.DEFAULT_CHARACTER, isPlayer);
			showNotif('Error loading character: $_char', FlxColor.RED);
		}

		character.debugMode = true;
		if(pos > -1) insert(pos, character);
		else add(character);
		
		updateCharacterPositions();
		reloadAnimList();
		if(healthBar != null && healthIcon != null) updateHealthBar();
	}

	inline function updateUIIconScale()
	{
		if(uiIcon != null && character != null && character.healthIcon != null) {
			uiIcon.changeIcon(character.healthIcon, false);
			uiIcon.scale.set(0.5, 0.5); 
			uiIcon.updateHitbox();
		}
	}

	function updateUIFields()
	{
		if(uiRoot == null || character == null) return;
		
		var chkPlayer = uiRoot.findComponent("chkPlayer", CheckBox);
		if(chkPlayer != null) chkPlayer.selected = character.isPlayer;

		var txtImage = uiRoot.findComponent("txtImage", TextField);
		if(txtImage != null) txtImage.text = character.imageFile;
		var txtHealthIcon = uiRoot.findComponent("txtHealthIcon", TextField);
		if(txtHealthIcon != null) txtHealthIcon.text = character.healthIcon;
		
		var txtVocals = uiRoot.findComponent("txtVocals", TextField);
		if(txtVocals != null) txtVocals.text = character.vocalsFile;

		var chkFlipX = uiRoot.findComponent("chkFlipX", CheckBox);
		if(chkFlipX != null) chkFlipX.selected = character.originalFlipX;
		var chkNoAntialiasing = uiRoot.findComponent("chkNoAntialiasing", CheckBox);
		if(chkNoAntialiasing != null) chkNoAntialiasing.selected = character.noAntialiasing;

		var txtScale = uiRoot.findComponent("txtScale", TextField);
		if(txtScale != null) txtScale.text = Std.string(character.jsonScale);

		var chkVsliceSustains = uiRoot.findComponent("chkVsliceSustains", CheckBox);
		if(chkVsliceSustains != null) chkVsliceSustains.selected = character.vSliceSustains;

		var sldSingDuration = uiRoot.findComponent("sldSingDuration", Slider);
		if(sldSingDuration != null) sldSingDuration.pos = character.singDuration;

		var txtGameoverChar = uiRoot.findComponent("txtGameoverChar", TextField);
		if(txtGameoverChar != null) txtGameoverChar.text = character.gameoverCharacter != null ? character.gameoverCharacter : "";

		var txtGameoverInit = uiRoot.findComponent("txtGameoverInit", TextField);
		if(txtGameoverInit != null) txtGameoverInit.text = character.gameoverInitialDeathSound != null ? character.gameoverInitialDeathSound : "";

		var txtGameoverLoop = uiRoot.findComponent("txtGameoverLoop", TextField);
		if(txtGameoverLoop != null) txtGameoverLoop.text = character.gameoverLoopDeathSound != null ? character.gameoverLoopDeathSound : "";

		var txtGameoverConfirm = uiRoot.findComponent("txtGameoverConfirm", TextField);
		if(txtGameoverConfirm != null) txtGameoverConfirm.text = character.gameoverConfirmDeathSound != null ? character.gameoverConfirmDeathSound : "";
		
		updateUIIconScale();
	}

	function bindHaxeUI()
	{
		var chkPlayer = uiRoot.findComponent("chkPlayer", CheckBox);
		if(chkPlayer != null) {
			chkPlayer.onChange = function(e) {
				character.isPlayer = chkPlayer.selected;
				character.flipX = (character.originalFlipX != character.isPlayer);
				updateCharacterPositions();
				updatePointerPos(false);
			};
		}

		var txtImage = uiRoot.findComponent("txtImage", TextField);
		if(txtImage != null) {
			txtImage.onChange = function(e) { character.imageFile = txtImage.text; };
		}

		var btnReloadImage = uiRoot.findComponent("btnReloadImage", Button);
		var btnReloadChar = uiRoot.findComponent("btnReloadChar", Button);
		var reloadFunc = function(e) { addCharacter(true); };
		if(btnReloadImage != null) btnReloadImage.onClick = reloadFunc;
		if(btnReloadChar != null) btnReloadChar.onClick = reloadFunc;

		var txtHealthIcon = uiRoot.findComponent("txtHealthIcon", TextField);
		if(txtHealthIcon != null) {
			txtHealthIcon.onChange = function(e) {
				character.healthIcon = txtHealthIcon.text;
				updateHealthBar();
				updateUIIconScale();
			};
		}

		var iconContainer = uiRoot.findComponent("iconContainer", Component);
		if(iconContainer != null) {
			iconContainer.onClick = function(e) {
				iconBrowseFile = new FileReference();
				iconBrowseFile.addEventListener(Event.SELECT, function(evt:Event) {
					var rawName = iconBrowseFile.name;
					if(rawName.endsWith(".png")) {
						var iconName = rawName.substr(0, rawName.length - 4);
						if(iconName.startsWith("icon-")) iconName = iconName.substr(5);
						
						if(txtHealthIcon != null) txtHealthIcon.text = iconName;
						character.healthIcon = iconName;
						updateHealthBar();
						updateUIIconScale();
						showNotif('Icon selected: ' + iconName);
					}
				});
				iconBrowseFile.browse([new FileFilter("PNG Image", "*.png")]);
			};
		}

		var panelColor = uiRoot.findComponent("colorPickerPanel", VBox);
		var btnGetIconColor = uiRoot.findComponent("btnGetIconColor", Button);
		var btnApplyColor = uiRoot.findComponent("btnApplyColor", Button);
		var btnCancelColor = uiRoot.findComponent("btnCancelColor", Button);

		if(btnGetIconColor != null && panelColor != null) {
			btnGetIconColor.onClick = function(e) {
				panelColor.hidden = false;
				panelColor.left = FlxG.mouse.screenX - 50;
				panelColor.top = FlxG.mouse.screenY - 50;
				colorWheel.visible = true;
				isSelectingColor = true;
			};
		}

		if(btnCancelColor != null && panelColor != null) {
			btnCancelColor.onClick = function(e) {
				panelColor.hidden = true;
				colorWheel.visible = false;
				isSelectingColor = false;
			};
		}

		if(btnApplyColor != null && panelColor != null) {
			btnApplyColor.onClick = function(e) {
				character.healthColorArray = [tempColor.red, tempColor.green, tempColor.blue];
				updateHealthBar();
				panelColor.hidden = true;
				colorWheel.visible = false;
				isSelectingColor = false;
				showNotif('Health Color Applied!');
			};
		}

		var chkVsliceSustains = uiRoot.findComponent("chkVsliceSustains", CheckBox);
		if(chkVsliceSustains != null) {
			chkVsliceSustains.onChange = function(e) { character.vSliceSustains = chkVsliceSustains.selected; };
		}

		var sldSingDuration = uiRoot.findComponent("sldSingDuration", Slider);
		if(sldSingDuration != null) {
			sldSingDuration.onChange = function(e) { character.singDuration = sldSingDuration.pos; };
		}

		var txtGameoverChar = uiRoot.findComponent("txtGameoverChar", TextField);
		if(txtGameoverChar != null) {
			txtGameoverChar.onChange = function(e) { character.gameoverCharacter = txtGameoverChar.text; };
		}

		var txtGameoverInit = uiRoot.findComponent("txtGameoverInit", TextField);
		if(txtGameoverInit != null) {
			txtGameoverInit.onChange = function(e) { character.gameoverInitialDeathSound = txtGameoverInit.text; };
		}

		var txtGameoverLoop = uiRoot.findComponent("txtGameoverLoop", TextField);
		if(txtGameoverLoop != null) {
			txtGameoverLoop.onChange = function(e) { character.gameoverLoopDeathSound = txtGameoverLoop.text; };
		}

		var txtGameoverConfirm = uiRoot.findComponent("txtGameoverConfirm", TextField);
		if(txtGameoverConfirm != null) {
			txtGameoverConfirm.onChange = function(e) { character.gameoverConfirmDeathSound = txtGameoverConfirm.text; };
		}

		var txtVocals = uiRoot.findComponent("txtVocals", TextField);
		if(txtVocals != null) {
			txtVocals.onChange = function(e) { character.vocalsFile = txtVocals.text; };
		}

		var chkFlipX = uiRoot.findComponent("chkFlipX", CheckBox);
		if(chkFlipX != null) {
			chkFlipX.onChange = function(e) {
				character.originalFlipX = chkFlipX.selected;
				character.flipX = (character.originalFlipX != character.isPlayer);
			};
		}

		var chkNoAntialiasing = uiRoot.findComponent("chkNoAntialiasing", CheckBox);
		if(chkNoAntialiasing != null) {
			chkNoAntialiasing.onChange = function(e) {
				character.noAntialiasing = chkNoAntialiasing.selected;
				character.antialiasing = !character.noAntialiasing;
			};
		}

		var txtScale = uiRoot.findComponent("txtScale", TextField);
		if(txtScale != null) {
			txtScale.onChange = function(e) {
				var val = Std.parseFloat(txtScale.text);
				if(!Math.isNaN(val) && val > 0) {
					character.jsonScale = val;
					character.scale.set(val, val);
					character.updateHitbox();
				}
			};
		}

		if (listAnimations != null) {
			listAnimations.onChange = function(e) {
				if(listAnimations.selectedIndex >= 0 && listAnimations.selectedIndex < anims.length) {
					ghost.visible = false;
					curAnim = listAnimations.selectedIndex;
					var curAnimData = anims[curAnim];
					try {
						character.playAnim(curAnimData.anim, true);
						if(character.animation.curAnim != null) {
							character.animation.curAnim.flipX = (curAnimData.flipX == true);
							character.animation.curAnim.flipY = (curAnimData.flipY == true);
						}
					} catch(e:Dynamic) {}
					updateAnimInputsFromList();
				}
			}
		}

		var chkAnimFlipX = uiRoot.findComponent("chkAnimFlipX", CheckBox);
		if(chkAnimFlipX != null) {
			chkAnimFlipX.onChange = function(e) {
				if(anims != null && anims[curAnim] != null) {
					anims[curAnim].flipX = chkAnimFlipX.selected;
					if(character.animation.curAnim != null) character.animation.curAnim.flipX = chkAnimFlipX.selected;
				}
			};
		}

		var chkAnimFlipY = uiRoot.findComponent("chkAnimFlipY", CheckBox);
		if(chkAnimFlipY != null) {
			chkAnimFlipY.onChange = function(e) {
				if(anims != null && anims[curAnim] != null) {
					anims[curAnim].flipY = chkAnimFlipY.selected;
					if(character.animation.curAnim != null) character.animation.curAnim.flipY = chkAnimFlipY.selected;
				}
			};
		}

		var chkAnimLoop = uiRoot.findComponent("chkAnimLoop", CheckBox);
		if(chkAnimLoop != null) {
			chkAnimLoop.onChange = function(e) {
				if(anims != null && anims[curAnim] != null) {
					anims[curAnim].loop = chkAnimLoop.selected;
					if(character.animation.curAnim != null) character.animation.curAnim.looped = chkAnimLoop.selected;
				}
			};
		}

		var btnAddAnim = uiRoot.findComponent("btnAddAnim", Button);
		if(btnAddAnim != null) {
			btnAddAnim.onClick = function(e) {
				var txtAnim = uiRoot.findComponent("txtAnim", TextField);
				var txtAnimName = uiRoot.findComponent("txtAnimName", TextField);
				var txtIndices = uiRoot.findComponent("txtIndices", TextField);
				
				if(txtAnim == null || txtAnim.text.trim() == "" || txtAnimName == null || txtAnimName.text.trim() == "") {
					showNotif("Anim Name and Symbol cannot be empty!", FlxColor.RED);
					return;
				}

				var indicesArray:Array<Int> = [];
				if(txtIndices != null && txtIndices.text.trim() != "") {
					var splitStr = txtIndices.text.split(",");
					for(s in splitStr) {
						var i = Std.parseInt(s.trim());
						if(i != null) indicesArray.push(i);
					}
				}

				var exists:Bool = false;
				var newAnimData:Dynamic = {
					anim: txtAnim.text,
					name: txtAnimName.text,
					fps: 24,
					loop: (chkAnimLoop != null ? chkAnimLoop.selected : false),
					indices: (indicesArray.length > 0 ? indicesArray : []),
					offsets: [0, 0],
					flipX: (chkAnimFlipX != null ? chkAnimFlipX.selected : false),
					flipY: (chkAnimFlipY != null ? chkAnimFlipY.selected : false)
				};
				for(i in 0...character.animationsArray.length) {
					if(character.animationsArray[i].anim == txtAnim.text) {
						newAnimData.offsets = character.animationsArray[i].offsets;
						character.animationsArray[i] = newAnimData;
						exists = true;
						break;
					}
				}

				if(!exists) character.animationsArray.push(newAnimData);
				if(indicesArray.length > 0)
					character.animation.addByIndices(newAnimData.anim, newAnimData.name, indicesArray, "", 24, newAnimData.loop);
				else
					character.animation.addByPrefix(newAnimData.anim, newAnimData.name, 24, newAnimData.loop);
				
				character.addOffset(newAnimData.anim, newAnimData.offsets[0], newAnimData.offsets[1]);
				reloadAnimList();
				showNotif("Animation Added/Updated!");
			};
		}

		var btnDeleteAnim = uiRoot.findComponent("btnDeleteAnim", Button);
		if(btnDeleteAnim != null) {
			btnDeleteAnim.onClick = function(e) {
				if(anims != null && anims.length > 0) {
					var nameToRemove = anims[curAnim].anim;
					character.animationsArray.remove(anims[curAnim]);
					if(character.animOffsets.exists(nameToRemove)) character.animOffsets.remove(nameToRemove);
					reloadAnimList();
					showNotif("Animation Deleted!");
				}
			};
		}

		var btnMakeGhost = uiRoot.findComponent("btnMakeGhost", Button);
		if(btnMakeGhost != null) {
			btnMakeGhost.onClick = function(e) {
				if(anims != null && anims.length > 0 && !character.isAnimationNull()) {
					var myAnim = anims[curAnim];
					ghost.loadGraphic(character.graphic);
					ghost.frames.frames = character.frames.frames;
					ghost.animation.copyFrom(character.animation);
					ghost.animation.play(character.animation.curAnim.name, true, false, character.animation.curAnim.curFrame);
					ghost.animation.pause();
					
					ghost.setPosition(character.x, character.y);
					ghost.antialiasing = character.antialiasing;
					ghost.flipX = character.flipX;
					ghost.alpha = ghostAlpha;
					ghost.scale.set(character.scale.x, character.scale.y);
					ghost.updateHitbox();
					ghost.offset.set(character.offset.x, character.offset.y);
					ghost.visible = true;
					showNotif('Ghost Created!');
				}
			};
		}

		var sldGhostAlpha = uiRoot.findComponent("sldGhostAlpha", Slider);
		if(sldGhostAlpha != null) {
			sldGhostAlpha.onChange = function(e) {
				ghostAlpha = sldGhostAlpha.pos;
				ghost.alpha = ghostAlpha;
			};
		}

		var btnSaveCharacter = uiRoot.findComponent("btnSaveCharacter", Button);
		if(btnSaveCharacter != null) {
			btnSaveCharacter.onClick = function(e) { saveCharacter(); };
		}
	}

	function updateAnimInputsFromList() {
		if (uiRoot == null || anims == null || anims[curAnim] == null) return;
		var anim = anims[curAnim];
		
		var txtAnim = uiRoot.findComponent("txtAnim", TextField);
		var txtAnimName = uiRoot.findComponent("txtAnimName", TextField);
		var chkAnimLoop = uiRoot.findComponent("chkAnimLoop", CheckBox);
		var chkAnimFlipX = uiRoot.findComponent("chkAnimFlipX", CheckBox);
		var chkAnimFlipY = uiRoot.findComponent("chkAnimFlipY", CheckBox);
		var txtIndices = uiRoot.findComponent("txtIndices", TextField);
		if(txtAnim != null) txtAnim.text = anim.anim;
		if(txtAnimName != null) txtAnimName.text = anim.name;
		if(chkAnimLoop != null) chkAnimLoop.selected = (anim.loop == true);
		if(chkAnimFlipX != null) chkAnimFlipX.selected = (anim.flipX == true);
		if(chkAnimFlipY != null) chkAnimFlipY.selected = (anim.flipY == true);
		if(txtIndices != null) {
			if(anim.indices != null && anim.indices.length > 0) {
				var indicesStr:String = anim.indices.toString();
				txtIndices.text = indicesStr.substr(1, indicesStr.length - 2);
			} else {
				txtIndices.text = "";
			}
		}
	}

	var ghostAlpha:Float = 0.6;

	inline function anyInputFocused():Bool
	{
		return FocusManager.instance.focus != null && Std.isOfType(FocusManager.instance.focus, TextField);
	}

	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	var holdingFrameTime:Float = 0;
	var holdingFrameElapsed:Float = 0;
	
	override function update(elapsed:Float)
	{
		if(dragTarget != null) {
			dragTarget.left = FlxG.mouse.screenX - dragOffsetX;
			dragTarget.top = FlxG.mouse.screenY - dragOffsetY;
		}

		var winSettings = uiRoot.findComponent("windowSettings", VBox);
		if(winSettings != null && uiIcon != null) {
			uiIcon.x = winSettings.left + 155;
			uiIcon.y = winSettings.top + 260; 
		}

		var uiBox = uiRoot.findComponent("uiBox", TabView);
		if (uiBox != null && uiIcon != null) {
			uiIcon.visible = (uiBox.pageIndex == 0);
		}

		if(isSelectingColor) {
			var panelColor = uiRoot.findComponent("colorPickerPanel", VBox);
			var previewBox = uiRoot.findComponent("colorPreview", Component);
			
			if (panelColor != null) {
				colorWheel.x = panelColor.left + (panelColor.width - colorWheel.width) / 2;
				colorWheel.y = panelColor.top + 35;
			}

			if(FlxG.mouse.justPressed) {
				var mx = FlxG.mouse.screenX - colorWheel.x;
				var my = FlxG.mouse.screenY - colorWheel.y;
				if(mx >= 0 && mx < colorWheel.width && my >= 0 && my < colorWheel.height) {
					var localX = mx / colorWheel.scale.x;
					var localY = my / colorWheel.scale.y;
					
					var color:FlxColor = colorWheel.pixels.getPixel32(Std.int(localX), Std.int(localY));
					if(color.alpha > 0) {
						tempColor = color;
						if (previewBox != null) {
							previewBox.styleString = "background-color: #" + StringTools.hex(tempColor.to24Bit(), 6) + "; border: 1px solid #777777;";
						}
					}
				}
			}
		}

		super.update(elapsed);

		if(notifText.visible)
		{
			notifTimer -= elapsed;
			if(notifTimer <= 0) notifText.visible = false;
		}

		if(anyInputFocused() || isSelectingColor)
		{
			ClientPrefs.toggleVolumeKeys(false);
			return;
		}
		ClientPrefs.toggleVolumeKeys(true);

		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		var shiftMultBig:Float = 1;
		if(FlxG.keys.pressed.SHIFT) { 
			shiftMult = 4;
			shiftMultBig = 10; 
		}
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		if(FlxG.keys.pressed.J) FlxG.camera.scroll.x -= elapsed * 500 * shiftMult * ctrlMult;
		if(FlxG.keys.pressed.K) FlxG.camera.scroll.y += elapsed * 500 * shiftMult * ctrlMult;
		if(FlxG.keys.pressed.L) FlxG.camera.scroll.x += elapsed * 500 * shiftMult * ctrlMult;
		if(FlxG.keys.pressed.I) FlxG.camera.scroll.y -= elapsed * 500 * shiftMult * ctrlMult;

		var lastZoom = FlxG.camera.zoom;
		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) FlxG.camera.zoom = 1;
		else if(FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
			FlxG.camera.zoom += elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
		} else if(FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
			FlxG.camera.zoom -= elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
		}
		if(lastZoom != FlxG.camera.zoom)
			cameraZoomText.text = 'Camera Zoom: ' + FlxMath.roundDecimal(FlxG.camera.zoom, 2) + 'x';
		var changedAnim:Bool = false;
		if(anims != null && anims.length > 1)
		{
			if(FlxG.keys.justPressed.W && (changedAnim = true)) curAnim--;
			else if(FlxG.keys.justPressed.S && (changedAnim = true)) curAnim++;
			if(changedAnim)
			{
				ghost.visible = false;
				curAnim = FlxMath.wrap(curAnim, 0, anims.length - 1);
				var curAnimData = anims[curAnim];
				try {
					character.playAnim(curAnimData.anim, true);
					if(character.animation.curAnim != null) {
						character.animation.curAnim.flipX = (curAnimData.flipX == true);
						character.animation.curAnim.flipY = (curAnimData.flipY == true);
					}
				} catch(e:Dynamic) {}
				
				if(listAnimations != null) listAnimations.selectedIndex = curAnim;
			}
		}

		var changedOffset = false;
		var moveKeysP = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];
		var moveKeys = [FlxG.keys.pressed.LEFT, FlxG.keys.pressed.RIGHT, FlxG.keys.pressed.UP, FlxG.keys.pressed.DOWN];
		if(moveKeysP.contains(true)) {
			character.offset.x += ((moveKeysP[0] ? 1 : 0) - (moveKeysP[1] ? 1 : 0)) * shiftMultBig;
			character.offset.y += ((moveKeysP[2] ? 1 : 0) - (moveKeysP[3] ? 1 : 0)) * shiftMultBig;
			changedOffset = true;
		}

		if(moveKeys.contains(true)) {
			holdingArrowsTime += elapsed;
			if(holdingArrowsTime > 0.6) {
				holdingArrowsElapsed += elapsed;
				while(holdingArrowsElapsed > (1 / 60)) {
					character.offset.x += ((moveKeys[0] ? 1 : 0) - (moveKeys[1] ? 1 : 0)) * shiftMultBig;
					character.offset.y += ((moveKeys[2] ? 1 : 0) - (moveKeys[3] ? 1 : 0)) * shiftMultBig;
					holdingArrowsElapsed -= (1 / 60);
					changedOffset = true;
				}
			}
		} else holdingArrowsTime = 0;

		if(FlxG.mouse.pressedRight && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0)) {
			character.offset.x -= FlxG.mouse.deltaScreenX;
			character.offset.y -= FlxG.mouse.deltaScreenY;
			changedOffset = true;
		}

		if(FlxG.keys.pressed.CONTROL) {
			if(FlxG.keys.justPressed.C) {
				copiedOffset[0] = character.offset.x;
				copiedOffset[1] = character.offset.y;
				showNotif('Copied offset: [' + Std.int(copiedOffset[0]) + ', ' + Std.int(copiedOffset[1]) + ']');
			} else if(FlxG.keys.justPressed.V) {
				pushUndo(character.offset.x, character.offset.y);
				character.offset.x = copiedOffset[0];
				character.offset.y = copiedOffset[1];
				changedOffset = true;
				showNotif('Pasted Offset');
			} else if(FlxG.keys.justPressed.R) {
				pushUndo(character.offset.x, character.offset.y);
				character.offset.set(0, 0);
				changedOffset = true;
				showNotif('Reset Offset');
			} else if(FlxG.keys.justPressed.Z && undoStack.length > 0) {
				var top = undoStack.pop();
				pushRedo(character.offset.x, character.offset.y);
				character.offset.x = top[0];
				character.offset.y = top[1];
				changedOffset = true;
				showNotif('Undo');
			} else if(FlxG.keys.justPressed.Y && redoStack.length > 0) {
				var top = redoStack.pop();
				pushUndo(character.offset.x, character.offset.y);
				character.offset.x = top[0];
				character.offset.y = top[1];
				changedOffset = true;
				showNotif('Redo');
			}
		}

		var anim = anims != null ? anims[curAnim] : null;
		if(changedOffset && anim != null && anim.offsets != null) {
			anim.offsets[0] = Std.int(character.offset.x);
			anim.offsets[1] = Std.int(character.offset.y);
			if (listAnimations != null && listAnimations.dataSource != null) {
				var item = listAnimations.dataSource.get(curAnim);
				if (item != null) {
					item.text = anim.anim + ": " + anim.offsets;
					listAnimations.dataSource.update(curAnim, item);
				}
			}
			character.addOffset(anim.anim, character.offset.x, character.offset.y);
		}

		var txt = 'ERROR: No Animation Found';
		var clr = FlxColor.RED;
		if(character != null && !character.isAnimationNull()) {
			if(FlxG.keys.pressed.A || FlxG.keys.pressed.D) {
				holdingFrameTime += elapsed;
				if(holdingFrameTime > 0.5) holdingFrameElapsed += elapsed;
			} else holdingFrameTime = 0;

			if(FlxG.keys.justPressed.SPACE) {
				character.playAnim(character.getAnimationName(), true);
				if(character.animation.curAnim != null && anim != null) {
					character.animation.curAnim.flipX = (anim.flipX == true);
					character.animation.curAnim.flipY = (anim.flipY == true);
				}
			}

			var frames:Int = character.animation.curAnim != null ? character.animation.curAnim.curFrame : 0;
			var length:Int = character.animation.curAnim != null ? character.animation.curAnim.numFrames : 0;
			if(FlxG.keys.justPressed.A || FlxG.keys.justPressed.D || holdingFrameTime > 0.5) {
				var isLeft = (holdingFrameTime > 0.5 && FlxG.keys.pressed.A) || FlxG.keys.justPressed.A;
				character.animPaused = true;
				if(holdingFrameTime <= 0.5 || holdingFrameElapsed > 0.1) {
					frames = FlxMath.wrap(frames + Std.int(isLeft ? -shiftMult : shiftMult), 0, length > 0 ? length - 1 : 0);
					if(character.animation.curAnim != null) character.animation.curAnim.curFrame = frames;
					holdingFrameElapsed -= 0.1;
				}
			}
			txt = 'Animation Frames: ($frames / ${length > 0 ? length - 1 : 0})';
			clr = FlxColor.WHITE;
		}
		if(txt != frameAdvanceText.text) frameAdvanceText.text = txt;
		frameAdvanceText.color = clr;

		if(FlxG.keys.justPressed.F12) silhouettes.visible = !silhouettes.visible;
		if(FlxG.keys.justPressed.ESCAPE) {
			FlxG.mouse.visible = false;
			if (_goToPlayState) {
				MusicBeatState.switchState(new PlayState());
			} else {
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}
	}

	inline function pushUndo(x:Float, y:Float) {
		undoStack.push([x, y]);
		if(undoStack.length > MAX_UNDO) undoStack.shift();
		redoStack = [];
	}

	inline function pushRedo(x:Float, y:Float) {
		redoStack.push([x, y]);
		if(redoStack.length > MAX_UNDO) redoStack.shift();
	}

	final assetFolder = 'week1';
	inline function loadBG() {
		var lastLoaded = Paths.currentLevel;
		Paths.currentLevel = assetFolder;
		var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
		add(bg);
		var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		add(stageFront);
		dadPosition.set(100, 100);
		bfPosition.set(770, 100);
		Paths.currentLevel = lastLoaded;
	}

	inline function updatePointerPos(?snap:Bool = true) {
		if(character == null) return;
		var offX = !character.isPlayer ?
		character.getMidpoint().x + 150 + character.cameraPosition[0] : character.getMidpoint().x - 100 - character.cameraPosition[0];
		var offY = character.getMidpoint().y - 100 + character.cameraPosition[1];
		cameraFollowPointer.setPosition(offX, offY);
		if(snap) {
			FlxG.camera.scroll.x = cameraFollowPointer.getMidpoint().x - FlxG.width / 2;
			FlxG.camera.scroll.y = cameraFollowPointer.getMidpoint().y - FlxG.height / 2;
		}
	}

	inline function updateHealthBar() {
		if (healthBar != null && healthIcon != null && character != null) {
			healthBar.leftBar.color = healthBar.rightBar.color = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
			healthIcon.changeIcon(character.healthIcon, false);
		}
	}

	inline function reloadAnimList() {
		anims = character.animationsArray;
		if(anims != null && anims.length > 0) {
			try {
				character.playAnim(anims[0].anim, true);
				if(character.animation.curAnim != null) {
					character.animation.curAnim.flipX = (anims[0].flipX == true);
					character.animation.curAnim.flipY = (anims[0].flipY == true);
				}
			} catch(e:Dynamic) {}
		}
		curAnim = 0;
		if (listAnimations != null) {
			if (listAnimations.dataSource == null) listAnimations.dataSource = new haxe.ui.data.ArrayDataSource<Dynamic>();
			listAnimations.dataSource.clear();
			if(anims != null) {
				for(anim in anims) listAnimations.dataSource.add({ text: anim.anim + ": " + anim.offsets });
			}
			listAnimations.selectedIndex = curAnim;
		}
		updateAnimInputsFromList();
	}

	inline function updateCharacterPositions() {
		if(character == null) return;
		character.setPosition(!character.isPlayer ? dadPosition.x : bfPosition.x, !character.isPlayer ? dadPosition.y : bfPosition.y);
		character.x += character.positionArray[0];
		character.y += character.positionArray[1];
	}

	inline function predictCharacterIsNotPlayer(name:String) {
		return (name != 'bf' && !name.startsWith('bf-') && !name.endsWith('-player') && !name.endsWith('-dead')) || name.endsWith('-opponent') ||
		name.startsWith('gf-') || name.endsWith('-gf') || name == 'gf';
	}

	var characterList:Array<String> = [];
	function reloadCharacterDropDown() {
		characterList = Mods.mergeAllTextsNamed('data/characterList.txt', Paths.getSharedPath());
		#if sys
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'characters/');
		for(folder in foldersToCheck) {
			if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) continue;
			for(file in FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json')) {
					var charToCheck = file.substr(0, file.length - 5);
					if(!characterList.contains(charToCheck)) characterList.push(charToCheck);
				}
		}
		#end
		if(characterList.length < 1) characterList.push('');
		if (uiRoot != null) {
			var dropCharacter = uiRoot.findComponent("dropCharacter", DropDown);
			if (dropCharacter != null) {
				dropCharacter.dataSource = new haxe.ui.data.ArrayDataSource<Dynamic>();
				var selectedIndex = 0;
				for (i in 0...characterList.length) {
					dropCharacter.dataSource.add({ text: characterList[i] });
					if (characterList[i] == _char) selectedIndex = i;
				}
				dropCharacter.selectedIndex = selectedIndex;
			}
		}
	}

	var _file:FileReference;
	function saveCharacter() {
		if(_file != null) return;
		var json:Dynamic = {
			"animations": character.animationsArray,
			"image": character.imageFile,
			"scale": character.jsonScale,
			"sing_duration": character.singDuration,
			"healthicon": character.healthIcon,
			"position": character.positionArray,
			"camera_position": character.cameraPosition,
			"flip_x": character.originalFlipX,
			"no_antialiasing": character.noAntialiasing,
			"healthbar_colors": character.healthColorArray,
			"vocals_file": character.vocalsFile,
			"_editor_isPlayer": character.isPlayer,
			"dance_every": character.danceEveryNumBeats,
			"scalableOffsets": character.scalableOffsets,
			
			"vslice_sustains": character.vSliceSustains,
			"gameover_character": character.gameoverCharacter,
			"gameover_initial_sound": character.gameoverInitialDeathSound,
			"gameover_loop_sound": character.gameoverLoopDeathSound,
			"gameover_confirm_sound": character.gameoverConfirmDeathSound
		};
		var data = haxe.Json.stringify(json, "\t");
		if(data.length > 0) {
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, function(e) { _file = null; showNotif('Character Saved!'); });
			_file.save(data, '$_char.json');
		}
	}

	function showNotif(msg:String, ?color:FlxColor) {
		notifText.text = msg;
		notifText.color = color != null ? color : FlxColor.LIME;
		notifText.visible = true;
		notifTimer = 2.5;
	}

	function addHelpScreen() {
		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.75;
		helpBg.cameras = [camHUD];
		helpBg.active = helpBg.visible = false;
		add(helpBg);
		helpTexts = new FlxSpriteGroup();
		helpTexts.cameras = [camHUD];
		add(helpTexts);
		helpTexts.active = helpTexts.visible = false;
	}
}