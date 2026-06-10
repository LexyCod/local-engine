package objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.group.FlxSpriteGroup;

class MinimalTimeBar extends FlxSpriteGroup
{
    var topBG:FlxSprite;
    var topProgress:FlxSprite;
    var hudCamera:FlxCamera;

    public function new()
    {
        super();
        
        hudCamera = new FlxCamera();
        hudCamera.bgColor = 0x0;
        FlxG.cameras.add(hudCamera, false);

        topBG = new FlxSprite(0, 0).makeGraphic(FlxG.width, 11, 0xFF000000);
        topBG.alpha = 0.4;
        add(topBG);

        topProgress = new FlxSprite(0, 0).makeGraphic(1, 11, 0xFFFFFFFF);
        topProgress.origin.set(0, 0);
        add(topProgress);

        this.cameras = [hudCamera];
        
        if(backend.ClientPrefs.data.downScroll) {
            y = FlxG.height - 11;
        }
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if(FlxG.sound.music != null && FlxG.sound.music.playing)
        {
            var ratio:Float = FlxG.sound.music.time / FlxG.sound.music.length;
            if (ratio < 0) ratio = 0;
            if (ratio > 1) ratio = 1;
            
            topProgress.scale.x = FlxMath.lerp(topProgress.scale.x, FlxG.width * ratio, 0.15);
            topProgress.updateHitbox();
        }
    }
}