package;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import meta.CoolUtil;
import openfl.Assets as OpenFlAssets;
import openfl.utils.AssetType;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class Paths
{
	#if web
	public static inline final SOUND_EXT:String = "mp3";
	#else
	public static inline final SOUND_EXT:String = "ogg";
	#end

	public static inline final IMAGE_EXT:String = "png";
	public static inline final VIDEO_EXT:String = "mp4";

	static var currentLevel:String = "";
	static var pathCache:Map<String, String> = [];

	public static function setCurrentLevel(name:String):Void
	{
		currentLevel = name.toLowerCase();
		pathCache.clear();
	}

	public static function clearCache():Void
		pathCache.clear();

	static function resolve(file:String, type:AssetType, ?library:String):String
	{
		var cacheKey:String = '${library ?? ""}:$file';
		if (pathCache.exists(cacheKey))
			return pathCache.get(cacheKey);

		var resolved:String = _resolve(file, type, library);
		pathCache.set(cacheKey, resolved);
		return resolved;
	}

	static function _resolve(file:String, type:AssetType, ?library:String):String
	{
		if (library != null)
			return libraryPath(file, library);

		#if sys
		if (currentLevel != "")
		{
			var levelPath:String = forcePath(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;

			var sharedPath:String = forcePath(file, "shared");
			if (OpenFlAssets.exists(sharedPath, type))
				return sharedPath;
		}

		var modPath:String = forcePath(file, "mods");
		if (OpenFlAssets.exists(modPath, type))
			return modPath;
		#end

		return preloadPath(file);
	}

	public static function libraryPath(file:String, library:String = "preload"):String
	{
		return switch (library)
		{
			case "preload" | "default": preloadPath(file);
			default: forcePath(file, library);
		}
	}

	inline static function forcePath(file:String, library:String):String
		return '$library/$file';

	inline static function preloadPath(file:String):String
		return 'assets/$file';

	public static function fileExists(path:String, type:AssetType):Bool
	{
		#if sys
		return FileSystem.exists(path) || OpenFlAssets.exists(path, type);
		#else
		return OpenFlAssets.exists(path, type);
		#end
	}

	public static function getContent(path:String):String
	{
		#if sys
		if (FileSystem.exists(path))
			return File.getContent(path);
		#end
		if (OpenFlAssets.exists(path, TEXT))
			return OpenFlAssets.getText(path);
		return "";
	}

	inline public static function file(file:String, type:AssetType = TEXT, ?library:String):String
		return resolve(file, type, library);

	inline public static function txt(key:String, ?library:String):String
		return resolve('$key.txt', TEXT, library);

	inline public static function xml(key:String, ?library:String):String
		return resolve('data/$key.xml', TEXT, library);

	inline public static function json(key:String, ?library:String):String
		return resolve('data/$key.json', TEXT, library);

	inline public static function songJson(song:String, diff:String, ?library:String):String
		return resolve('songs/${song.toLowerCase()}/${diff.toLowerCase()}.json', TEXT, library);

	inline public static function offsetTxt(key:String, ?library:String):String
		return resolve('images/characters/$key.txt', TEXT, library);

	inline public static function lua(key:String, ?library:String):String
		return resolve('$key.lua', TEXT, library);

	inline public static function hscript(key:String, ?library:String):String
		return resolve('$key.hx', TEXT, library);

	inline public static function shader(key:String, ?library:String):String
		return resolve('shaders/$key.frag', TEXT, library);

	inline public static function image(key:String, ?library:String):String
		return resolve('images/$key.$IMAGE_EXT', IMAGE, library);

	inline public static function sound(key:String, ?library:String):String
		return resolve('sounds/$key.$SOUND_EXT', SOUND, library);

	inline public static function soundRandom(key:String, min:Int, max:Int, ?library:String):String
		return sound(key + FlxG.random.int(min, max), library);

	inline public static function music(key:String, ?library:String):String
		return resolve('music/$key.$SOUND_EXT', MUSIC, library);

	public static function voices(song:String):String
	{
		var normal:String = resolve('songs/${song.toLowerCase()}/Voices.$SOUND_EXT', MUSIC, null);
		if (fileExists(normal, MUSIC))
			return normal;
		return resolve('songs/${CoolUtil.swapSpaceDash(song.toLowerCase())}/Voices.$SOUND_EXT', MUSIC, null);
	}

	public static function inst(song:String):String
	{
		var normal:String = resolve('songs/${song.toLowerCase()}/Inst.$SOUND_EXT', MUSIC, null);
		if (fileExists(normal, MUSIC))
			return normal;
		return resolve('songs/${CoolUtil.swapSpaceDash(song.toLowerCase())}/Inst.$SOUND_EXT', MUSIC, null);
	}

	inline public static function font(key:String):String
		return 'assets/fonts/$key';

	inline public static function video(key:String, ?library:String):String
		return resolve('videos/$key.$VIDEO_EXT', BINARY, library);

	public static function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var imgPath:String = image(key, library);
		var xmlPath:String = resolve('images/$key.xml', TEXT, library);
		return FlxAtlasFrames.fromSparrow(imgPath, getContent(xmlPath));
	}

	public static function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var imgPath:String = image(key, library);
		var txtPath:String = resolve('images/$key.txt', TEXT, library);
		return FlxAtlasFrames.fromSpriteSheetPacker(imgPath, txtPath);
	}

	public static function getAsepriteAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var imgPath:String = image(key, library);
		var jsonPath:String = resolve('images/$key.json', TEXT, library);
		return FlxAtlasFrames.fromAseprite(imgPath, getContent(jsonPath));
	}
}
