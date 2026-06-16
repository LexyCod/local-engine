package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import sys.FileSystem;
import sys.io.File;
import sys.thread.Thread;
import sys.thread.Mutex;
import haxe.Json;
import states.TitleState;

using StringTools;

typedef FileEntry = {
    var path:String;
    var lastModified:Float;
}

class SplashScreen extends FlxState
{
    var TargetState:FlxState;
    var DirectoriesToScan:Array<String> = ["assets/shared/images", "assets/shared/sounds"];
    var FilesList:Array<String> = [];
    var ManifestPath:String = "manifest.json";
    
    var TotalFileCount:Int = 0;
    var LoadedFileCount:Int = 0;
    var LoadingComplete:Bool = false;
    var StateMutex:Mutex;

    var BackgroundSystem:FlxSprite;

	var engineLogo:FlxSprite;

    public function new()
    {
        super();
        TargetState = new TitleState();
        StateMutex = new Mutex();
    }

    override public function create()
    {
        super.create();
        
        BackgroundSystem = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        add(BackgroundSystem);

		FlxG.cameras.bgColor = FlxColor.BLACK;
		engineLogo = new FlxSprite(0, 0).loadGraphic("assets/exclude/local_Engine_logo_concept.png");
		engineLogo.screenCenter(); 
		engineLogo.alpha = 0; 
		engineLogo.antialiasing = backend.ClientPrefs.data.antialiasing;
		add(engineLogo);

		FlxTween.tween(engineLogo, {alpha: 1}, 1.0);

        InitializeAssets();
        
        TotalFileCount = FilesList.length;
        Thread.create(ExecuteCoreLoading);
    }

    function InitializeAssets()
    {
        if (FileSystem.exists(ManifestPath))
        {
            try {
                var content = File.getContent(ManifestPath);
                var manifest:Array<FileEntry> = Json.parse(content);
                var isUpToDate = true;

                for (entry in manifest)
                {
                    if (!FileSystem.exists(entry.path) || FileSystem.stat(entry.path).mtime.getTime() != entry.lastModified)
                    {
                        isUpToDate = false;
                        break;
                    }
                }

                if (isUpToDate)
				{
					for (entry in manifest) FilesList.push(entry.path);
					return;
				}
            } catch(e:Dynamic) {}
        }

        FilesList = [];
        ExecuteDirectoryScan(DirectoriesToScan);
        SaveManifest();
    }

    function SaveManifest()
    {
        var manifest:Array<FileEntry> = [];
        for (path in FilesList)
        {
            manifest.push({
                path: path,
                lastModified: FileSystem.stat(path).mtime.getTime()
            });
        }
        File.saveContent(ManifestPath, Json.stringify(manifest));
    }

    function ExecuteDirectoryScan(dirs:Array<String>)
    {
        for (dir in dirs)
        {
            if (FileSystem.exists(dir) && FileSystem.isDirectory(dir))
            {
                for (file in FileSystem.readDirectory(dir))
                {
                    var fullPath = dir + "/" + file;
                    if (FileSystem.isDirectory(fullPath))
                    {
                        ExecuteDirectoryScan([fullPath]);
                    }
                    else if (fullPath.endsWith(".png") || fullPath.endsWith(".ogg") || fullPath.endsWith(".json"))
                    {
                        FilesList.push(fullPath);
                    }
                }
            }
        }
    }

    function ExecuteCoreLoading()
    {
        for (file in FilesList)
        {
            if (file.endsWith(".png"))
            {
                var cleanPath = file.replace("assets/shared/images/", "").replace(".png", "");
                var graph = Paths.image(cleanPath);
                if (graph != null) {
                    graph.persist = true;
                    graph.destroyOnNoUse = false;
                }
            }
            else if (file.endsWith(".ogg"))
            {
                var cleanSoundPath = file.replace("assets/shared/sounds/", "").replace(".ogg", "");
                Paths.sound(cleanSoundPath);
            }

            StateMutex.acquire();
            LoadedFileCount++;
            StateMutex.release();
        }

        StateMutex.acquire();
        LoadingComplete = true;
        StateMutex.release();
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        StateMutex.acquire();
        var currentProgress:Int = LoadedFileCount;
        var isSystemDone:Bool = LoadingComplete;
        StateMutex.release();

        if (isSystemDone)
        {
			new FlxTimer().start(3.0, function(tmr:FlxTimer)
			{
				FlxTween.tween(engineLogo, {alpha: 0}, 0.5, {
					onComplete: function(twn:FlxTween) {
						FlxG.switchState(TargetState);
					}
				});
			});
        }
    }
}