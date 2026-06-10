package objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.group.FlxSpriteGroup;

class MinimalTimeBar extends FlxSpriteGroup
{
    var topBG:FlxSprite;
    var topProgress:FlxSprite;

    public function new()
    {
        super();

        topBG = new FlxSprite(0, 0).makeGraphic(FlxG.width, 8, 0xFF000000);
        topBG.alpha = 0.4;
        add(topBG);

        topProgress = new FlxSprite(0, 0).makeGraphic(1, 8, 0xFFFFFFFF);
        topProgress.origin.set(0, 0);
        add(topProgress);
        
        if(backend.ClientPrefs.data.downScroll) {
            y = FlxG.height - 11;
        }
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // Добавляем строгую проверку, что музыка загрузилась и её длина больше нуля
        if(FlxG.sound.music != null && FlxG.sound.music.playing && FlxG.sound.music.length > 0)
        {
            var ratio:Float = FlxG.sound.music.time / FlxG.sound.music.length;
            
            // Защита на случай непредвиденных NaN
            if (Math.isNaN(ratio)) ratio = 0;
            if (ratio < 0) ratio = 0;
            if (ratio > 1) ratio = 1;

            // Плавное изменение ширины полосы
            topProgress.scale.x = FlxMath.lerp(topProgress.scale.x, FlxG.width * ratio, 0.15);
            topProgress.updateHitbox();
        }
    }
}