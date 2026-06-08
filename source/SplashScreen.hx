package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import states.TitleState;
// хули нет

using StringTools;

@:access(flixel.FlxGame)
class SplashScreen extends FlxState
{
	var engineLogo:FlxSprite;

	override public function create():Void
	{
		super.create();

		FlxG.cameras.bgColor = FlxColor.BLACK;
		engineLogo = new FlxSprite(0, 0).loadGraphic("assets/exclude/local_Engine_logo_concept.png");
		engineLogo.screenCenter(); 
		engineLogo.alpha = 0; 
		engineLogo.antialiasing = backend.ClientPrefs.data.antialiasing;
		add(engineLogo);

		FlxTween.tween(engineLogo, {alpha: 1}, 1.0);

		new FlxTimer().start(3.0, function(tmr:FlxTimer)
		{
			FlxTween.tween(engineLogo, {alpha: 0}, 0.5, {
				onComplete: function(twn:FlxTween) {
					FlxG.switchState(new TitleState());
				}
			});
		});
	}
}