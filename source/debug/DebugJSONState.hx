package debug;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import backend.Paths;
import backend.Song;
import backend.Difficulty;
import states.PlayState;
import sys.FileSystem;

#if (debug || dev)
class DebugJSONState extends FlxState
{
    var songs:Array<String> = [];
    var difficulties:Array<String> = [];
    
    var grpSongs:FlxTypedGroup<FlxText>;
    var grpDiffs:FlxTypedGroup<FlxText>;
    
    var curSelected:Int = 0;
    var curDiff:Int = 0;
    var selectingDiff:Bool = false;

    var bg:FlxSprite;
    var sideBG:FlxSprite;
    
    var intendedY:Float = 0;

    override function create()
    {
        songs = [];

        var path = "assets/songs/"; 
        if (FileSystem.exists(path)) {
            for (directory in FileSystem.readDirectory(path)) {
                if (FileSystem.isDirectory(path + directory)) songs.push(directory);
            }
        }

        #if MODS_ALLOWED
        var modPath = "mods/songs/";
        if (FileSystem.exists(modPath)) {
            for (directory in FileSystem.readDirectory(modPath)) {
                if (FileSystem.isDirectory(modPath + directory) && !songs.contains(directory)) {
                    songs.push(directory);
                }
            }
        }
        #end

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF050505);
        bg.alpha = 0.6;
        bg.scrollFactor.set(0, 0);
        add(bg);

        sideBG = new FlxSprite(FlxG.width * 0.7).makeGraphic(Std.int(FlxG.width * 0.3), FlxG.height, 0xFF000000);
        sideBG.alpha = 0.8;
        sideBG.visible = false;
        sideBG.scrollFactor.set(0, 0);
        add(sideBG);

        grpSongs = new FlxTypedGroup<FlxText>();
        add(grpSongs);

        grpDiffs = new FlxTypedGroup<FlxText>();
        add(grpDiffs);

        for (i in 0...songs.length) {
            var songText = new FlxText(50, 60 + (i * 35), 0, songs[i].toUpperCase() + ".JSON", 24);
            songText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT);
            songText.ID = i;
            grpSongs.add(songText);
        }

        changeSelection();
        super.create();
    }

    override function update(elapsed:Float)
    {
        var lerpVal:Float = FlxMath.bound(elapsed * 7.5, 0, 1);
        FlxG.camera.scroll.y = FlxMath.lerp(FlxG.camera.scroll.y, intendedY, lerpVal);

        if (FlxG.keys.justPressed.ESCAPE) {
            if (selectingDiff) {
                selectingDiff = false;
                sideBG.visible = false;
                grpDiffs.clear();
            } else {
                FlxG.camera.scroll.y = 0;
                FlxG.switchState(new states.MainMenuState());
            }
        }

        if (!selectingDiff) {
            if (FlxG.keys.justPressed.UP) changeSelection(-1);
            if (FlxG.keys.justPressed.DOWN) changeSelection(1);
            if (FlxG.keys.justPressed.ENTER) openDiffSelector();
        } else {
            if (FlxG.keys.justPressed.UP) changeDiff(-1);
            if (FlxG.keys.justPressed.DOWN) changeDiff(1);
            if (FlxG.keys.justPressed.ENTER) loadJsonSong();
        }

        super.update(elapsed);
    }

    function changeSelection(change:Int = 0)
    {
        curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);

        grpSongs.forEach(function(txt:FlxText) {
            txt.color = FlxColor.WHITE;
            txt.alpha = 0.6;
            
            if (txt.ID == curSelected) {
                txt.color = FlxColor.CYAN;
                txt.alpha = 1;
                intendedY = txt.y - (FlxG.height / 2) + (txt.height / 2);
            }
        });
    }

    function openDiffSelector()
    {
        selectingDiff = true;
        sideBG.visible = true;
        grpDiffs.clear();
        
        Difficulty.list = []; 
        Difficulty.loadFromWeek();
        difficulties = Difficulty.list;

        for (i in 0...difficulties.length) {
            var diffText = new FlxText(sideBG.x + 20, 100 + (i * 50), 0, difficulties[i].toUpperCase(), 28);
            diffText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT);
            diffText.scrollFactor.set(0, 0);
            diffText.ID = i;
            grpDiffs.add(diffText);
        }
        changeDiff();
    }

    function changeDiff(change:Int = 0)
    {
        curDiff = FlxMath.wrap(curDiff + change, 0, difficulties.length - 1);
        grpDiffs.forEach(function(txt:FlxText) {
            txt.color = (txt.ID == curDiff) ? FlxColor.YELLOW : FlxColor.WHITE;
        });
    }

    function loadJsonSong()
    {
        var songName:String = songs[curSelected];
        var difficultyName:String = difficulties[curDiff];
        
        try {
            PlayState.SONG = Song.loadFromJson(songName + '-' + difficultyName.toLowerCase(), songName.toLowerCase());
            PlayState.isStoryMode = false;
            PlayState.storyDifficulty = curDiff;

            trace('Loading song: ' + songName + ' on difficulty: ' + difficultyName);
            
            FlxG.camera.scroll.y = 0;
            LoadingState.loadAndSwitchState(new PlayState());
        } catch(e:Dynamic) {
            trace('Error loading JSON: ' + e);
            PlayState.SONG = Song.loadFromJson(songName.toLowerCase(), songName.toLowerCase());
            
            FlxG.camera.scroll.y = 0;
            LoadingState.loadAndSwitchState(new PlayState());
        }
    }
}
#end