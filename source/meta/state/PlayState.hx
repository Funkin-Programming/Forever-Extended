package meta.state;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import gameObjects.*;
import gameObjects.userInterface.*;
import gameObjects.userInterface.notes.*;
import gameObjects.userInterface.notes.Strumline.UIStaticArrow;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import meta.MusicBeat.MusicBeatState;
import meta.CoolUtil;
import meta.InfoHud;
import meta.data.*;
import meta.data.Song.SwagSong;
import meta.data.dependency.Discord;
import meta.state.charting.*;
import meta.state.menus.*;
import meta.subState.*;
import openfl.media.Sound;
import openfl.utils.Assets;

using StringTools;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef ScriptModule =
{
	var interp:Interp;
	var name:String;
}

class PlayState extends MusicBeatState
{
	public static var instance:PlayState;

	public static var SONG:SwagSong;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 2;
	public static var campaignScore:Int = 0;
	public static var curStage:String = '';
	public static var assetModifier:String = 'base';
	public static var changeableSkin:String = 'default';

	public static var songMusic:FlxSound;
	public static var vocals:FlxSound;
	public static var songLength:Float = 0;

	public static var dadOpponent:Character;
	public static var gf:Character;
	public static var boyfriend:Boyfriend;

	public static var health:Float = 1;
	public static var combo:Int = 0;
	public static var misses:Int = 0;
	public static var songScore:Int = 0;

	public static var camHUD:FlxCamera;
	public static var camGame:FlxCamera;
	public static var dialogueHUD:FlxCamera;
	public static var defaultCamZoom:Float = 1.05;
	public static var forceZoom:Array<Float> = [0, 0, 0, 0];
	public static var daPixelZoom:Float = 6;
	public static var determinedChartType:String = '';
	public static var iconRPC:String = '';
	public static var songDetails:String = '';
	public static var detailsSub:String = '';
	public static var detailsPausedText:String = '';
	public static var uiHUD:ClassHUD;
	public static var strumLines:FlxTypedGroup<Strumline>;
	public static var strumHUD:Array<FlxCamera> = [];
	public static var lastRating:FlxSprite;
	public static var lastCombo:Array<FlxSprite> = [];
	public static var startTimer:FlxTimer;
	public static var swagCounter:Int = 0;

	public var generatedMusic:Bool = false;
	public var camDisplaceX:Float = 0;
	public var camDisplaceY:Float = 0;

	private var scripts:Array<ScriptModule> = [];
	private var scriptParser:Parser;

	private var unspawnNotes:Array<Note> = [];
	private var ratingArray:Array<String> = [];
	private var allSicks:Bool = true;
	private var numberOfKeys:Int = 4;
	private var curSection:Int = 0;
	private var camFollow:FlxObject;
	private static var prevCamFollow:FlxObject;
	private var curSong:String = '';
	private var gfSpeed:Int = 1;
	private var startingSong:Bool = false;
	private var paused:Bool = false;
	private var startedCountdown:Bool = false;
	private var inCutscene:Bool = false;
	private var canPause:Bool = true;
	private var endSongEvent:Bool = false;
	private var ratingTiming:String = '';
	private var previousFrameTime:Int = 0;
	private var lastReportedPlayheadPosition:Int = 0;
	private var songTime:Float = 0;
	private var dadStrums:Strumline;
	private var boyfriendStrums:Strumline;
	private var stageBuild:Stage;
	private var allUIs:Array<FlxCamera> = [];
	private var dialogueBox:DialogueBox;
	private var createdColor:FlxColor = FlxColor.fromRGB(204, 66, 66);
	private var noteSpawnThreshold:Float = 3500;

	private static var _reusableRect:FlxRect = new FlxRect();
	private static var _reusablePoint:FlxPoint = new FlxPoint();

	override public function create():Void
	{
		instance = this;
		super.create();

		songScore = 0;
		combo = 0;
		health = 1;
		misses = 0;
		allSicks = true;
		lastCombo = [];
		defaultCamZoom = 1.05;
		forceZoom = [0, 0, 0, 0];
		strumHUD = [];
		allUIs = [];
		scripts = [];

		Timings.callAccuracy();
		assetModifier = 'base';
		changeableSkin = 'default';

		resetMusic();

		setupCameras();

		if (SONG == null)
			SONG = Song.loadFromJson('test', 'test');

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);
		determinedChartType = 'FNF';

		curStage = (SONG.stage != null) ? SONG.stage : '';

		displayRating('sick', 'early', true);
		popUpCombo(true);

		stageBuild = new Stage(curStage);
		add(stageBuild);

		gf = new Character(400, 130, stageBuild.returnGFtype(curStage));
		gf.scrollFactor.set(0.95, 0.95);

		dadOpponent = new Character(100, 100, SONG.player2);
		boyfriend = new Boyfriend(770, 450, SONG.player1);

		var camPos:FlxPoint = new FlxPoint(gf.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
		stageBuild.dadPosition(curStage, dadOpponent, gf, camPos, SONG.player2);

		changeableSkin = Init.trueSettings.get('UI Skin');
		if (curStage.startsWith('school') && determinedChartType == 'FNF')
			assetModifier = 'pixel';

		stageBuild.repositionPlayers(curStage, boyfriend, dadOpponent, gf);

		add(gf);
		if (curStage == 'highway')
			add(stageBuild.limo);
		add(dadOpponent);
		add(boyfriend);
		add(stageBuild.foreground);

		dadOpponent.dance();
		gf.dance();
		boyfriend.dance();

		Conductor.songPosition = -(Conductor.crochet * 4);

		var darknessBG:FlxSprite = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5)
			.makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		darknessBG.alpha = Init.trueSettings.get('Stage Darkness') * 0.01;
		darknessBG.scrollFactor.set(0, 0);
		add(darknessBG);

