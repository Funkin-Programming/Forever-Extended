package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import haxe.CallStack;
import haxe.CallStack.StackItem;
import lime.app.Application;
import meta.InfoHud;
import meta.data.PlayerSettings;
import meta.data.dependency.Discord;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.UncaughtErrorEvent;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
#if desktop
import sys.io.Process;
#end
#if (android || ios)
import lime.system.System as LimeSystem;
#end

typedef WeekData =
{
	var songs:Array<String>;
	var characters:Array<String>;
	var color:FlxColor;
	var name:String;
}

class Main extends Sprite
{
	public static inline final GAME_WIDTH:Int = 1280;
	public static inline final GAME_HEIGHT:Int = 720;
	public static inline final VERSION:String = '0.2.7.1';
	public static inline final REPO_URL:String = 'https://github.com/Funkin-Programming/Forever-Extended';

	public static inline final FRAMERATE_DEFAULT:Int = 120;
	public static inline final FRAMERATE_MOBILE:Int = 60;
	public static inline final FRAMERATE_MIN:Int = 30;
	public static inline final FRAMERATE_MAX:Int = 360;

	public static var framerate:Int = FRAMERATE_DEFAULT;
	public static var mainClassState:Class<FlxState> = Init;
	public static var lastState:FlxState;
	public static var storageDirectory:String = '';
	public static var crashDirectory:String = '';
	public static var initialized:Bool = false;

	public static var gameWeeks:Array<WeekData> = [
		{
			songs: ['Tutorial'],
			characters: ['gf'],
			color: FlxColor.fromRGB(129, 100, 223),
			name: 'Funky Beginnings'
		},
		{
			songs: ['Bopeebo', 'Fresh', 'Dadbattle'],
			characters: ['dad', 'dad', 'dad'],
			color: FlxColor.fromRGB(129, 100, 223),
			name: 'vs. DADDY DEAREST'
		},
		{
			songs: ['Spookeez', 'South', 'Monster'],
			characters: ['spooky', 'spooky', 'monster'],
			color: FlxColor.fromRGB(30, 45, 60),
			name: 'Spooky Month'
		},
		{
			songs: ['Pico', 'Philly-Nice', 'Blammed'],
			characters: ['pico', 'pico', 'pico'],
			color: FlxColor.fromRGB(111, 19, 60),
			name: 'vs. Pico'
		},
		{
			songs: ['Satin-Panties', 'High', 'Milf'],
			characters: ['mom', 'mom', 'mom'],
			color: FlxColor.fromRGB(203, 113, 170),
			name: 'MOMMY MUST MURDER'
		},
		{
			songs: ['Cocoa', 'Eggnog', 'Winter-Horrorland'],
			characters: ['parents-christmas', 'parents-christmas', 'monster-christmas'],
			color: FlxColor.fromRGB(141, 165, 206),
			name: 'RED SNOW'
		},
		{
			songs: ['Senpai', 'Roses', 'Thorns'],
			characters: ['senpai', 'senpai', 'spirit'],
			color: FlxColor.fromRGB(206, 106, 169),
			name: 'hating simulator ft. moawling'
		},
	];

	private var infoCounter:InfoHud;

	public static function main():Void
		Lib.current.addChild(new Main());

	public function new()
	{
		super();

		resolveStoragePaths();
		registerErrorHandler();
		resolveFramerate();
		setupStage();
		mountGame();
		bootSystems();

		initialized = true;
	}

	private function resolveStoragePaths():Void
	{
		#if (android || ios)
		storageDirectory = LimeSystem.applicationStorageDirectory;
		if (!storageDirectory.endsWith('/'))
			storageDirectory += '/';
		#elseif sys
		storageDirectory = Sys.getCwd();
		if (!storageDirectory.endsWith('/') && !storageDirectory.endsWith('\\'))
			storageDirectory += '/';
		#else
		storageDirectory = './';
		#end

		crashDirectory = storageDirectory + 'crash/';
	}

	private function registerErrorHandler():Void
	{
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
	}

	private function resolveFramerate():Void
	{
		#if (mobile || html5)
		framerate = FRAMERATE_MOBILE;
		#end
	}

	private function setupStage():Void
	{
		if (stage == null)
			return;

		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;

		#if mobile
		stage.quality = openfl.display.StageQuality.LOW;
		#end
	}

