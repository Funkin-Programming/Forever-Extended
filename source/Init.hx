package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import meta.CoolUtil;
import meta.InfoHud;
import meta.data.Highscore;
import meta.state.*;
import meta.state.charting.*;
import openfl.filters.BitmapFilter;
import openfl.filters.ColorMatrixFilter;

using StringTools;

enum abstract SettingType(Int) from Int to Int
{
	var Checkmark = 0;
	var Selector = 1;
	var Numeric = 2;
	var Offset = 3;
}

enum abstract ForceMode(String) from String to String
{
	var Forced = 'forced';
	var NotForced = 'not forced';
}

typedef SettingEntry =
{
	var defaultValue:Dynamic;
	var type:SettingType;
	var description:String;
	var forceMode:ForceMode;
	@:optional var options:Array<Dynamic>;
}

typedef FilterEntry =
{
	var filter:BitmapFilter;
	@:optional var onUpdate:Void->Void;
}

class Init extends FlxState
{
	public static var gameSettings:Map<String, SettingEntry> = [
		'Downscroll' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Whether to have the strumline vertically flipped in gameplay.',
			forceMode: NotForced
		},
		'Auto Pause' => {
			defaultValue: true,
			type: Checkmark,
			description: 'Pause the game when it loses focus.',
			forceMode: NotForced
		},
		'FPS Counter' => {
			defaultValue: true,
			type: Checkmark,
			description: 'Whether to display the FPS counter.',
			forceMode: NotForced
		},
		'Memory Counter' => {
			defaultValue: true,
			type: Checkmark,
			description: 'Whether to display approximately how much memory is being used.',
			forceMode: NotForced
		},
		'Debug Info' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Whether to display information like your game state.',
			forceMode: NotForced
		},
		'Reduced Movements' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Whether to reduce movements, like icons bouncing or beat zooms in gameplay.',
			forceMode: NotForced
		},
		'Stage Darkness' => {
			defaultValue: 0,
			type: Numeric,
			description: 'Darkens non-UI elements, useful if you find the characters and backgrounds distracting.',
			forceMode: NotForced,
			options: [0, 100]
		},
		'Display Accuracy' => {
			defaultValue: true,
			type: Checkmark,
			description: 'Whether to display your accuracy on screen.',
			forceMode: NotForced
		},
		'Disable Antialiasing' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Whether to disable anti-aliasing. Helps improve performance.',
			forceMode: NotForced
		},
		'No Camera Note Movement' => {
			defaultValue: false,
			type: Checkmark,
			description: 'When enabled, left and right notes no longer move the camera.',
			forceMode: NotForced
		},
		'Use Forever Chart Editor' => {
			defaultValue: false,
			type: Checkmark,
			description: 'When enabled, uses the custom Forever Engine chart editor.',
			forceMode: NotForced
		},
		'Disable Note Splashes' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Whether to disable note splashes in gameplay.',
			forceMode: NotForced
		},
		'Ghost Tapping' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Enables Ghost Tapping, allowing you to press inputs without missing.',
			forceMode: NotForced
		},
		'Centered Notefield' => {
			defaultValue: false,
			type: Checkmark,
			description: "Centers the notes and disables the opponent's notefield.",
			forceMode: NotForced
		},
		'Opaque Arrows' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Makes the strum arrows fully opaque.',
			forceMode: NotForced
		},
		'Opaque Holds' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Disables the hold trail cutoff effect.',
			forceMode: NotForced
		},
		'Fixed Judgements' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Fixes judgements to the camera instead of world space.',
			forceMode: NotForced
		},
		'Simply Judgements' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Displays only one judgement sprite at a time.',
			forceMode: NotForced
		},
		'Skip Text' => {
			defaultValue: 'freeplay only',
			type: Selector,
			description: 'Decides whether to skip cutscenes and dialogue in gameplay.',
			forceMode: NotForced,
			options: ['never', 'freeplay only', 'always']
		},
		'Filter' => {
			defaultValue: 'none',
			type: Selector,
			description: 'Choose a colorblindness filter.',
			forceMode: NotForced,
			options: ['none', 'Deuteranopia', 'Protanopia', 'Tritanopia']
		},
		'UI Skin' => {
			defaultValue: 'default',
			type: Selector,
			description: 'Choose a UI skin for judgements, combo, etc.',
			forceMode: NotForced,
			options: []
		},
		'Note Skin' => {
			defaultValue: 'default',
			type: Selector,
			description: 'Choose a note skin.',
			forceMode: NotForced,
			options: []
		},
		'Framerate Cap' => {
			defaultValue: #if mobile 60 #else 120 #end,
			type: Numeric,
			description: 'Define your maximum FPS.',
			forceMode: NotForced,
			options: [30, 360]
		},
		'Offset' => {
			defaultValue: 0,
			type: Offset,
			description: 'Audio sync offset in milliseconds.',
			forceMode: NotForced
		},
		'Custom Titlescreen' => {
			defaultValue: false,
			type: Checkmark,
			description: 'Enables the custom Forever Engine titlescreen. Requires restart.',
			forceMode: Forced
		},
	];

	public static var trueSettings:Map<String, Dynamic> = [];

	public static var gameControls:Map<String, Dynamic> = [
		'UP'     => [[FlxKey.UP, W], 2],
		'DOWN'   => [[FlxKey.DOWN, S], 1],
		'LEFT'   => [[FlxKey.LEFT, A], 0],
		'RIGHT'  => [[FlxKey.RIGHT, D], 3],
		'ACCEPT' => [[FlxKey.SPACE, Z, FlxKey.ENTER], 4],
		'BACK'   => [[FlxKey.BACKSPACE, X, FlxKey.ESCAPE], 5],
		'PAUSE'  => [[FlxKey.ENTER, P], 6],
		'RESET'  => [[R, null], 7],
	];

	public static var filters:Array<BitmapFilter> = [];

	public static var gameFilters:Map<String, FilterEntry> = [
		'Deuteranopia' => {
			filter: new ColorMatrixFilter([
				0.43,  0.72, -0.15, 0, 0,
				0.34,  0.57,  0.09, 0, 0,
				-0.02, 0.03,  1.00, 0, 0,
				0,     0,     0,    1, 0,
			])
		},
		'Protanopia' => {
			filter: new ColorMatrixFilter([
				0.20,  0.99, -0.19, 0, 0,
				0.16,  0.79,  0.04, 0, 0,
				0.01, -0.01,  1.00, 0, 0,
				0,     0,     0,    1, 0,
			])
		},
		'Tritanopia' => {
			filter: new ColorMatrixFilter([
				0.97,  0.11, -0.08, 0, 0,
				0.02,  0.82,  0.16, 0, 0,
				0.06,  0.88,  0.18, 0, 0,
				0,     0,     0,    1, 0,
			])
		},
	];

	override public function create():Void
	{
		super.create();

		FlxG.save.bind('foreverextended-options');
		Highscore.load();

		loadSettings();
		loadControls();
		applyStartupSettings();

		gotoTitleScreen();
	}

	private function applyStartupSettings():Void
	{
		FlxG.fixedTimestep = false;
		FlxG.mouse.useSystemCursor = true;
		FlxG.mouse.visible = false;
		FlxG.autoPause = getSetting('Auto Pause');

		#if !html5
		Main.updateFramerate(getSetting('Framerate Cap'));
		#end

		applyFilters();
	}

	private function gotoTitleScreen():Void
	{
		var state:FlxState = getSetting('Custom Titlescreen') ? new CustomTitlescreen() : new TitleState();
		Main.switchState(this, state);
	}

	public static function getSetting<T>(key:String):T
		return cast trueSettings.get(key);

	public static function setSetting(key:String, value:Dynamic):Void
	{
		trueSettings.set(key, value);
		saveSettings();
	}

	public static function loadSettings():Void
	{
		for (key => entry in gameSettings)
			trueSettings.set(key, entry.defaultValue);

		if (FlxG.save.data.settings != null)
		{
			var saved:Map<String, Dynamic> = FlxG.save.data.settings;
			for (key => value in saved)
			{
				var entry = gameSettings.get(key);
				if (entry != null && entry.forceMode != Forced)
					trueSettings.set(key, value);
			}
		}

		sanitizeSettings();
		resolveSkinnableOptions();
		saveSettings();
		updateAll();
	}

	static function sanitizeSettings():Void
	{
		var fpsVal = getSetting('Framerate Cap');
		if (!Std.isOfType(fpsVal, Int) || fpsVal < 30 || fpsVal > 360)
			trueSettings.set('Framerate Cap', #if mobile 60 #else 120 #end);

		var darknessVal = getSetting('Stage Darkness');
		if (!Std.isOfType(darknessVal, Int) || darknessVal < 0 || darknessVal > 100)
			trueSettings.set('Stage Darkness', 0);

		var offsetVal = getSetting('Offset');
		if (!Std.isOfType(offsetVal, Int))
			trueSettings.set('Offset', 0);
	}

	static function resolveSkinnableOptions():Void
	{
		var uiSkins:Array<String> = CoolUtil.returnAssetsLibrary('UI');
		gameSettings.get('UI Skin').options = uiSkins;
		if (!uiSkins.contains(getSetting('UI Skin')))
			trueSettings.set('UI Skin', 'default');

		var noteSkins:Array<String> = CoolUtil.returnAssetsLibrary('noteskins/notes');
		gameSettings.get('Note Skin').options = noteSkins;
		if (!noteSkins.contains(getSetting('Note Skin')))
			trueSettings.set('Note Skin', 'default');
	}

	public static function loadControls():Void
	{
		var saved = FlxG.save.data.gameControls;
		if (saved != null && Lambda.count(saved) == Lambda.count(gameControls))
			gameControls = saved;
		saveControls();
	}

	public static function saveSettings():Void
	{
		FlxG.save.data.settings = trueSettings;
		FlxG.save.flush();
	}

	public static function saveControls():Void
	{
		FlxG.save.data.gameControls = gameControls;
		FlxG.save.flush();
	}

	public static function applyFilters():Void
	{
		filters = [];

		var filterName:String = getSetting('Filter');
		var entry = gameFilters.get(filterName);
		if (entry != null)
		{
			if (entry.onUpdate != null)
				entry.onUpdate();
			filters.push(entry.filter);
		}

		FlxG.game.setFilters(filters);
	}

	public static function updateAll():Void
	{
		InfoHud.updateDisplayInfo(
			getSetting('FPS Counter'),
			getSetting('Debug Info'),
			getSetting('Memory Counter')
		);

		FlxG.autoPause = getSetting('Auto Pause');

		#if !html5
		Main.updateFramerate(getSetting('Framerate Cap'));
		#end

		applyFilters();
	}
}