		strumLines = new FlxTypedGroup<Strumline>();
		generateSong(SONG.song);

		camPos.set(gf.x + (gf.frameWidth / 2), gf.y + (gf.frameHeight / 2));
		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(camPos.x, camPos.y);
		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, Main.framerateAdjust(0.04));
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow.getPosition());
		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		startingSong = true;
		startedCountdown = true;

		var placement:Float = FlxG.width / 2;
		dadStrums = new Strumline(placement - (FlxG.width / 4), this, dadOpponent, false, true, false, 4, Init.trueSettings.get('Downscroll'));
		dadStrums.visible = !Init.trueSettings.get('Centered Notefield');

		boyfriendStrums = new Strumline(
			placement + (!Init.trueSettings.get('Centered Notefield') ? (FlxG.width / 4) : 0),
			this, boyfriend, true, false, true, 4, Init.trueSettings.get('Downscroll')
		);

		strumLines.add(dadStrums);
		strumLines.add(boyfriendStrums);

		for (i in 0...strumLines.length)
		{
			var cam:FlxCamera = new FlxCamera();
			cam.bgColor.alpha = 0;
			cam.cameras = [camHUD];
			FlxG.cameras.add(cam);
			strumHUD.push(cam);
			allUIs.push(cam);
			strumLines.members[i].cameras = [cam];
		}
		add(strumLines);

		uiHUD = new ClassHUD();
		add(uiHUD);
		uiHUD.cameras = [camHUD];

		dialogueHUD = new FlxCamera();
		dialogueHUD.bgColor.alpha = 0;
		FlxG.cameras.add(dialogueHUD);

		loadScripts();
		callScript('onCreate');

		if (!skipCutscenes())
			songIntroCutscene();
		else
			startCountdown();
	}

	private function setupCameras():Void
	{
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD);
		allUIs.push(camHUD);
		FlxCamera.defaultCameras = [camGame];
	}

	private function loadScripts():Void
	{
		scriptParser = new Parser();
		scriptParser.allowJSON = true;
		scriptParser.allowMetadata = true;
		scriptParser.allowTypes = true;

		var scriptPaths:Array<String> = [
			'assets/data/scripts/global.hx',
			'assets/data/scripts/songs/${SONG.song.toLowerCase()}.hx',
			'assets/data/scripts/stages/$curStage.hx',
		];

		for (path in scriptPaths)
			tryLoadScript(path);
	}

	private function tryLoadScript(path:String):Void
	{
		#if sys
		if (!FileSystem.exists(path))
			return;

		try
		{
			var content:String = File.getContent(path);
			var expr:Expr = scriptParser.parseString(content, path);
			var interp:Interp = new Interp();

			injectScriptGlobals(interp);

			interp.execute(expr);
			scripts.push({interp: interp, name: path});
		}
		catch (e:Dynamic) {}
		#end
	}

	private function injectScriptGlobals(interp:Interp):Void
	{
		interp.variables.set('FlxG', FlxG);
		interp.variables.set('FlxTween', FlxTween);
		interp.variables.set('FlxTimer', FlxTimer);
		interp.variables.set('FlxEase', FlxEase);
		interp.variables.set('FlxColor', FlxColor);
		interp.variables.set('FlxSprite', FlxSprite);
		interp.variables.set('Math', Math);
		interp.variables.set('Std', Std);
		interp.variables.set('StringTools', StringTools);
		interp.variables.set('Paths', Paths);
		interp.variables.set('PlayState', PlayState);
		interp.variables.set('Conductor', Conductor);
		interp.variables.set('Init', Init);
		interp.variables.set('boyfriend', boyfriend);
		interp.variables.set('dadOpponent', dadOpponent);
		interp.variables.set('gf', gf);
		interp.variables.set('camGame', camGame);
		interp.variables.set('camHUD', camHUD);
		interp.variables.set('add', add);
		interp.variables.set('remove', remove);
		interp.variables.set('switchState', Main.switchState);
		interp.variables.set('playAnim', (char:Character, anim:String, force:Bool) -> char.playAnim(anim, force));
	}

	public function callScript(func:String, ?args:Array<Dynamic>):Void
	{
		if (args == null)
			args = [];
		for (script in scripts)
		{
			var fn = script.interp.variables.get(func);
			if (fn != null)
			{
				try { Reflect.callMethod(null, fn, args); }
				catch (e:Dynamic) {}
			}
		}
	}

	public function setScriptVar(name:String, value:Dynamic):Void
	{
		for (script in scripts)
			script.interp.variables.set(name, value);
	}

	override public function update(elapsed:Float):Void
	{
		stageBuild.stageUpdateConstant(elapsed, boyfriend, gf, dadOpponent);
		super.update(elapsed);

		FlxG.camera.followLerp = elapsed * 2;

		health = Math.min(health, 2);

		callScript('onUpdate', [elapsed]);

		handleDialogue();

		if (!inCutscene)
		{
			handlePause();
			handleChartEditor();
			handleSongTiming(elapsed);
			updateCameraTarget();
			updateCameraLerp();
			handleDeath();
			spawnNotes();
			noteCalls();
		}

		callScript('onUpdatePost', [elapsed]);
	}

	private function handleDialogue():Void
	{
		if (dialogueBox == null || !dialogueBox.alive)
			return;

		#if mobile
		if (FlxG.touches.getFirst() != null && dialogueBox.textStarted)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			dialogueBox.curPage += 1;
			if (dialogueBox.curPage >= dialogueBox.dialogueData.dialogue.length)
				dialogueBox.closeDialog();
			else
				dialogueBox.updateDialog();
		}
		#else
		if (FlxG.keys.justPressed.SHIFT)
			dialogueBox.closeDialog();
		if (controls.ACCEPT && dialogueBox.textStarted)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			dialogueBox.curPage += 1;
			if (dialogueBox.curPage >= dialogueBox.dialogueData.dialogue.length)
				dialogueBox.closeDialog();
			else
				dialogueBox.updateDialog();
		}
		#end
	}

	private function handlePause():Void
	{
		#if mobile
		var pausePressed:Bool = (FlxG.touches.getFirst() != null && FlxG.touches.getFirst().justPressed && startedCountdown && canPause);
		#else
		var pausePressed:Bool = (FlxG.keys.justPressed.ENTER && startedCountdown && canPause);
		#end

		if (pausePressed)
		{
			persistentUpdate = false;
			persistentDraw = true;
			paused = true;
			openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
			updateRPC(true);
		}
	}

	private function handleChartEditor():Void
	{
		#if !mobile
		if (FlxG.keys.justPressed.SEVEN && !startingSong && !isStoryMode)
		{
			resetMusic();
			Main.switchState(this, Init.trueSettings.get('Use Forever Chart Editor') ? new ChartingState() : new OriginalChartingState());
		}
		#end
	}

	private function handleSongTiming(elapsed:Float):Void
	{
		if (startingSong)
		{
			if (startedCountdown)
			{
				Conductor.songPosition += elapsed * 1000;
				if (Conductor.songPosition >= 0)
					startSong();
			}
		}
		else
		{
			Conductor.songPosition += elapsed * 1000;
			if (!paused)
			{
				songTime += FlxG.game.ticks - previousFrameTime;
				previousFrameTime = FlxG.game.ticks;
				if (Conductor.lastSongPos != Conductor.songPosition)
				{
					songTime = (songTime + Conductor.songPosition) / 2;
					Conductor.lastSongPos = Conductor.songPosition;
				}
			}
		}
	}

	private function updateCameraTarget():Void
	{
		if (!generatedMusic)
			return;

		var section = SONG.notes[Std.int(curStep / 16)];
		if (section == null)
			return;

		var char:Character = section.mustHitSection ? boyfriend : dadOpponent;
		var cx:Float = char.getMidpoint().x + (section.mustHitSection ? -100 : 150);
		var cy:Float = char.getMidpoint().y - 100;

		if (!section.mustHitSection)
		{
			switch (dadOpponent.curCharacter)
			{
				case 'mom': cy = char.getMidpoint().y;
				case 'senpai' | 'senpai-angry':
					cy = char.getMidpoint().y - 430;
					cx = char.getMidpoint().x - 100;
			}
			if (char.curCharacter == 'mom')
				vocals.volume = 1;
		}
		else
		{
			switch (curStage)
			{
				case 'limo': cx = char.getMidpoint().x - 300;
				case 'mall': cy = char.getMidpoint().y - 200;
				case 'school' | 'schoolEvil':
					cx = char.getMidpoint().x - 200;
					cy = char.getMidpoint().y - 200;
			}
		}

		camFollow.setPosition(cx + (camDisplaceX * 8), cy);
	}

	private inline function updateCameraLerp():Void
	{
		var lerp:Float = 0.95;
		FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom + forceZoom[0], FlxG.camera.zoom, lerp);
		FlxG.camera.angle = FlxMath.lerp(forceZoom[2], FlxG.camera.angle, lerp);

		for (hud in allUIs)
		{
			hud.zoom = FlxMath.lerp(1 + forceZoom[1], hud.zoom, lerp);
			hud.angle = FlxMath.lerp(forceZoom[3], hud.angle, lerp);
		}
	}

	private function handleDeath():Void
	{
		if (health <= 0 && startedCountdown)
		{
			persistentUpdate = false;
			persistentDraw = false;
			paused = true;
			resetMusic();
			openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
		}
	}

	private inline function spawnNotes():Void
	{
		while (unspawnNotes.length > 0 && (unspawnNotes[0].strumTime - Conductor.songPosition) < noteSpawnThreshold)
		{
			var dunceNote:Note = unspawnNotes.shift();
			var strumIdx:Int = Math.floor((dunceNote.noteData + (dunceNote.mustPress ? 4 : 0)) / numberOfKeys);
			strumLines.members[strumIdx].push(dunceNote);
		}
	}

	function noteCalls():Void
	{
		var up:Bool = controls.UP;
		var right:Bool = controls.RIGHT;
		var down:Bool = controls.DOWN;
		var left:Bool = controls.LEFT;

		var holdControls:Array<Bool> = [left, down, up, right];
		var pressControls:Array<Bool> = [controls.LEFT_P, controls.DOWN_P, controls.UP_P, controls.RIGHT_P];
		var releaseControls:Array<Bool> = [controls.LEFT_R, controls.DOWN_R, controls.UP_R, controls.RIGHT_R];

		var downscrollMult:Int = Init.trueSettings.get('Downscroll') ? -1 : 1;

		for (strumline in strumLines)
		{
			for (uiNote in strumline.receptors)
			{
				if (strumline.autoplay)
					strumCallsAuto(uiNote);
			}

			if (strumline.splashNotes != null)
			{
				for (i in 0...strumline.splashNotes.length)
				{
					strumline.splashNotes.members[i].x = strumline.receptors.members[i].x - 48;
					strumline.splashNotes.members[i].y = strumline.receptors.members[i].y - 56;
				}
			}
		}

		if (!generatedMusic || !startedCountdown)
			return;

		for (strumline in strumLines)
		{
			if (!strumline.autoplay)
				controlPlayer(strumline.character, strumline.autoplay, strumline, holdControls, pressControls, releaseControls);

			strumline.notesGroup.forEachAlive(function(daNote:Note)
			{
				var receptor = strumline.receptors.members[Math.floor(daNote.noteData)];
				var psuedoY:Float = downscrollMult * -((Conductor.songPosition - daNote.strumTime) * (0.45 * FlxMath.roundDecimal(daNote.noteSpeed, 2)));
				var psuedoX:Float = 25 + daNote.noteVisualOffset;
				var rad:Float = flixel.math.FlxAngle.asRadians(daNote.noteDirection);
				var cosR:Float = Math.cos(rad);
				var sinR:Float = Math.sin(rad);

				daNote.y = receptor.y + (cosR * psuedoY) + (sinR * psuedoX);
				daNote.x = receptor.x + (cosR * psuedoX) + (sinR * psuedoY);
				daNote.angle = -daNote.noteDirection;

				if (daNote.isSustainNote)
				{
					if (daNote.animation.curAnim.name.endsWith('holdend') && daNote.prevNote != null)
						daNote.y += Init.trueSettings.get('Downscroll') ? daNote.prevNote.height : -(daNote.prevNote.height / 2);
					else
						daNote.y -= (daNote.height / 2) * downscrollMult;

					daNote.flipY = Init.trueSettings.get('Downscroll');
				}

				var offscreenBottom:Bool = daNote.y > FlxG.height;
				var offscreenTop:Bool = !Init.trueSettings.get('Downscroll') && daNote.y < -daNote.height;
				var offscreenDownBottom:Bool = Init.trueSettings.get('Downscroll') && daNote.y > FlxG.height + daNote.height;

				daNote.active = !offscreenBottom;
				daNote.visible = !offscreenBottom;

				if (offscreenTop || offscreenDownBottom)
				{
					if (daNote.mustPress && (daNote.tooLate || !daNote.wasGoodHit))
					{
						vocals.volume = 0;
						missNoteCheck(Init.trueSettings.get('Ghost Tapping'), daNote.noteData, boyfriend, true);
						Timings.updateAccuracy(0);
					}
					killNote(daNote, strumline);
					return;
				}

				mainControls(daNote, strumline.character, strumline, strumline.autoplay);
			});
		}
	}

	private inline function killNote(note:Note, strumline:Strumline):Void
	{
		note.active = false;
		note.visible = false;
		note.kill();
		if (strumline.notesGroup.members.contains(note))
			strumline.notesGroup.remove(note, true);
		note.destroy();
	}

	function controlPlayer(character:Character, autoplay:Bool, characterStrums:Strumline, holdControls:Array<Bool>, pressControls:Array<Bool>, releaseControls:Array<Bool>):Void
	{
		if (!autoplay && pressControls.contains(true))
		{
			for (i in 0...pressControls.length)
			{
				if (!pressControls[i])
					continue;

				var possibleNotes:Array<Note> = [];
				var pressedNotes:Array<Note> = [];

				characterStrums.notesGroup.forEachAlive(function(daNote:Note)
				{
					if (daNote.noteData == i && daNote.canBeHit && !daNote.tooLate && !daNote.wasGoodHit)
						possibleNotes.push(daNote);
				});

				possibleNotes.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

				if (possibleNotes.length > 0)
				{
					for (coolNote in possibleNotes)
					{
						var eligible:Bool = true;
						var firstNote:Bool = true;

						for (pressed in pressedNotes)
						{
							if (Math.abs(pressed.strumTime - coolNote.strumTime) < 10)
								firstNote = false;
							else
								eligible = false;
						}

						if (eligible)
						{
							goodNoteHit(coolNote, character, characterStrums, firstNote);
							pressedNotes.push(coolNote);
						}
					}
				}
				else if (!Init.trueSettings.get('Ghost Tapping'))
					missNoteCheck(true, i, character, true);
			}
		}

		if (!autoplay && holdControls.contains(true))
		{
			characterStrums.notesGroup.forEachAlive(function(coolNote:Note)
			{
				if (coolNote.canBeHit && coolNote.mustPress && coolNote.isSustainNote && holdControls[coolNote.noteData])
					goodNoteHit(coolNote, character, characterStrums);
			});
		}

		characterStrums.receptors.forEach(function(strum:UIStaticArrow)
		{
			if (pressControls[strum.ID] && strum.animation.curAnim.name != 'confirm')
				strum.playAnim('pressed');
			if (releaseControls[strum.ID])
				strum.playAnim('static');
		});

		if (character != null && character.animation != null
			&& character.holdTimer > Conductor.stepCrochet * (4 / 1000)
			&& (!holdControls.contains(true) || autoplay))
		{
			if (character.animation.curAnim.name.startsWith('sing') && !character.animation.curAnim.name.endsWith('miss'))
				character.dance();
		}
	}

	function goodNoteHit(coolNote:Note, character:Character, characterStrums:Strumline, ?canDisplayJudgement:Bool = true):Void
	{
		if (coolNote.wasGoodHit)
			return;

		coolNote.wasGoodHit = true;
		vocals.volume = 1;

		characterPlayAnimation(coolNote, character);

		if (characterStrums.receptors.members[coolNote.noteData] != null)
			characterStrums.receptors.members[coolNote.noteData].playAnim('confirm', true);

		if (canDisplayJudgement)
		{
			var noteDiff:Float = Math.abs(coolNote.strumTime - Conductor.songPosition);
			ratingTiming = coolNote.strumTime < Conductor.songPosition ? 'late' : 'early';

			var foundRating:String = 'miss';
			var lowestThreshold:Float = Math.POSITIVE_INFINITY;

			for (myRating in Timings.judgementsMap.keys())
			{
				var threshold:Float = Timings.judgementsMap.get(myRating)[1];
				if (noteDiff <= threshold && threshold < lowestThreshold)
				{
					foundRating = myRating;
					lowestThreshold = threshold;
				}
			}

			if (!coolNote.isSustainNote)
			{
				increaseCombo(foundRating, coolNote.noteData, character);
				popUpScore(foundRating, ratingTiming, characterStrums, coolNote);
				healthCall(Timings.judgementsMap.get(foundRating)[3]);
			}
			else
			{
				Timings.updateAccuracy(100, true);
				if (coolNote.animation.name.endsWith('holdend'))
					healthCall(100);
			}
		}

		callScript('onNoteHit', [coolNote, character]);

		if (!coolNote.isSustainNote)
			killNote(coolNote, characterStrums);
	}

	function missNoteCheck(?includeAnimation:Bool = false, direction:Int = 0, character:Character, popMiss:Bool = false, lockMiss:Bool = false):Void
	{
		if (includeAnimation)
		{
			var stringDir:String = UIStaticArrow.getArrowFromNumber(direction);
			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
			character.playAnim('sing' + stringDir.toUpperCase() + 'miss', lockMiss);
		}

		decreaseCombo(popMiss);
		callScript('onMiss', [direction]);
	}

	function characterPlayAnimation(coolNote:Note, character:Character):Void
	{
		var baseString:String = 'sing' + UIStaticArrow.getArrowFromNumber(coolNote.noteData).toUpperCase();
		var altString:String = coolNote.noteAlt > 0 ? '-alt' : '';

		if (SONG.notes[Math.floor(curStep / 16)] != null
			&& SONG.notes[Math.floor(curStep / 16)].altAnim
			&& character.animOffsets.exists(baseString + '-alt'))
		{
			altString = altString != '-alt' ? '-alt' : '';
		}

		character.playAnim(baseString + altString, true);
		character.holdTimer = 0;
	}

	private function strumCallsAuto(cStrum:UIStaticArrow, ?callType:Int = 1, ?daNote:Note):Void
	{
		if (callType == 1)
		{
			if (cStrum.animation.finished && cStrum.canFinishAnimation)
				cStrum.playAnim('static');
		}
		else if (daNote != null && daNote.noteData == cStrum.ID)
		{
			cStrum.playAnim('confirm');
			cStrum.canFinishAnimation = !daNote.isSustainNote || daNote.animation.curAnim.name.endsWith('holdend');
		}
	}

	private function mainControls(daNote:Note, char:Character, strumline:Strumline, autoplay:Bool):Void
	{
		var downscroll:Bool = Init.trueSettings.get('Downscroll');
		var receptor = strumline.receptors.members[Math.floor(daNote.noteData)];
		var receptorMid:Float = receptor.y + Note.swagWidth / 2;

		var clipped:Bool = daNote.isSustainNote && (
			(!downscroll && daNote.y + daNote.offset.y <= receptorMid)
			|| (downscroll && daNote.y - (daNote.offset.y * daNote.scale.y) + daNote.height >= receptorMid)
		) && (autoplay || daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit));

		if (clipped)
		{
			var swagRectY:Float = (receptorMid - daNote.y) / daNote.scale.y;
			_reusableRect.set(0, 0, daNote.width * 2, daNote.height * 2);

			if (downscroll)
			{
				_reusableRect.height = swagRectY;
				_reusableRect.y += _reusableRect.height - daNote.height;
			}
			else
			{
				_reusableRect.y = swagRectY;
				_reusableRect.height -= _reusableRect.y;
			}

			daNote.clipRect = _reusableRect;
		}

		if (autoplay && daNote.strumTime <= Conductor.songPosition)
		{
			var canDisplayJudgement:Bool = strumline.displayJudgements;
			goodNoteHit(daNote, char, strumline, canDisplayJudgement);
		}

		strumCameraRoll(strumline.receptors, daNote.mustPress);
	}

	private function strumCameraRoll(cStrum:FlxTypedGroup<UIStaticArrow>, mustHit:Bool):Void
	{
		if (Init.trueSettings.get('No Camera Note Movement'))
			return;

		var section = PlayState.SONG.notes[Std.int(curStep / 16)];
		if (section == null)
			return;

		var active:Bool = (section.mustHitSection && mustHit) || (!section.mustHitSection && !mustHit);
		if (!active)
			return;

		var extend:Float = 1.5;
		var speed:Float = 0.0125;

		if (cStrum.members[0].animation.curAnim.name == 'confirm' && camDisplaceX > -extend)
			camDisplaceX -= speed;
		else if (cStrum.members[3].animation.curAnim.name == 'confirm' && camDisplaceX < extend)
			camDisplaceX += speed;
	}

	override public function onFocus():Void
	{
		if (!paused)
			updateRPC(false);
		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		updateRPC(true);
		super.onFocusLost();
	}

	public static function updateRPC(pausedRPC:Bool):Void
	{
		#if desktop
		if (health <= 0)
			return;

		var display:String = pausedRPC ? detailsPausedText : songDetails;

		if (Conductor.songPosition > 0 && !pausedRPC)
			Discord.changePresence(display, detailsSub, iconRPC, true, songLength - Conductor.songPosition);
		else
			Discord.changePresence(display, detailsSub, iconRPC);
		#end
	}

	function popUpScore(baseRating:String, timing:String, strumline:Strumline, coolNote:Note):Void
	{
		if (baseRating == 'sick')
			createSplash(coolNote, strumline);
		else if (allSicks)
			allSicks = false;

		displayRating(baseRating, timing);
		Timings.updateAccuracy(Timings.judgementsMap.get(baseRating)[3]);
		songScore += Std.int(Timings.judgementsMap.get(baseRating)[2]);
		popUpCombo();
	}

	public function createSplash(coolNote:Note, strumline:Strumline):Void
	{
		if (strumline.splashNotes == null)
			return;

		var rand:String = Std.string(FlxG.random.int(1, 2));
		strumline.splashNotes.members[coolNote.noteData].playAnim('anim' + rand);
	}

	function popUpCombo(?preload:Bool = false):Void
	{
		var comboString:String = Std.string(combo);
		var negative:Bool = comboString.startsWith('-') || combo == 0;
		var stringArray:Array<String> = comboString.split('');

		if (lastCombo != null)
		{
			while (lastCombo.length > 0)
			{
				lastCombo[0].kill();
				lastCombo.remove(lastCombo[0]);
			}
		}

		var simply:Bool = Init.trueSettings.get('Simply Judgements');
		var fixed:Bool = Init.trueSettings.get('Fixed Judgements');

		for (scoreInt in 0...stringArray.length)
		{
			var numScore:FlxSprite = ForeverAssets.generateCombo('combo', stringArray[scoreInt], (!negative ? allSicks : false),
				assetModifier, changeableSkin, 'UI', negative, createdColor, scoreInt);

			add(numScore);

			if (!simply)
			{
				FlxTween.tween(numScore, {alpha: 0}, 0.2, {
					onComplete: (_) -> numScore.kill(),
					startDelay: Conductor.crochet * 0.002
				});
			}
			else
			{
				numScore.y += 10;
				numScore.x -= 95 + ((comboString.length - 1) * 22);
				lastCombo.push(numScore);
				FlxTween.tween(numScore, {y: numScore.y + 20}, 0.1, {type: FlxTweenType.BACKWARD, ease: FlxEase.circOut});
			}

			if (preload)
				numScore.visible = false;

			if (fixed)
			{
				numScore.cameras = [camHUD];
				numScore.y += 50;
			}

			numScore.x += 100;
		}
	}

	function decreaseCombo(?popMiss:Bool = false):Void
	{
		if ((combo > 5 || combo < 0) && gf.animOffsets.exists('sad'))
			gf.playAnim('sad');

		combo = combo > 0 ? 0 : combo - 1;
		songScore -= 10;
		misses++;

		if (popMiss)
		{
			displayRating('miss', 'late');
			healthCall(Timings.judgementsMap.get('miss')[3]);
		}

		popUpCombo();
		Timings.updateFCDisplay();
	}

	function increaseCombo(?baseRating:String, ?direction:Int = 0, ?character:Character):Void
	{
		if (baseRating == null)
			return;

		if (Timings.judgementsMap.get(baseRating)[3] > 0)
		{
			if (combo < 0)
				combo = 0;
			combo += 1;
		}
		else
			missNoteCheck(true, direction, character, false, true);
	}

	public function displayRating(daRating:String, timing:String, ?cache:Bool = false):Void
	{
		var rating:FlxSprite = ForeverAssets.generateRating('$daRating', daRating == 'sick' ? allSicks : false, timing, assetModifier, changeableSkin, 'UI');
		add(rating);

		var simply:Bool = Init.trueSettings.get('Simply Judgements');
		var fixed:Bool = Init.trueSettings.get('Fixed Judgements');
		var delay:Float = Conductor.crochet * 0.00125;

		if (!simply)
		{
			FlxTween.tween(rating, {alpha: 0}, 0.2, {
				onComplete: (_) -> rating.kill(),
				startDelay: delay
			});
		}
		else
		{
			if (lastRating != null)
				lastRating.kill();
			lastRating = rating;
			FlxTween.tween(rating, {y: rating.y + 20}, 0.2, {type: FlxTweenType.BACKWARD, ease: FlxEase.circOut});
			FlxTween.tween(rating, {'scale.x': 0, 'scale.y': 0}, 0.1, {
				onComplete: (_) -> rating.kill(),
				startDelay: delay
			});
		}

		if (fixed)
		{
			rating.cameras = [camHUD];
			rating.screenCenter();
		}

		Timings.gottenJudgements.set(daRating, Timings.gottenJudgements.get(daRating) + 1);

		if (Timings.smallestRating != daRating
			&& Timings.judgementsMap.get(Timings.smallestRating)[0] < Timings.judgementsMap.get(daRating)[0])
			Timings.smallestRating = daRating;

		if (cache)
			rating.visible = false;
	}

	function healthCall(?ratingMultiplier:Float = 0):Void
		health += 0.06 * (ratingMultiplier / 100);

	function startSong():Void
	{
		startingSong = false;
		previousFrameTime = FlxG.game.ticks;
		lastReportedPlayheadPosition = 0;

		if (paused)
			return;

		songMusic.play();
		songMusic.onComplete = endSong;
		vocals.play();
		resyncVocals();

		#if !html5
		songLength = songMusic.length;
		updateRPC(false);
		#end

		callScript('onSongStart');
	}

	private function generateSong(dataPath:String):Void
	{
		var songData = SONG;
		Conductor.changeBPM(songData.bpm);

		songDetails = CoolUtil.dashToSpace(SONG.song) + ' - ' + CoolUtil.difficultyFromNumber(storyDifficulty);
		detailsPausedText = 'Paused - ' + songDetails;
		detailsSub = '';

		updateRPC(false);

		curSong = songData.song;

		songMusic = new FlxSound();
		songMusic.loadEmbedded(Sound.fromFile('./' + Paths.inst(SONG.song)), false, true);

		vocals = new FlxSound();
		if (SONG.needsVoices)
			vocals.loadEmbedded(Sound.fromFile('./' + Paths.voices(SONG.song)), false, true);

		FlxG.sound.list.add(songMusic);
		FlxG.sound.list.add(vocals);

		unspawnNotes = ChartLoader.generateChartType(SONG, determinedChartType);
		unspawnNotes.sort((a, b) -> FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime));

		generatedMusic = true;
		Timings.accuracyMaxCalculation(unspawnNotes);
	}

	function resyncVocals():Void
	{
		vocals.pause();
		songMusic.play();
		Conductor.songPosition = songMusic.time;
		vocals.time = Conductor.songPosition;
		vocals.play();
	}

	override function stepHit():Void
	{
		super.stepHit();
		if (Math.abs(songMusic.time - Conductor.songPosition) > 20)
			resyncVocals();
		callScript('onStepHit', [curStep]);
	}

	private function charactersDance(curBeat:Int):Void
	{
		if (curBeat % gfSpeed == 0 && gf.animation.curAnim.name.startsWith('dance'))
			gf.dance();
		if (curBeat % 2 == 0 || boyfriend.quickDancer)
			if (boyfriend.animation.curAnim.name.startsWith('idle'))
				boyfriend.dance();
		if (curBeat % 2 == 0 || dadOpponent.quickDancer)
			if (dadOpponent.animation.curAnim.name.startsWith('idle'))
				dadOpponent.dance();
	}

	override function beatHit():Void
	{
		super.beatHit();

		if (FlxG.camera.zoom < 1.35 && curBeat % 4 == 0 && !Init.trueSettings.get('Reduced Movements'))
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.05;
			for (hud in strumHUD)
				hud.zoom += 0.05;
		}

		uiHUD.beatHit();
		charactersDance(curBeat);
		stageBuild.stageUpdate(curBeat, boyfriend, gf, dadOpponent);

		callScript('onBeatHit', [curBeat]);
	}

	public static function resetMusic():Void
	{
		if (songMusic != null)
			songMusic.stop();
		if (vocals != null)
			vocals.stop();
	}

	override function openSubState(SubState:FlxSubState):Void
	{
		if (paused)
		{
			if (songMusic != null)
			{
				songMusic.pause();
				vocals.pause();
			}
			if (startTimer != null && !startTimer.finished)
				startTimer.active = false;
		}
		super.openSubState(SubState);
	}

	override function closeSubState():Void
	{
		if (paused)
		{
			if (songMusic != null && !startingSong)
				resyncVocals();
			if (startTimer != null && !startTimer.finished)
				startTimer.active = true;
			paused = false;
			updateRPC(false);
		}
		super.closeSubState();
	}

	function endSong():Void
	{
		canPause = false;
		songMusic.volume = 0;
		vocals.volume = 0;

		callScript('onSongEnd');

		if (SONG.validScore)
			Highscore.saveScore(SONG.song, songScore, storyDifficulty);

		if (!isStoryMode)
		{
			Main.switchState(this, new FreeplayState());
			return;
		}

		campaignScore += songScore;
		storyPlaylist.remove(storyPlaylist[0]);

		if (storyPlaylist.length <= 0 && !endSongEvent)
		{
			ForeverTools.resetMenuMusic();
			transIn = FlxTransitionableState.defaultTransIn;
			transOut = FlxTransitionableState.defaultTransOut;
			Main.switchState(this, new StoryMenuState());

			if (SONG.validScore)
				Highscore.saveWeekScore(storyWeek, campaignScore, storyDifficulty);

			FlxG.save.flush();
		}
		else
			songEndSpecificActions();
	}

	private function songEndSpecificActions():Void
	{
		switch (SONG.song.toLowerCase())
		{
			case 'eggnog':
				var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom, -FlxG.height * FlxG.camera.zoom)
					.makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
				blackShit.scrollFactor.set();
				add(blackShit);
				camHUD.visible = false;
				FlxG.sound.play(Paths.sound('Lights_Shut_off'));
				new FlxTimer().start(Conductor.crochet / 1000, (_) -> callDefaultSongEnd(), 1);

			default:
				callDefaultSongEnd();
		}
	}

	private function callDefaultSongEnd():Void
	{
		var difficulty:String = '-' + CoolUtil.difficultyFromNumber(storyDifficulty).toLowerCase();
		difficulty = difficulty.replace('-normal', '');

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + difficulty, PlayState.storyPlaylist[0]);
		ForeverTools.killMusic([songMusic, vocals]);
		FlxG.switchState(new PlayState());
	}

	public function songIntroCutscene():Void
	{
		callScript('onIntroCutscene');

		switch (curSong.toLowerCase())
		{
			case 'winter-horrorland':
				inCutscene = true;
				var blackScreen:FlxSprite = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				blackScreen.scrollFactor.set();
				add(blackScreen);
				camHUD.visible = false;

				new FlxTimer().start(0.1, function(_)
				{
					remove(blackScreen);
					FlxG.sound.play(Paths.sound('Lights_Turn_On'));
					camFollow.y = -2050;
					camFollow.x += 200;
					FlxG.camera.focusOn(camFollow.getPosition());
					FlxG.camera.zoom = 1.5;

					new FlxTimer().start(0.8, function(_)
					{
						camHUD.visible = true;
						FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 2.5, {
							ease: FlxEase.quadInOut,
							onComplete: (_) -> startCountdown()
						});
					});
				});

			case 'roses':
				FlxG.sound.play(Paths.sound('ANGRY_TEXT_BOX'));
				callTextbox();

			case 'thorns':
				inCutscene = true;
				for (hud in allUIs)
					hud.visible = false;

				var red:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFff1b31);
				red.scrollFactor.set();

				var senpaiEvil:FlxSprite = new FlxSprite();
				senpaiEvil.frames = Paths.getSparrowAtlas('cutscene/senpai/senpaiCrazy');
				senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
				senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * 6));
				senpaiEvil.scrollFactor.set();
				senpaiEvil.updateHitbox();
				senpaiEvil.screenCenter();
				senpaiEvil.alpha = 0;

				add(red);
				add(senpaiEvil);

				new FlxTimer().start(0.3, function(t:FlxTimer)
				{
					senpaiEvil.alpha += 0.15;
					if (senpaiEvil.alpha < 1)
					{
						t.reset();
						return;
					}

					senpaiEvil.animation.play('idle');
					FlxG.sound.play(Paths.sound('Senpai_Dies'), 1, false, null, true, function()
					{
						remove(senpaiEvil);
						remove(red);
						FlxG.camera.fade(FlxColor.WHITE, 0.01, true, function()
						{
							for (hud in allUIs)
								hud.visible = true;
							callTextbox();
						}, true);
					});

					new FlxTimer().start(3.2, (_) -> FlxG.camera.fade(FlxColor.WHITE, 1.6, false));
				});

			default:
				callTextbox();
		}
	}

	function callTextbox():Void
	{
		var dialogPath:String = Paths.json(SONG.song.toLowerCase() + '/dialogue');

		#if sys
		var exists:Bool = FileSystem.exists(dialogPath);
		#else
		var exists:Bool = Assets.exists(dialogPath);
		#end

		if (exists)
		{
			startedCountdown = false;
			#if sys
			dialogueBox = DialogueBox.createDialogue(File.getContent(dialogPath));
			#else
			dialogueBox = DialogueBox.createDialogue(Assets.getText(dialogPath));
			#end
			dialogueBox.cameras = [dialogueHUD];
			dialogueBox.whenDaFinish = startCountdown;
			add(dialogueBox);
		}
		else
			startCountdown();
	}

	public static function skipCutscenes():Bool
	{
		var skip = Init.trueSettings.get('Skip Text');
		if (skip == null || !Std.isOfType(skip, String))
			return false;

		return switch (cast(skip, String))
		{
			case 'never': false;
			case 'freeplay only': !isStoryMode;
			default: true;
		};
	}

	private function startCountdown():Void
	{
		inCutscene = false;
		Conductor.songPosition = -(Conductor.crochet * 5);
		swagCounter = 0;
		camHUD.visible = true;

		callScript('onCountdownStart');

		startTimer = new FlxTimer().start(Conductor.crochet / 1000, function(_)
		{
			startedCountdown = true;
			charactersDance(curBeat);

			var introAlts:Array<String> = [
				ForeverTools.returnSkinAsset('ready', assetModifier, changeableSkin, 'UI'),
				ForeverTools.returnSkinAsset('set', assetModifier, changeableSkin, 'UI'),
				ForeverTools.returnSkinAsset('go', assetModifier, changeableSkin, 'UI')
			];

			var soundSuffix:String = '-' + assetModifier;

			switch (swagCounter)
			{
				case 0:
					FlxG.sound.play(Paths.sound('intro3' + soundSuffix), 0.6);
					Conductor.songPosition = -(Conductor.crochet * 4);

				case 1 | 2 | 3:
					var imgKey:String = introAlts[swagCounter - 1];
					var sprite:FlxSprite = new FlxSprite().loadGraphic(Paths.image(imgKey));
					sprite.scrollFactor.set();
					sprite.updateHitbox();
					if (assetModifier == 'pixel')
						sprite.setGraphicSize(Std.int(sprite.width * daPixelZoom));
					sprite.screenCenter();
					add(sprite);
					FlxTween.tween(sprite, {y: sprite.y + 100, alpha: 0}, Conductor.crochet / 1000, {
						ease: FlxEase.cubeInOut,
						onComplete: (_) -> sprite.destroy()
					});

					var sounds:Array<String> = ['intro2', 'intro1', 'introGo'];
					FlxG.sound.play(Paths.sound(sounds[swagCounter - 1] + soundSuffix), 0.6);
					Conductor.songPosition = -(Conductor.crochet * (4 - swagCounter));
			}

			swagCounter++;
		}, 5);
	}

	override function add(Object:FlxBasic):FlxBasic
	{
		if (Init.trueSettings.get('Disable Antialiasing') && Std.isOfType(Object, FlxSprite))
			cast(Object, FlxSprite).antialiasing = false;
		return super.add(Object);
	}

	override function destroy():Void
	{
		scripts = [];
		instance = null;
		super.destroy();
	}
}
