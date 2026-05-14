package objects;

import flixel.FlxSprite;
import objects.StrumNote;

class HoldNoteCover extends FlxSprite
{
    public var strumId:Int = 0;
    private var noteName:String = '';

    public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

    public function new(strum:StrumNote)
    {
        super(strum.x, strum.y);
        strumId = strum.ID;
        
        switch(strumId % 4) {
            case 0: noteName = 'left';
            case 1: noteName = 'down';
            case 2: noteName = 'up';
            case 3: noteName = 'right';
        }

        frames = Paths.getSparrowAtlas('noteHoldCovers');
        
        animation.addByPrefix('start', 'susCover_' + noteName + 'Start', 24, false);
        animation.addByPrefix('loop', 'susCover_sparks', 24, true);
        animation.addByPrefix('end', 'susCover_' + noteName + 'End', 24, false);

        addOffset('start', 75, 70);
        addOffset('loop', 75, 50);
        addOffset('end', 150, 100);
        
        antialiasing = ClientPrefs.data.antialiasing;
        
        playAnim('start');
    }

    public function addOffset(name:String, x:Float, y:Float) {
        animOffsets.set(name, [x, y]);
    }

    public function playAnim(anim:String, forced:Bool = false) {
        animation.play(anim, forced);

        var daOffset = animOffsets.get(anim);
        if (animOffsets.exists(anim)) {
            offset.set(daOffset[0], daOffset[1]);
        } else {
            offset.set(0, 0);
        }
        
        if(anim == 'end') animation.finishCallback = function(n) kill();
    }

    override function update(elapsed:Float) {
        if (animation.curAnim != null && animation.curAnim.name == 'start' && animation.curAnim.finished) {
            playAnim('loop');
        }
        super.update(elapsed);
    }
}