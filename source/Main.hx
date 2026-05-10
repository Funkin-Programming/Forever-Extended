package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.util.FlxColor;
import haxe.CallStack;
import haxe.CallStack.StackItem;
import haxe.io.Path;
import lime.app.Application;
import meta.*;
import meta.data.PlayerSettings;
import meta.data.dependency.Discord;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
#if desktop
import sys.io.Process;
#end
#if android
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
	public static inline final FRAMERATE_CAP:Int = 120;
	public static inline final FRAMERATE_MOBILE:Int = 60;
	public static inline final VERSION:String = '0.2.7.1';

	public static var framerate:Int = FRAMERATE_CAP;
	public static var mainClassState:Class<FlxState> = Init;
	public static var lastState:FlxState;
	public static var storageDirectory:String;
	public static var crashDirectory:String;

	public static var gameWeeks:Array<WeekData> = [
		{songs: ['Tutorial'], characters: ['gf'], color: FlxColor.fromRGB(129, 100, 223), name: 'Funky Beginnings'},
		{songs: ['Bopeebo', 'Fresh', 'Dadbattle'], characters: ['dad', 'dad', 'dad'], color: FlxColor.fromRGB(129, 100, 223), name: 'vs. DADDY DEAREST'},
		{songs: ['Spookeez', 'South', 'Monster'], characters: ['spooky', 'spooky', 'monster'], color: FlxColor.fromRGB(30, 45, 60), name: 'Spooky Month'},
		{songs: ['Pico', 'Philly-Nice', 'Blammed'], characters: ['pico', 'pico', 'pico'], color: FlxColor.fromRGB(111, 19, 60), name: 'vs. Pico'},
		{songs: ['Satin-Panties', 'High', 'Milf'], characters: ['mom', 'mom', 'mom'], color: FlxColor.fromRGB(203, 113, 170), name: 'MOMMY MUST MURDER'},
		{
			songs: ['Cocoa', 'Eggnog', 'Winter-Horrorland'],
			characters: ['parents-christmas', 'parents-christmas', 'monster-christmas'],
			color: FlxColor.fromRGB(141, 165, 206),
			name: 'RED SNOW'
		},
		{songs: ['Senpai', 'Roses', 'Thorns'], characters: ['senpai', 'senpai', 'spirit'], color: FlxColor.fromRGB(206, 106, 169), name: 'hating simulator ft. moawling'},
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
	}

	private function resolveStoragePaths():Void
	{
		#if android
		storageDirectory = LimeSystem.applicationStorageDirectory;
		#elseif ios
		storageDirectory = LimeSystem.applicationStorageDirectory;
		#else
		storageDirectory = Sys.getCwd();
		if (!storageDirectory.endsWith("/") && !storageDirectory.endsWith("\\"))
			storageDirectory += "/";
		#end
		crashDirectory = storageDirectory + "crash/";
	}

	private function registerErrorHandler():Void
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);

	private function resolveFramerate():Void
	{
		#if mobile
		framerate = FRAMERATE_MOBILE;
		#elseif html5
		framerate = FRAMERATE_MOBILE;
		#end
	}

	private function setupStage():Void
	{
		if (stage != null)
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
		}
	}

	private function mountGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		var ratioX:Float = stageWidth / GAME_WIDTH;
		var ratioY:Float = stageHeight / GAME_HEIGHT;
		var zoom:Float = Math.min(ratioX, ratioY);

		var gameWidth:Int = Math.ceil(stageWidth / zoom);
		var gameHeight:Int = Math.ceil(stageHeight / zoom);

		var game:FlxGame = new FlxGame(gameWidth, gameHeight, mainClassState, zoom, framerate, framerate, true);
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

	public static function updateFramerate(target:Int):Void
	{
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
		Assets.cache.clear("songs");
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
					errLines.push('$file (line $line)');
				default:
			}
		}

		errLines.push('');
		errLines.push('Uncaught Error: ${e.error}');
		errLines.push('Please report this error to: https://github.com/Funkin-Programming/Forever-Extended');

		var errMsg:String = errLines.join('\n');

		#if sys
		try
		{
			var dateNow:String = Date.now().toString();
			dateNow = StringTools.replace(dateNow, ' ', '_');
			dateNow = StringTools.replace(dateNow, ':', "'");

			var logPath:String = crashDirectory + 'FE_' + dateNow + '.txt';

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
				Application.current.window.alert(errMsg, 'Crash - Forever Engine $VERSION');
			#else
			Application.current.window.alert(errMsg, 'Crash - Forever Engine $VERSION');
			#end
		}
		catch (_)
		{
			Application.current.window.alert(errMsg, 'Crash - Forever Engine $VERSION');
		}
		#else
		Application.current.window.alert(errMsg, 'Crash - Forever Engine $VERSION');
		#end

		#if sys
		Sys.exit(1);
		#end
	}
}
