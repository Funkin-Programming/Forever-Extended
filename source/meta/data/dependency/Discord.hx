package meta.data.dependency;

#if desktop
import discord_rpc.DiscordRpc;
import lime.app.Application;
import sys.thread.Thread;

class Discord
{
	static inline final CLIENT_ID:String = '879525344128925717';
	static inline final LARGE_IMAGE_KEY:String = 'iconog';
	static inline final LARGE_IMAGE_TEXT:String = 'Forever Extended';

	public static var isInitialized:Bool = false;
	public static var isShuttingDown:Bool = false;

	static var currentDetails:String = '';
	static var currentState:String = '';

	public static function initializeRPC():Void
	{
		if (isInitialized)
			return;

		try
		{
			DiscordRpc.start({
				clientID: CLIENT_ID,
				onReady: onReady,
				onError: onError,
				onDisconnected: onDisconnected
			});

			isInitialized = true;

			Application.current.window.onClose.add(shutdownRPC);

			Thread.create(() ->
			{
				while (!isShuttingDown)
				{
					DiscordRpc.process();
					Sys.sleep(2);
				}
			});
		}
		catch (e:Dynamic)
		{
			isInitialized = false;
		}
	}

	static function onReady():Void
	{
		DiscordRpc.presence({
			details: 'Starting up...',
			state: null,
			largeImageKey: LARGE_IMAGE_KEY,
			largeImageText: LARGE_IMAGE_TEXT
		});
	}

	static function onError(code:Int, message:String):Void
	{
		isInitialized = false;
	}

	static function onDisconnected(code:Int, message:String):Void
	{
		isInitialized = false;
	}

	public static function changePresence(details:String = '', ?state:String, ?smallImageKey:String, ?smallImageText:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float):Void
	{
		if (!isInitialized || isShuttingDown)
			return;

		currentDetails = details;
		currentState = state ?? '';

		var startTimestamp:Int = 0;
		var endTimestampInt:Int = 0;

		if (hasStartTimestamp == true)
		{
			startTimestamp = Std.int(Date.now().getTime() / 1000);

			if (endTimestamp != null && endTimestamp > 0)
				endTimestampInt = startTimestamp + Std.int(endTimestamp);
		}

		try
		{
			DiscordRpc.presence({
				details: currentDetails,
				state: currentState,
				largeImageKey: LARGE_IMAGE_KEY,
				largeImageText: LARGE_IMAGE_TEXT,
				smallImageKey: smallImageKey ?? '',
				smallImageText: smallImageText ?? '',
				startTimestamp: startTimestamp,
				endTimestamp: endTimestampInt
			});
		}
		catch (e:Dynamic) {}
	}

	public static function clearPresence():Void
	{
		if (!isInitialized || isShuttingDown)
			return;

		try
		{
			DiscordRpc.presence({
				details: '',
				state: null,
				largeImageKey: LARGE_IMAGE_KEY,
				largeImageText: LARGE_IMAGE_TEXT
			});
		}
		catch (e:Dynamic) {}
	}

	public static function shutdownRPC():Void
	{
		if (!isInitialized || isShuttingDown)
			return;

		isShuttingDown = true;

		try
		{
			DiscordRpc.shutdown();
		}
		catch (e:Dynamic) {}

		isInitialized = false;
	}
}
#else
class Discord
{
	public static var isInitialized:Bool = false;
	public static var isShuttingDown:Bool = false;

	public static function initializeRPC():Void {}
	public static function changePresence(details:String = '', ?state:String, ?smallImageKey:String, ?smallImageText:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float):Void {}
	public static function clearPresence():Void {}
	public static function shutdownRPC():Void {}
}
#end