	private function mountGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		var ratioX:Float = stageWidth / GAME_WIDTH;
		var ratioY:Float = stageHeight / GAME_HEIGHT;
		var zoom:Float = Math.min(ratioX, ratioY);

		var scaledWidth:Int = Math.ceil(stageWidth / zoom);
		var scaledHeight:Int = Math.ceil(stageHeight / zoom);

		var game:FlxGame = new FlxGame(scaledWidth, scaledHeight, mainClassState, zoom, framerate, framerate, true);
		addChild(game);

		infoCounter = new InfoHud(10, 3, 0xFFFFFF, true);
		addChild(infoCounter);
	}

	private function bootSystems():Void
	{
		#if desktop
		Discord.initializeRPC();
		Discord.changePresence('');
		#end

		PlayerSettings.init();
	}

	public static function switchState(from:FlxState, to:FlxState):Void
	{
		lastState = from;
		mainClassState = Type.getClass(to);
		FlxG.switchState(to);
	}

	public static function resetState():Void
	{
		if (mainClassState != null)
			FlxG.resetState();
	}

	public static function updateFramerate(target:Int):Void
	{
		target = Std.int(Math.max(FRAMERATE_MIN, Math.min(FRAMERATE_MAX, target)));

		if (target == FlxG.updateFramerate)
			return;

		if (target > FlxG.updateFramerate)
		{
			FlxG.updateFramerate = target;
			FlxG.drawFramerate = target;
		}
		else
		{
			FlxG.drawFramerate = target;
			FlxG.updateFramerate = target;
		}

		framerate = target;
	}

	public static function framerateAdjust(input:Float):Float
		return input * (60.0 / FlxG.drawFramerate);

	public static function dumpCache():Void
	{
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null)
			{
				Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		Assets.cache.clear('songs');
		FlxG.sound.destroySounds();
	}

	public static function stopMusic():Void
	{
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
			FlxG.sound.music.stop();
	}

	public static function playMusic(key:String, volume:Float = 1.0, looped:Bool = true):Void
	{
		stopMusic();
		FlxG.sound.playMusic(Paths.music(key), volume, looped);
	}

	public static function playSound(key:String, volume:Float = 1.0, ?onComplete:Void->Void):FlxSound
	{
		return FlxG.sound.play(Paths.sound(key), volume, false, null, true, onComplete);
	}

	private function onCrash(e:UncaughtErrorEvent):Void
	{
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var errLines:Array<String> = [];

		for (item in callStack)
		{
			switch (item)
			{
				case FilePos(_, file, line, _):
					errLines.push('  $file (line $line)');
				default:
			}
		}

		var header:String = '=== Forever Extended $VERSION Crash Report ===';
		var footer:String = StringTools.lpad('', '=', header.length);

		errLines.unshift('');
		errLines.unshift(header);
		errLines.push('');
		errLines.push('Uncaught Error: ${e.error}');
		errLines.push('');
		errLines.push('Please report this at: $REPO_URL');
		errLines.push(footer);

		var errMsg:String = errLines.join('\n');

		#if sys
		try
		{
			var stamp:String = DateTools.format(Date.now(), '%Y-%m-%d_%H-%M-%S');
			var logPath:String = crashDirectory + 'FE_$stamp.txt';

			if (!FileSystem.exists(crashDirectory))
				FileSystem.createDirectory(crashDirectory);

			File.saveContent(logPath, errMsg + '\n');

			#if desktop
			var dialogPath:String = storageDirectory + 'FE-CrashDialog';
			#if windows
			dialogPath += '.exe';
			#end

			if (FileSystem.exists(dialogPath))
				new Process(dialogPath, [logPath]);
			else
				Application.current.window.alert(errMsg, 'Crash — Forever Extended $VERSION');
			#else
			Application.current.window.alert(errMsg, 'Crash — Forever Extended $VERSION');
			#end
		}
		catch (err:Dynamic)
		{
			Application.current.window.alert('$errMsg\n\n[Crash logger also failed: $err]', 'Crash — Forever Extended $VERSION');
		}
		#else
		Application.current.window.alert(errMsg, 'Crash — Forever Extended $VERSION');
		#end

		#if sys
		Sys.exit(1);
		#end
	}
}
