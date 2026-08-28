// GoldSrcHUD
// Ported from the POSTAL 2 GoldSrcMovement mod to UT2004. Extends HudCDeathmatch,
// so the entire stock HUD keeps drawing underneath; this class only adds the
// GoldSrc overlays (speedometer, movedebug, net_graph, cl_showpos, HL damage
// indicator), the HL2 viewmodel bob/sway, and an optional Half-Life bottom row.
class GoldSrcHUD extends HudCDeathmatch;

var config color SpeedColor;
var config color LabelColor;
var config color DebugColor;
var config color AccelColor;
var config color DecelColor;

// graph history for the velocity graph, which is drawn in the lower right corner of the screen
// graph is not shown by default but can be enabled in the ini

const GRAPH_SAMPLES = 96;
var float GraphSpeed[96];
var int   GraphIndex;
var bool  bGraphFilled;

var config bool bShowVelocityGraph;

var float LastSpeed;        // for the accel/decel indicator
var float DisplayAccel;     // smoothed d(speed)/dt

// net_graph and cl_showpos recreations

const FPS_WINDOW = 0.25;    // seconds of frames averaged into the fps readout

var float LastFrameTime;    // Level.TimeSeconds at the previous DrawHUD
var float FpsAccumTime;     // real seconds accumulated in the current window
var int   FpsFrames;        // frames counted in the current window
var float DisplayFps;

var config color NetGraphColor;
var config color ShowPosColor;

// damage direction indicator, ported from CHudHealth in cl_dll/health.cpp
//
// The four values are how strongly the last hit came from each side, 0..1, and
// they live here rather than on the player for the same reason Valve keeps them on
// the HUD: they are latched in SCREEN space at the moment of the hit, so turning
// round afterwards does not drag the wedges with you.
var float AttackFront;      // m_fAttackFront
var float AttackRear;       // m_fAttackRear
var float AttackLeft;       // m_fAttackLeft
var float AttackRight;      // m_fAttackRight
var float PainLastTime;     // our own, because UpdateFps owns LastFrameTime

var config color PainColor;

const PAIN_THRESHOLD  = 0.3;    // health.cpp:269, how far off-axis still counts
const PAIN_MIN_DRAW   = 0.4;    // :307, below this the wedge is dropped outright
const PAIN_MIN_SHADE  = 0.5;    // :310, the floor under the brightness
const PAIN_FADE_RATE  = 2.0;    // :304, m_flTimeDelta * 2 per frame
const PAIN_NEAR_DIST  = 100.0;  // :261, Valve's 50 units at the doubled scale

// Valve's pain sprite is 24 wide and 9 deep at 640x480, and every placement below
// is written in terms of those two numbers, so they scale as one.
const PAIN_SPR_W      = 24.0;
const PAIN_SPR_H      = 9.0;
const PAIN_REF_HEIGHT = 480.0;

// How much narrower the end nearest the crosshair is. Valve had an actual sprite;
// this is the shape of it.
const PAIN_TAPER      = 0.35;
const PAIN_SLICES     = 8;

// source viewmodel bob and sway, ported from CBaseHLCombatWeapon::CalcViewmodelBob and CBaseViewModel::CalcViewModelLag from Source SDK 2013
// the bob is applied in HUD.PostRender and the sway is applied in Controller.RenderOverlays
// so both are bracketed around the draw of the viewmodel and can write to its PlayerViewOffset safely.
const HL2_BOB_CYCLE_MAX = 0.45;     // basehlcombatweapon_shared.cpp:235
const HL2_BOB_UP        = 0.5;      // :237
const BOB_PI            = 3.14159265;

var float BobTime;          // bobtime      (static in CalcViewmodelBob)
var float LastBobTime;      // lastbobtime  (ditto)
var float VerticalBob;      // g_verticalBob
var float LateralBob;       // g_lateralBob

// the weapon we have an offset written into right now and its real value.
var Weapon BobWeapon;
var Pawn   BobPawn;         // the pawn whose draw path places it
var vector BobSaved;        // the default's PlayerViewOffset before we touched it
var vector BobSavedSmall;   // ditto for SmallViewOffset (bSmallWeapons reads it)
var vector BobSavedOld;     // ditto OldPlayerViewOffset (UTClassic / old mesh)
var vector BobSavedOldSm;   // ditto OldSmallViewOffset
var vector BobWrote;        // the offset we left standing for the draw
var vector BobDrawLoc;      // the weapon's Location at the moment we wrote it
var bool   bBobApplied;
var bool   bBobDrawn;       // the weapon actor moved between the write and the restore
var bool   bBobStomped;     // our value was gone again by the time we restored
var int    BobHUDCalls;     // applies driven by HUD.PostRender
var int    BobCtrlCalls;    // applies driven by Controller.RenderOverlays
var string BobDiag;         // why the last apply did nothing; movedebug shows it

// source viewmodel lag, ported from CBaseViewModel::CalcViewModelLag from Source SDK 2013

const MAX_VM_LAG = 1.5;         // g_fMaxViewModelLag, :459
const VM_LAG_SPEED = 5.0;       // flSpeed, :477
const VM_LAG_SCALE = 5.0;       // the offset multiplier at :492

var vector LagOffset;           // the finished offset, Source units, view space
var vector LastFacing;          // m_vecLastFacing
var bool   bLastFacingValid;    // LastFacing has been seeded
var float  LastLagTime;         // our stand-in for gpGlobals->frametime
var float  LagGap;              // flDiff: how far the gun's facing trails the view

// half-life hud yippie

var config bool bGoldSrcHud;
var config color HudColor;
var config float HudMinAlpha; // resting brightness. hud.h MIN_ALPHA is 100, mud on text
var config float HudScale;    // sits on top of the 480p scale, the whole row
var config int HudFontSize;   // 0..3, which canvas font the numbers use

const HL_FADE_TIME = 100.0;
const HL_FADE_RATE = 20.0;
const HL_CRIT_HEALTH = 15;

const HL_FONT_H = 25.0;
const HL_DIGIT_W = 20.0;
const HL_REF_HEIGHT = 480.0;
const HL_ICON_H = 40.0;
const HL_BAR_FRAC = 16.0; // health.cpp uses HealthWidth/10, thinner reads better here

var float HealthFade, ArmorFade, AmmoFade; // one per elem.
var int LastHealth, LastArmor, LastAmmo;   // what fade we're watching


var config bool bHitmarker;       // cl_hitmarker 1
var config bool bDamageNumbers;   // cl_dmgnumbers 1
var config color HitColor;        // normal hit
var config color KillColor;       // the killing blow

const HITMARKER_TIME  = 0.35;     // seconds the marker holds
const HITMARKER_GAP   = 7.0;      // inner gap of the X from center, pixels at 600p
const HITMARKER_LEN   = 9.0;      // arm length
const HITMARKER_THICK = 2.0;
const HITMARKER_STEPS = 12;       // steps per arm: 1-unit stair, reads as a smooth line
const HITMARKER_POP   = 0.09;     // seconds of expand "pop" before the fade takes over

const DMGNUM_TIME     = 1.1;      // lifetime of a floating number
const DMGNUM_RISE     = 34.0;     // units it climbs over that lifetime
const DMGNUM_DRIFT    = 12.0;     // sideways drift, per-instance jitter
const DMGNUM_MAX      = 8;        // simultaneously visible numbers

// One live damage number. Pooled array, oldest entry is recycled.
struct DmgNum
{
	var vector WorldLoc;   // where it spawned (world space, tracked so turning keeps it anchored)
	var int    Amount;     // damage dealt, rounded at draw time
	var int    Shield;     // the portion of it that went into the victim's shield
	var bool   bKill;      // red + bigger
	var float  SpawnTime;
	var float  DriftX;     // cached jitter, so the drift direction is stable
};

var DmgNum DmgNums[DMGNUM_MAX];

// Hitmarker state. Kills refresh the timer and switch the color.
var float HitTime;
var bool  HitKill;

var float HudFadeTime, AmmoFadeTime;       // stand-in for fps


// killfeed, damage-direction arrow ring, enemy HP bars, revenge marker,
// multikill pips, low-HP desaturation, death recap / killcam label, pickup
// respawn timers, custom scoreboard + stats panel, MVP card, spectator strip.
// All cl_-toggleable, all default on.

var config bool bKillfeed;
var config bool bArrowRing;       // replaces the HL pain wedges while on
var config bool bEnemyHPBar;
var config bool bRevengeMarker;
var config bool bMultikillPips;
var config bool bDeathRecap;
var config bool bPickupTimers;
var config bool bModernScoreboard; // replaces the stock board while Tab is held
var config bool bMVPCard;

var config color FeedColor;       // other players' kills
var config color MyFeedColor;     // kills we were part of
var config color FeedSelfColor;   // our own death
var config color ArrowColor;
var config color HPBarColor;
var config color ShieldBarColor;

const KILLFEED_MAX  = 6;
const KILLFEED_TIME = 6.0;
const ARROWS_MAX    = 4;
const ARROW_TIME    = 3.0;
const ARROW_RING_R  = 52.0;      // ring radius, px at 600p
const ARROW_STEPS   = 8;
const HPBAR_TIME    = 3.0;
const HPBAR_W       = 70.0;
const HPBAR_H       = 5.0;
const HPBAR_MAX     = 4;
const PICKUP_MAX    = 24;
const PICKUP_SCAN   = 0.5;       // seconds between pickup hidden/visible polls

struct KillFeedEntry
{
	var string Killer;
	var string Victim;
	var string Weapon;
	var bool   bSuicide;
	var bool   bMine;      // we were the killer or the victim
	var float  Time;
};

struct ArrowHit
{
	var vector Dir;        // world-space, player -> attacker, latched at hit time
	var float  Time;
};

struct HPTrackEntry
{
	var Pawn   Victim;
	var float  Time;       // last time we damaged them
};

struct PickupTrack
{
	var Pickup Pickup;
	var string Label;
	var float  HiddenSince; // 0 = sitting there visible
	var float  Respawn;     // its RespawnTime
};

var KillFeedEntry KillFeed[KILLFEED_MAX];
var ArrowHit      Arrows[ARROWS_MAX];
var HPTrackEntry  HPTracks[HPBAR_MAX];
var PickupTrack   PickupList[PICKUP_MAX];
var float         NextPickupScan;
var float         RJHeight, RJSpeed, RJTime;   // rocket-jump / boost stats popup


// Called by the player controller every time OUR shot lands on an enemy.
simulated function NoteEnemyHit(Pawn Victim, vector HitLocation, int Damage,
	int ShieldDamage, bool bKilled)
{	local int    i, Oldest;
	local float  BestAge;
	local vector HitLoc;

	if (Damage > 0)
	{
		HitTime  = Level.TimeSeconds;
		HitKill  = bKilled;
	}

	// Enemy HP bar: latch the victim so the bar can hang over their head for
	// a few seconds and fade. Same victim refreshes in place.
	if (Victim != None && bEnemyHPBar)
	{
		Oldest = -1;
		for (i = 0; i < HPBAR_MAX; i++)
		{
			if (HPTracks[i].Victim == Victim)
			{
				Oldest = i;
				break;
			}
			if (Oldest < 0 || Level.TimeSeconds - HPTracks[i].Time > Level.TimeSeconds - HPTracks[Oldest].Time)
				Oldest = i;
		}
		HPTracks[Oldest].Victim = Victim;
		HPTracks[Oldest].Time   = Level.TimeSeconds;
	}

	if (!bDamageNumbers || Damage <= 0)
		return;

	// Anchor the number just above the hit point, like every modern DM.
	HitLoc = HitLocation;
	HitLoc.Z += 20;

	// Recycle the oldest slot.
	for (i = 0; i < DMGNUM_MAX; i++)
	{
		if (DmgNums[i].Amount == 0)
		{
			Oldest = i;
			break;
		}
		if (Level.TimeSeconds - DmgNums[i].SpawnTime > BestAge)
		{
			BestAge = Level.TimeSeconds - DmgNums[i].SpawnTime;
			Oldest  = i;
		}
	}

	DmgNums[Oldest].WorldLoc  = HitLoc;
	DmgNums[Oldest].Amount    = Damage;
	DmgNums[Oldest].Shield    = Clamp(ShieldDamage, 0, Damage);
	DmgNums[Oldest].bKill     = bKilled;
	DmgNums[Oldest].SpawnTime = Level.TimeSeconds;
	// Pseudo-jitter from the location: no Math.random-style calls exist on
	// HUD, and a hash of the position is as good as anything for spread.
	DmgNums[Oldest].DriftX    = ((HitLocation.X + HitLocation.Y) % 7 - 3) * (DMGNUM_DRIFT / 3.0);
}

// True if a world point is actually in front of the camera. WorldToScreen
// alone is not enough on this build: points behind the camera come back
// mirrored with a positive Z, so a naive Z check lets them draw -- that was
// the "revenge marker / pickup timer visible when I look away" bug.
simulated final function bool IsInFront(canvas Canvas, vector WorldLoc)
{
	local vector  CamLoc, CamDir;
	local rotator CamRot;

	Canvas.GetCameraLocation(CamLoc, CamRot);
	CamDir = vector(CamRot);
	return (WorldLoc - CamLoc) dot CamDir > 0.0;
}

simulated final function DrawHitmarker(canvas Canvas)
{
	local float CX, CY, Scale, Alpha, Age, Grow, Dist, StepAlpha, Thick;
	local int   i, SgnX, SgnY, Arm;
	local color C;

	Age = Level.TimeSeconds - HitTime;
	if (Age > HITMARKER_TIME)
		return;

	CX    = Canvas.ClipX * 0.5;
	CY    = Canvas.ClipY * 0.5;
	Scale = FMax(Canvas.ClipY / 600.0, 0.5);

	if (HitKill)
		C = KillColor;
	else
		C = HitColor;

	// Pop: the marker snaps in slightly oversized and settles to rest during
	// the first HITMARKER_POP seconds, then the whole thing fades out.
	Alpha = 1.0 - Age / HITMARKER_TIME;
	Grow  = 1.0;
	if (Age < HITMARKER_POP)
		Grow = 1.0 + 0.5 * Square(1.0 - Age / HITMARKER_POP);

	Thick = HITMARKER_THICK * Scale;
	if (HitKill)
		Thick *= 1.35;

	// The engine's DrawRect is axis-aligned only, so each diagonal arm of the
	// X is built as a stair of tiny squares. HITMARKER_STEPS 1-unit steps with
	// an alpha taper toward the tip read as a thin anti-aliased line at any
	// resolution -- no visible pixel staircase.
	for (Arm = 0; Arm < 4; Arm++)
	{
		if (Arm == 0)      { SgnX =  1; SgnY =  1; }
		else if (Arm == 1) { SgnX = -1; SgnY =  1; }
		else if (Arm == 2) { SgnX =  1; SgnY = -1; }
		else               { SgnX = -1; SgnY = -1; }

		for (i = 0; i < HITMARKER_STEPS; i++)
		{
			// 0 at the inner gap, 1 at the arm tip.
			Dist = (HITMARKER_GAP + HITMARKER_LEN * float(i) / float(HITMARKER_STEPS - 1))
			       * Scale * Grow;

			// Taper: full brightness at the base, ~25% at the tip -- this is
			// what sells it as a line instead of a row of blocks.
			StepAlpha = Alpha * (1.0 - 0.75 * float(i) / float(HITMARKER_STEPS - 1));

			Canvas.SetDrawColor(C.R, C.G, C.B, int(255.0 * StepAlpha));
			Canvas.SetPos(CX + SgnX * Dist - Thick * 0.5,
			              CY + SgnY * Dist - Thick * 0.5);
			Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', Thick, Thick);
		}
	}

	// Kill confirmation: a filled dot in the middle of the X.
	if (HitKill)
	{
		Canvas.SetDrawColor(C.R, C.G, C.B, int(255.0 * Alpha));
		Canvas.SetPos(CX - Thick, CY - Thick);
		Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', Thick * 2.0, Thick * 2.0);
	}
}

simulated final function DrawDamageNumbers(canvas Canvas)
{
	local int    i;
	local float  Age, Fade, XL, YL;
	local vector Screen;
	local string S;

	for (i = 0; i < DMGNUM_MAX; i++)
	{
		if (DmgNums[i].Amount <= 0)
			continue;

		Age = Level.TimeSeconds - DmgNums[i].SpawnTime;
		if (Age > DMGNUM_TIME)
		{
			DmgNums[i].Amount = 0;
			continue;
		}

		Screen = Canvas.WorldToScreen(DmgNums[i].WorldLoc);
		if (Screen.Z <= 0.0 || !IsInFront(Canvas, DmgNums[i].WorldLoc))
			continue;   // behind us

		Fade = 1.0 - Age / DMGNUM_TIME;

		S = string(DmgNums[i].Amount);
		Canvas.Font = Canvas.MedFont;
		Canvas.TextSize(S, XL, YL);

		Canvas.SetPos(Screen.X - XL * 0.5 + DmgNums[i].DriftX * Age / DMGNUM_TIME,
		              Screen.Y - YL * 0.5 - DMGNUM_RISE * Age / DMGNUM_TIME);

		if (DmgNums[i].bKill)
			Canvas.SetDrawColor(KillColor.R, KillColor.G, KillColor.B, int(255 * Fade));
		else
			Canvas.SetDrawColor(HitColor.R, HitColor.G, HitColor.B, int(200 * Fade));

		Canvas.DrawText(S);

		// Shield split: the part that went into the shield rides under the
		// number in the shield color, so "42 / +15 shield" reads at a glance.
		if (DmgNums[i].Shield > 0)
		{
			S = "+" $ string(DmgNums[i].Shield);
			Canvas.Font = Canvas.SmallFont;
			Canvas.TextSize(S, XL, YL);
			Canvas.SetPos(Screen.X - XL * 0.5 + DmgNums[i].DriftX * Age / DMGNUM_TIME,
			              Screen.Y + YL * 0.25 - DMGNUM_RISE * Age / DMGNUM_TIME);
			Canvas.SetDrawColor(ShieldBarColor.R, ShieldBarColor.G, ShieldBarColor.B, int(200 * Fade));
			Canvas.DrawText(S);
		}
	}
}

// the first person weapon is drawn from inside HUD.PostRender (CanvasDrawActors)
// so the bob is applied there, and the sway is applied in
// Controller.RenderOverlays, so both are bracketed around the draw and can write
// to the viewmodel's PlayerViewOffset safely

simulated event PostRender(canvas Canvas)
{
	local Scoreboard SavedBoard;

	BobHUDCalls++;
	ApplyViewModelBob();

	// While our modern scoreboard is up, the stock board must not draw
	// underneath it. The engine draws HUD.ScoreBoard directly when
	// bShowScoreBoard is set, so park the actor for the duration of the pass.
	if (bModernScoreboard && bShowScoreBoard)
	{
		SavedBoard = ScoreBoard;
		ScoreBoard = None;
		Super.PostRender(Canvas);
		ScoreBoard = SavedBoard;
	}
	else
		Super.PostRender(Canvas);

	RestoreViewModelBob();
}

simulated final function ApplyViewModelBob()
{
	local GoldSrcPlayer GP;
	local Pawn P;
	local Weapon W;

	// left over from the last frame, if any, and the one that will be restored after the draw
	if (bBobApplied)
		RestoreViewModelBob();

	GP = GoldSrcPlayer(PlayerOwner);
	if (GP == None)
	{
		BobBail("no GoldSrcPlayer");
		return;
	}

	if (GP.Move == None)
	{
		BobBail("no Move");
		return;
	}

	// Both knobs off still has to fall through while a stair step is being smoothed
	// out: that offset is not decoration, it is what keeps the gun from drifting
	// away from a camera the movement code just lowered.
	if (!GP.bViewModelBob && !GP.bViewModelSway && GP.StepSmoothShift == 0.0)
	{
		BobBail("off (cl_viewmodelbob 0, cl_viewmodelsway 0)");
		return;
	}

	// third person draws the pawn and not the viewmodel, so the bob is irrelevant
	if (GP.bBehindView)
	{
		BobBail("third person");
		return;
	}

	// viewtarget first, because the pawn can be None if the player is dead or in a camera
	P = Pawn(GP.ViewTarget);
	if (P == None)
		P = GP.Pawn;

	if (P == None)
	{
		BobBail("no pawn");
		return;
	}

	if (P.Weapon == None)
	{
		BobBail("no weapon");
		return;
	}
	W = P.Weapon;

	BobWeapon  = W;
	BobPawn    = P;
	BobDrawLoc = W.Location;

	// Weapon.RenderOverlays rebuilds PlayerViewOffset out of the CLASS DEFAULT
	// every frame (Weapon.uc:919-924: "PlayerViewOffset = Default.PlayerViewOffset"
	// -- or SmallViewOffset when bSmallWeapons is on, or OldPlayerViewOffset when
	// the weapon is in old-mesh/UTClassic mode), so writing the instance's
	// offset is discarded before the draw ever reads it. The write has to go to
	// the default object instead, bracketed by this apply and the restore below;
	// nothing else observes the class default inside that bracket but this
	// weapon's own RenderOverlays.
	//
	// The SmallViewOffset and OldPlayerViewOffset branches, however, read the
	// INSTANCE, which is only re-synced from the default on a hand change -- so
	// those two also get written on the instance itself, with the same delta,
	// or those weapons would draw with no bob at all.
	BobSaved         = W.Default.PlayerViewOffset;
	BobSavedSmall    = W.Default.SmallViewOffset;
	BobSavedOld      = W.Default.OldPlayerViewOffset;
	BobSavedOldSm    = W.Default.OldSmallViewOffset;
	BobWrote         = BobSaved + ViewModelOffset(GP, P, W);

	W.Default.PlayerViewOffset    = BobWrote;
	W.Default.SmallViewOffset     = BobSavedSmall + (BobWrote - BobSaved);
	W.Default.OldPlayerViewOffset = BobSavedOld + (BobWrote - BobSaved);
	W.Default.OldSmallViewOffset  = BobSavedOldSm + (BobWrote - BobSaved);

	// Instance side of the small/old-mesh branches. SmallViewOffset is skipped
	// when its default is zero: Weapon.uc:885-886 makes a zero default mean
	// "use PlayerViewOffset instead", and hard-writing zero would undo that.
	W.PlayerViewOffset    = BobWrote;
	W.OldPlayerViewOffset = W.Default.OldPlayerViewOffset;
	W.OldSmallViewOffset  = W.Default.OldSmallViewOffset;
	if (BobSavedSmall != vect(0,0,0))
		W.SmallViewOffset = W.Default.SmallViewOffset;

	bBobApplied = True;
	BobBail("applied");
}

// Why the last apply did nothing. Read back by movedebug; deliberately does no
// logging of its own -- this runs on every rendered frame, and the version that
// wrote a line whenever the reason changed could be provoked into writing to
// UT2004.log at frame rate, which is a disk hit inside the render path.

simulated final function BobBail(string Why)
{
	BobDiag = Why;
}

simulated final function RestoreViewModelBob()
{
	local vector Now;

	if (!bBobApplied)
		return;

	if (BobWeapon != None)
	{
		Now = BobWeapon.Default.PlayerViewOffset;

		bBobDrawn   = (BobWeapon.Location != BobDrawLoc);
		// The stomp test watches the CLASS DEFAULT now, which Weapon.RenderOverlays
		// rewrites from Default itself -- so if ours survived the draw untouched
		// the read-back is still exactly what we wrote.
		bBobStomped = (VSize(Now - BobWrote) > 0.001);

		BobWeapon.Default.PlayerViewOffset    = BobSaved;
		BobWeapon.Default.SmallViewOffset     = BobSavedSmall;
		BobWeapon.Default.OldPlayerViewOffset = BobSavedOld;
		BobWeapon.Default.OldSmallViewOffset  = BobSavedOldSm;

		BobWeapon.PlayerViewOffset    = BobSaved;
		BobWeapon.OldPlayerViewOffset = BobSavedOld;
		BobWeapon.OldSmallViewOffset  = BobSavedOldSm;
		if (BobSavedSmall != vect(0,0,0))
			BobWeapon.SmallViewOffset = BobSavedSmall;
	}

	BobWeapon   = None;
	BobPawn     = None;
	bBobApplied = False;
}


// lowkey this is where the bob is calculated, but the actual application is in ApplyViewModelBob and the restoration is in RestoreViewModelBob.
// the bob is calculated every frame, but only applied if the weapon is drawn and the player is in first person.

simulated final function CalcViewModelBob(GoldSrcPlayer GP, Pawn P)
{
	local vector v;
	local float speed, bob_offset, cycle, dt;

	dt = Level.TimeSeconds - LastBobTime;

	if (dt <= 0.0)
		return;

	dt          = FMin(dt, 0.1);
	LastBobTime = Level.TimeSeconds;

	// find the speed of the player
	v   = P.Velocity;
	v.Z = 0;
	speed = VSize(v) / FMax(GP.Move.WorldScale, 0.0001);    // -> to hammer units

	speed = FClamp(speed, -320, 320);

	bob_offset = speed / 320.0;         // RemapVal( speed, 0, 320, 0.0f, 1.0f )

	BobTime += dt * bob_offset;

	// calc the vertical bob
	cycle = BobTime - int(BobTime / HL2_BOB_CYCLE_MAX) * HL2_BOB_CYCLE_MAX;
	cycle /= HL2_BOB_CYCLE_MAX;

	if (cycle < HL2_BOB_UP)
		cycle = BOB_PI * cycle / HL2_BOB_UP;
	else
		cycle = BOB_PI + BOB_PI * (cycle - HL2_BOB_UP) / (1.0 - HL2_BOB_UP);

	VerticalBob = speed * 0.005;
	VerticalBob = VerticalBob * 0.3 + VerticalBob * 0.7 * Sin(cycle);

	VerticalBob = FClamp(VerticalBob, -7.0, 4.0);

	// calc the lateral bob
	cycle = BobTime - int((BobTime / HL2_BOB_CYCLE_MAX) * 2) * (HL2_BOB_CYCLE_MAX * 2);
	cycle /= (HL2_BOB_CYCLE_MAX * 2);

	if (cycle < HL2_BOB_UP)
		cycle = BOB_PI * cycle / HL2_BOB_UP;
	else
		cycle = BOB_PI + BOB_PI * (cycle - HL2_BOB_UP) / (1.0 - HL2_BOB_UP);

	LateralBob = speed * 0.005;
	LateralBob = LateralBob * 0.3 + LateralBob * 0.7 * Sin(cycle);
	LateralBob = FClamp(LateralBob, -7.0, 4.0);
}

// translation of CBaseHLCombatWeapon::CalcViewmodelBob, basehlcombatweapon_shared.cpp:235

simulated final function vector ViewModelBobOffset(GoldSrcPlayer GP)
{
	local vector Bob;

	Bob.X = VerticalBob * 0.1;
	Bob.Y = LateralBob  * 0.8;
	Bob.Z = VerticalBob * 0.1;

	// bob is calculated in hammer units, but the viewmodel is drawn in world units, so scale it down to world units before returning it
	return Bob * GP.ViewModelBobScale * GP.Move.WorldScale;
}

simulated final function CalcViewModelLag(GoldSrcPlayer GP, Pawn P)
{
	local rotator ViewRot;
	local vector  Fwd, Rgt, Up, Diff;
	local float   dt, Speed, Len, PitchDeg;

	dt = Level.TimeSeconds - LastLagTime;

	// same reasoning as in CalcViewModelBob ## if the frame time is zero or negative, the viewmodel is not moving and there is no lag to calculate.
	if (dt <= 0.0)
		return;

	ViewRot = P.GetViewRotation();
	GetAxes(ViewRot, Fwd, Rgt, Up);

	if (!bLastFacingValid || dt > 0.25)
	{
		LastFacing       = Fwd;
		bLastFacingValid = True;
		LastLagTime      = Level.TimeSeconds;
		LagOffset        = vect(0,0,0);
		LagGap           = 0.0;
		return;
	}

	dt          = FMin(dt, 0.1);
	LastLagTime = Level.TimeSeconds;

	Diff = Fwd - LastFacing;

	Speed = VM_LAG_SPEED;

	Len = VSize(Diff);
	LagGap = Len;

	if (Len > MAX_VM_LAG && MAX_VM_LAG > 0.0)
		Speed *= Len / MAX_VM_LAG;

	LastFacing = Normal(LastFacing + Diff * (Speed * dt));

	LagOffset.X = -VM_LAG_SCALE * (Diff Dot Fwd);
	LagOffset.Y = -VM_LAG_SCALE * (Diff Dot Rgt);
	LagOffset.Z = -VM_LAG_SCALE * (Diff Dot Up);

	if (!GP.bViewModelSwayPitch)
		return;

	// the DROOOOOOOPY
	PitchDeg = (ViewRot.Pitch & 65535) * 360.0 / 65536.0;
	if (PitchDeg > 180.0)
		PitchDeg -= 360.0;

	LagOffset.X += PitchDeg * 0.035;
	LagOffset.Y += PitchDeg * 0.03;
	LagOffset.Z += PitchDeg * 0.02;
}

// sway finished offset
simulated final function vector ViewModelLagOffset(GoldSrcPlayer GP)
{
	return LagOffset * GP.ViewModelSwayScale * GP.Move.WorldScale;
}

// The gun half of the stair-step smoothing:  view->origin[2] += oldz - simorg[2]
// (cl_dll/view.cpp:714). GoldSrcPlayer.CalcFirstPersonView has already done the
// camera half and left the shift in StepSmoothShift.
//
// Valve moves the camera and the view model by the same amount, so the gun holds
// still on screen while the origin climbs. UT2004 places the viewmodel off the
// weapon's own draw path (Weapon.RenderOverlays reads PlayerViewOffset), which
// the camera shift never reaches, so doing only the camera half leaves the gun
// behind and it reads as the gun floating up out of the frame. That is the bug
// this closes.
//
// PlayerViewOffset is a view-space offset, and UT2004's Weapon.RenderOverlays
// spends it rotated by the view rotation and scaled by a 0.9/DisplayFOV factor,
// so to land a world delta of exactly StepSmoothShift on Z it has to be
// unrotated into view space and pre-divided by that factor. Both halves matter:
// the view is nearly always pitched somewhere while climbing stairs, and
// DisplayFOV is per weapon.
simulated final function vector ViewModelStepOffset(GoldSrcPlayer GP, Pawn P, Weapon W)
{
	local vector WorldShift;
	local float  FOVScale;

	if (GP.StepSmoothShift == 0.0 || W == None || P == None)
		return vect(0,0,0);

	WorldShift.Z = GP.StepSmoothShift;

	FOVScale = 1.0;
	if (W.DisplayFOV > 0.0)
		FOVScale = W.DisplayFOV / 90.0;

	return (WorldShift << P.GetViewRotation()) * FOVScale;
}

simulated final function vector ViewModelOffset(GoldSrcPlayer GP, Pawn P, Weapon W)
{
	local vector Ofs;

	if (GP.bViewModelBob)
	{
		CalcViewModelBob(GP, P);
		Ofs += ViewModelBobOffset(GP);
	}

	if (GP.bViewModelSway)
	{
		CalcViewModelLag(GP, P);
		Ofs += ViewModelLagOffset(GP);
	}
	else
	{

		bLastFacingValid = False;
		LagOffset        = vect(0,0,0);
		LagGap           = 0.0;
	}

	// Not decoration like the two above -- this one only holds the gun still
	// against a camera the movement code moved, so it is not gated on either knob.
	Ofs += ViewModelStepOffset(GP, P, W);

	return Ofs;
}

// The stock passes draw health/ammo/shield widgets; when the HL row is on, draw
// ours instead of theirs by hiding the stock personal info for the pass.
simulated function DrawHudPassA(Canvas C)
{
	local bool bOldWeaponInfo, bOldPersonalInfo;

	if (bGoldSrcHud)
	{
		bOldWeaponInfo   = bShowWeaponInfo;
		bOldPersonalInfo = bShowPersonalInfo;
		bShowWeaponInfo  = false;
		bShowPersonalInfo = false;

		Super.DrawHudPassA(C);

		bShowWeaponInfo   = bOldWeaponInfo;
		bShowPersonalInfo = bOldPersonalInfo;
		return;
	}

	Super.DrawHudPassA(C);
}

simulated function DrawHud(Canvas C)
{
	Super.DrawHud(C);

	// draw ours last so it sits on top of the stock HUD.
	DrawGoldSrcOverlay(C);
}

simulated final function DrawGoldSrcOverlay(canvas Canvas)
{
	local GoldSrcPlayer GP;
	local GoldSrcMovement M;

	GP = GoldSrcPlayer(PlayerOwner);
	if (GP == None)
		return;

	UpdateFps();

	if (GP.bShowNetGraph)
		DrawNetGraph(Canvas);

	if (GP.bShowPos)
		DrawShowPos(Canvas, GP.Move);

	// Before the Move check below: a hit lands the same whether or not the
	// simulation is the thing that's driving. The modern arrow ring replaces
	// the ported HL wedges while it is on; cl_damageindicator still gates both.
	if (GP.bDamageIndicator && !bArrowRing)
		DrawPain(Canvas);

	// Combat feedback rides on top of everything, crosshair included.
	if (bDamageNumbers)
		DrawDamageNumbers(Canvas);

	if (bHitmarker)
		DrawHitmarker(Canvas);

	if (bArrowRing && GP.bDamageIndicator)
		DrawArrowRing(Canvas);

	if (bKillfeed)
		DrawKillfeed(Canvas);

	if (bEnemyHPBar)
		DrawEnemyHPBar(Canvas);

	if (bRevengeMarker)
		DrawRevengeMarker(Canvas, GP);

	if (bMultikillPips)
		DrawMultikillPips(Canvas, GP);

	if (bPickupTimers)
		DrawPickupTimers(Canvas);

	DrawDeathRecap(Canvas, GP);
	DrawRJPopup(Canvas, GP);

	M = GP.Move;
	if (M == None)
		return;

	// track accel for readout
	UpdateAccel(M);

	if (GP.bShowSpeedometer)
		DrawSpeedometer(Canvas, M);

	if (bShowVelocityGraph && GP.bShowSpeedometer)
		DrawVelocityGraph(Canvas, M);

	if (GP.bShowMoveDebug)
		DrawMoveDebug(Canvas, M);

	// the HL bottom row rides on the overlay so it lands above everything
	if (bGoldSrcHud && !bHideHud)
	{
		HudFadeTime = Level.TimeSeconds;
		DrawGoldSrcHealth(Canvas, FClamp(Level.TimeSeconds - HudFadeTime, 0.0, 0.1));
		DrawGoldSrcArmor(Canvas, FClamp(Level.TimeSeconds - HudFadeTime, 0.0, 0.1));
		DrawGoldSrcAmmo(Canvas);
	}

	// Full-screen panels go on top of absolutely everything.
	DrawScorePanel(Canvas);
	DrawMVPCard(Canvas);
}

simulated final function ClearDamageDirection()
{
	AttackFront = 0;
	AttackRear  = 0;
	AttackLeft  = 0;
	AttackRight = 0;
}

// CHudHealth::CalcDamageDirection    (cl_dll/health.cpp:234)
//
// Valve's locals read oddly: `front` is the dot with RIGHT and `side` is the dot
// with FORWARD. The names are crossed, the arithmetic under them is not, and it is
// transcribed as written rather than tidied so the two files still diff.
simulated final function CalcDamageDirection(vector vecFrom, vector vecOrigin, rotator vecAngles)
{
	local vector forward, right, up;
	local float  side, front, f;
	local float  flDistToTarget;

	if (vecFrom == vect(0,0,0))
	{
		ClearDamageDirection();
		return;
	}

	vecFrom = vecFrom - vecOrigin;

	flDistToTarget = VSize(vecFrom);

	vecFrom = Normal(vecFrom);
	GetAxes(vecAngles, forward, right, up);

	front = vecFrom Dot right;
	side  = vecFrom Dot forward;

	if (flDistToTarget <= PAIN_NEAR_DIST)
	{
		// Close enough that there is no useful direction: light all four.
		AttackFront = 1;
		AttackRear  = 1;
		AttackRight = 1;
		AttackLeft  = 1;
		return;
	}

	if (side > 0)
	{
		if (side > PAIN_THRESHOLD)
			AttackFront = FMax(AttackFront, side);
	}
	else
	{
		f = Abs(side);
		if (f > PAIN_THRESHOLD)
			AttackRear = FMax(AttackRear, f);
	}

	if (front > 0)
	{
		if (front > PAIN_THRESHOLD)
			AttackRight = FMax(AttackRight, front);
	}
	else
	{
		f = Abs(front);
		if (f > PAIN_THRESHOLD)
			AttackLeft = FMax(AttackLeft, f);
	}
}

// CHudHealth::GetPainColor    (cl_dll/health.cpp:143)
//
// Valve keeps a health-scaled gradient in there behind an #if 0 and ships the
// two-colour version, so that is what this is.
simulated final function color GetPainColor()
{
	local color C;
	local int   iHealth;

	iHealth = 100;
	if (PlayerOwner != None && PlayerOwner.Pawn != None)
		iHealth = PlayerOwner.Pawn.Health;

	if (iHealth > 25)
		return PainColor;

	C.R = 250;
	C.G = 0;
	C.B = 0;
	return C;
}

// CHudHealth::DrawPain    (cl_dll/health.cpp:293)
//
// Every placement here is Valve's, spelled in units of the sprite it no longer
// has: the wedges sit two of their own short sides out from the crosshair. Valve
// draws them additively with the colour pre-scaled by the shade; a canvas tile
// blends on alpha instead, so the shade is carried there and the colour left alone.
simulated final function DrawPain(canvas Canvas)
{
	local float fFade, S, W, H, CX, CY;
	local color C;
	local int   a, shade;

	if (AttackFront == 0 && AttackRear == 0 && AttackLeft == 0 && AttackRight == 0)
	{
		PainLastTime = Level.TimeSeconds;
		return;
	}

	// TODO:  get the shift value of the health
	a = 255;    // max brightness until then

	// Clamped, or one loading screen's worth of elapsed time would swallow the
	// whole indicator before its first frame is drawn.
	fFade        = FClamp(Level.TimeSeconds - PainLastTime, 0.0, 1.0) * PAIN_FADE_RATE;
	PainLastTime = Level.TimeSeconds;

	S  = Canvas.ClipY / PAIN_REF_HEIGHT;
	W  = PAIN_SPR_W * S;
	H  = PAIN_SPR_H * S;
	CX = Canvas.ClipX * 0.5;
	CY = Canvas.ClipY * 0.5;

	C = GetPainColor();

	// SPR_Draw top
	if (AttackFront > PAIN_MIN_DRAW)
	{
		shade = int(a * FMax(AttackFront, PAIN_MIN_SHADE));
		DrawPainWedge(Canvas, CX - W * 0.5, CY - H * 3, W, H, 0, C, shade);
		AttackFront = FMax(0, AttackFront - fFade);
	}
	else
		AttackFront = 0;

	if (AttackRight > PAIN_MIN_DRAW)
	{
		shade = int(a * FMax(AttackRight, PAIN_MIN_SHADE));
		DrawPainWedge(Canvas, CX + H * 2, CY - W * 0.5, H, W, 1, C, shade);
		AttackRight = FMax(0, AttackRight - fFade);
	}
	else
		AttackRight = 0;

	if (AttackRear > PAIN_MIN_DRAW)
	{
		shade = int(a * FMax(AttackRear, PAIN_MIN_SHADE));
		DrawPainWedge(Canvas, CX - W * 0.5, CY + H * 2, W, H, 2, C, shade);
		AttackRear = FMax(0, AttackRear - fFade);
	}
	else
		AttackRear = 0;

	if (AttackLeft > PAIN_MIN_DRAW)
	{
		shade = int(a * FMax(AttackLeft, PAIN_MIN_SHADE));
		DrawPainWedge(Canvas, CX - H * 3, CY - W * 0.5, H, W, 3, C, shade);
		AttackLeft = FMax(0, AttackLeft - fFade);
	}
	else
		AttackLeft = 0;
}

// more color stuff

simulated final function color ScaleHudColors(color C, float a)
{
	local color Out;

	Out.R = int(float(C.R) * a / 255.0);
	Out.G = int(float(C.G) * a / 255.0);
	Out.B = int(float(C.B) * a / 255.0);
	Out.A = 255;
	return Out;
}


simulated final function float HudFlashAlpha(out float Fade, out int Last, int Value, float Delta)
{
	local float Floor;

	Floor = FClamp(HudMinAlpha, 0.0, 255.0);

	if (Value != Last)
	{
		Last = Value;
		Fade = HL_FADE_TIME;
	}

	if (Fade <= 0.0)
		return Floor;

	Fade -= Delta * HL_FADE_RATE;
	if (Fade < 0.0)
		Fade = 0.0;

	return Floor + (Fade / HL_FADE_TIME) * (255.0 - Floor);
}

simulated final function float HudRowScale(canvas Canvas)
{
	return (Canvas.ClipY / HL_REF_HEIGHT) * FMax(HudScale, 0.1);
}

// health.cpp:213, y = ScreenHeight - m_iFontHeight - m_iFontHeight / 2
simulated final function float HudRowY(canvas Canvas)
{
	return Canvas.ClipY - HL_FONT_H * 1.5 * HudRowScale(Canvas);
}

// which canvas font the HL row's numbers use, by the HudFontSize knob
simulated final function font HudRowFont(canvas Canvas)
{
	switch (HudFontSize)
	{
		case 0:  return Canvas.TinyFont;
		case 1:  return Canvas.SmallFont;
		case 2:  return Canvas.MedFont;
	}
	return Canvas.MedFont;
}

// right-aligned plain text, standing in for Postal's FontInfo.DrawTextEx
simulated final function DrawRightAligned(canvas Canvas, float Right, float Y, string S, color C)
{
	local float XL, YL;
	local font  OldFont;
	local color OldColor;
	local byte  OldStyle;

	OldFont  = Canvas.Font;
	OldColor = Canvas.DrawColor;
	OldStyle = Canvas.Style;

	Canvas.Font       = HudRowFont(Canvas);
	Canvas.Style      = ERenderStyle.STY_Normal;
	Canvas.FontScaleX = 1.0;
	Canvas.FontScaleY = 1.0;

	Canvas.StrLen(S, XL, YL);

	Canvas.SetDrawColor(0, 0, 0, 170);
	Canvas.SetPos(Right - XL + 1, Y + 1);
	Canvas.DrawText(S, false);

	Canvas.SetDrawColor(C.R, C.G, C.B, C.A);
	Canvas.SetPos(Right - XL, Y);
	Canvas.DrawText(S, false);

	Canvas.Font       = OldFont;
	Canvas.DrawColor  = OldColor;
	Canvas.Style      = ERenderStyle(OldStyle);
}

simulated final function DrawHudDivider(canvas Canvas, float X, float Y, float S, color C)
{
	Canvas.Style = ERenderStyle.STY_Normal;
	Canvas.SetDrawColor(C.R, C.G, C.B, 255);
	Canvas.SetPos(X, Y);
	Canvas.DrawTile(Texture'engine.WhiteSquareTexture',
			FMax(HL_DIGIT_W * S / HL_BAR_FRAC, 1.0), HL_FONT_H * S, 0, 0, 1, 1);
}

// Valve's health cross, built out of two bars since there is no sprite to tile.
simulated final function DrawHealthCross(canvas Canvas, float X, float Y, float H, int Health)
{
	local float Arm;
	local color C;

	Arm = H * 0.3;

	// health.cpp's colour ramp: green to red as health falls
	if (Health > 25)
	{
		C.R = 155 + Health;
		C.G = 55 + Health * 2;
		C.B = 55 + Health * 2;
	}
	else
	{
		C.R = 250;
		C.G = 0;
		C.B = 0;
	}

	Canvas.Style = ERenderStyle.STY_Normal;
	Canvas.SetDrawColor(C.R, C.G, C.B, 255);

	Canvas.SetPos(X + (H - Arm) * 0.5, Y);
	Canvas.DrawTile(Texture'engine.WhiteSquareTexture', Arm, H, 0, 0, 1, 1);

	Canvas.SetPos(X, Y + (H - Arm) * 0.5);
	Canvas.DrawTile(Texture'engine.WhiteSquareTexture', H, Arm, 0, 0, 1, 1);
}

// battery.cpp: the battery sits at ScreenWidth/5 on the same row, its number right
// after the icon, no divider
simulated final function DrawGoldSrcArmor(canvas Canvas, float Delta)
{
	local int    UseArmor;
	local float  X, Y, S, a;
	local xPawn  XP;

	if (PawnOwner == None)
		return;

	XP = xPawn(PawnOwner);
	if (XP == None)
		return;

	UseArmor = int(XP.ShieldStrength);
	if (UseArmor <= 0)
		return;

	S = HudRowScale(Canvas);
	Y = HudRowY(Canvas);
	X = Canvas.ClipX / 5.0;

	a = HudFlashAlpha(ArmorFade, LastArmor, UseArmor, Delta);

	// Valve's battery: a filled box, narrower than the health cross
	DrawHudDivider(Canvas, X, Y, S, ScaleHudColors(HudColor, a));

	DrawRightAligned(Canvas, X + HL_ICON_H * S + HL_DIGIT_W * S * 3.0, Y,
		""$UseArmor, ScaleHudColors(HudColor, a));
}

// health.cpp: the cross then the number then the divider bar
simulated final function DrawGoldSrcHealth(canvas Canvas, float Delta)
{
	local int   UseHealth;
	local float Y, S, a, SlotW, NumRight;

	if (PawnOwner == None)
		return;

	S = HudRowScale(Canvas);
	Y = HudRowY(Canvas);

	UseHealth = PawnOwner.Health;

	if (UseHealth == 0 && PawnOwner.Health > 0)
		UseHealth = 1;

	a = HudFlashAlpha(HealthFade, LastHealth, UseHealth, Delta);
	if (UseHealth <= HL_CRIT_HEALTH)
		a = 255.0;

	SlotW = HL_ICON_H * S;

	DrawHealthCross(Canvas, 0.0, Y + (HL_FONT_H * S - SlotW) * 0.5, SlotW, UseHealth);

	// three digits, right aligned, so it grows leftward like Valve's number sprites
	NumRight = SlotW * 1.2 + HL_DIGIT_W * S * 3.0;

	DrawRightAligned(Canvas, NumRight, Y, ""$UseHealth, ScaleHudColors(HudColor, a));
	DrawHudDivider(Canvas, NumRight + HL_DIGIT_W * S * 0.5, Y, S, ScaleHudColors(HudColor, a));
}

// ammo.cpp: bottom right, the reserve then the icon. UT2004 weapons have no
// reload clips, so it is the reserve count only, right aligned.
simulated final function DrawGoldSrcAmmo(canvas Canvas)
{
	local string ResStr;
	local float  Y, S, a, Delta, DigitW, ResRight;
	local float  MaxAmmo, CurAmmo;
	local color  C;
	local class<Ammunition> AmmoClass;
	local Texture Tex;
	local float  IconW, IconH, U, V, UL, VL;

	if (PawnOwner == None || PawnOwner.Weapon == None)
		return;

	PawnOwner.Weapon.GetAmmoCount(MaxAmmo, CurAmmo);

	ResStr = ""$CurAmmo;
	if (MaxAmmo > 0 && CurAmmo != MaxAmmo)
		ResStr = ResStr$"/"$MaxAmmo;

	S      = HudRowScale(Canvas);
	Y      = HudRowY(Canvas);
	DigitW = HL_DIGIT_W * S;

	Delta = FClamp(Level.TimeSeconds - AmmoFadeTime, 0.0, 0.1);
	AmmoFadeTime = Level.TimeSeconds;
	a = HudFlashAlpha(AmmoFade, LastAmmo, CurAmmo, Delta);
	C = ScaleHudColors(HudColor, a);

	ResRight = Canvas.ClipX - DigitW;

	DrawRightAligned(Canvas, ResRight, Y, ResStr, C);

	// the ammo type's own icon, if it has one. IconCoords is (0,0,0,0) when the
	// ammo class never set one, so a whole-icon tile is drawn for those.
	AmmoClass = PawnOwner.Weapon.GetAmmoClass(0);
	if (AmmoClass != None && AmmoClass.default.IconMaterial != None)
	{
		IconW = HL_ICON_H * S;

		if (AmmoClass.default.IconCoords.X2 > AmmoClass.default.IconCoords.X1
			|| AmmoClass.default.IconCoords.Y2 > AmmoClass.default.IconCoords.Y1)
		{
			U  = AmmoClass.default.IconCoords.X1;
			V  = AmmoClass.default.IconCoords.Y1;
			UL = AmmoClass.default.IconCoords.X2 - AmmoClass.default.IconCoords.X1;
			VL = AmmoClass.default.IconCoords.Y2 - AmmoClass.default.IconCoords.Y1;
		}
		else
		{
			U  = 0;
			V  = 0;
			UL = 0;
			VL = 0;

			// no coords: stretch whatever the material is into the icon slot.
			// A material is not necessarily a texture, so read the size when it
			// is one and otherwise settle for a whole-material tile.
			Tex = Texture(AmmoClass.default.IconMaterial);
			if (Tex != None)
			{
				UL = Tex.USize;
				VL = Tex.VSize;
			}
		}

		if (UL > 0 && VL > 0)
		{
			// keep the icon's own aspect, fitted inside the slot
			IconH = HL_ICON_H * S;
			if (UL > VL)
			{
				IconW = IconH;
				IconH = IconH * VL / UL;
			}
			else
				IconW = IconH * UL / VL;

			Canvas.Style = ERenderStyle.STY_Alpha;
			Canvas.DrawColor = C;
			Canvas.SetPos(ResRight + DigitW * 0.5, Y + (HL_FONT_H * S - IconH) * 0.5);
			Canvas.DrawTile(AmmoClass.default.IconMaterial, IconW, IconH, U, V, UL, VL);
		}
	}
}

// One wedge, narrowing towards the crosshair. Dir is Valve's sprite frame number:
// 0 top, 1 right, 2 bottom, 3 left. The canvas fills rectangles and nothing else,
// so the taper is sliced out of them.

simulated final function DrawPainWedge(canvas Canvas, float X, float Y, float RW, float RH, int Dir, color C, int A)
{
	local int   i;
	local float t, scale, sw, sh, step;

	Canvas.Style = ERenderStyle.STY_Normal;
	Canvas.SetDrawColor(C.R, C.G, C.B, A);

	if (Dir == 0 || Dir == 2)
	{
		step = RH / float(PAIN_SLICES);

		for (i = 0; i < PAIN_SLICES; i++)
		{
			t = float(i) / float(PAIN_SLICES - 1);

			if (Dir == 0)
				scale = 1.0 - (1.0 - PAIN_TAPER) * t;
			else
				scale = PAIN_TAPER + (1.0 - PAIN_TAPER) * t;

			sw = RW * scale;

			// One pixel of overlap: without it the seams show as gaps.
			Canvas.SetPos(X + (RW - sw) * 0.5, Y + float(i) * step);
			Canvas.DrawTile(Texture'engine.WhiteSquareTexture', sw, step + 1, 0, 0, 1, 1);
		}

		return;
	}

	step = RW / float(PAIN_SLICES);

	for (i = 0; i < PAIN_SLICES; i++)
	{
		t = float(i) / float(PAIN_SLICES - 1);

		if (Dir == 1)
			scale = PAIN_TAPER + (1.0 - PAIN_TAPER) * t;
		else
			scale = 1.0 - (1.0 - PAIN_TAPER) * t;

		sh = RH * scale;

		Canvas.SetPos(X + float(i) * step, Y + (RH - sh) * 0.5);
		Canvas.DrawTile(Texture'engine.WhiteSquareTexture', step + 1, sh, 0, 0, 1, 1);
	}
}

// smooth the accel readout and push the current speed into the graph history for the velocity graph

simulated final function UpdateAccel(GoldSrcMovement M)
{
	local float Spd, dt, Inst;

	Spd = M.HorizontalSpeedHL();
	dt  = M.frametime;

	if (dt > 0.0)
	{
		Inst         = (Spd - LastSpeed) / dt;
		DisplayAccel = DisplayAccel + (Inst - DisplayAccel) * 0.15;
	}

	LastSpeed = Spd;

	// push to graph history
	//
	// Only DrawVelocityGraph reads this, and bShowVelocityGraph is off by default
	// (it is an ini-only switch), so without the gate every frame in the shipped
	// configuration writes a sample nobody will ever draw. Resetting the cursor on
	// the way past means the graph starts empty when it is switched on rather than
	// drawing a ring buffer full of speeds from minutes ago.
	if (!bShowVelocityGraph)
	{
		GraphIndex   = 0;
		bGraphFilled = false;
		return;
	}

	GraphSpeed[GraphIndex] = Spd;
	GraphIndex++;
	if (GraphIndex >= GRAPH_SAMPLES)
	{
		GraphIndex   = 0;
		bGraphFilled = true;
	}
}

// bunnymod xt users favourite feature. SHOUTOUT MY BOY YALTER

simulated final function DrawSpeedometer(canvas Canvas, GoldSrcMovement M)
{
	local float Spd, BaseX, BaseY, XL, YL;
	local string S;

	Spd = M.HorizontalSpeedHL();

	Canvas.Font       = Canvas.MedFont;
	Canvas.Style      = ERenderStyle.STY_Normal;
	Canvas.FontScaleX = 1.0;
	Canvas.FontScaleY = 1.0;

	// Speed now, and the speed the last jump left the ground at in brackets after
	// it -- the two numbers a bunnyhop is actually judged on. No label and no unit:
	// the row is read hundreds of times a run and the words never change.
	S = int(Spd + 0.5) @ "(" $ int(M.DebugTakeoffSpeed / FMax(M.WorldScale, 0.0001) + 0.5) $ ")";

	Canvas.StrLen(S, XL, YL);

	BaseX = (Canvas.ClipX * 0.5) - (XL * 0.5);
	BaseY = Canvas.ClipY - (Canvas.ClipY * 0.18);

	// Drop shadow for legibility on bright scenery.
	Canvas.SetDrawColor(0, 0, 0, 160);
	Canvas.SetPos(BaseX + 1, BaseY + 1);
	Canvas.DrawText(S, false);

	Canvas.SetDrawColor(SpeedColor.R, SpeedColor.G, SpeedColor.B, SpeedColor.A);
	Canvas.SetPos(BaseX, BaseY);
	Canvas.DrawText(S, false);

	// accel readout
	if (Abs(DisplayAccel) > 5.0)
	{
		Canvas.Font = Canvas.SmallFont;

		if (DisplayAccel > 0)
		{
			S = "+" $ int(DisplayAccel + 0.5);
			Canvas.SetDrawColor(AccelColor.R, AccelColor.G, AccelColor.B, AccelColor.A);
		}
		else
		{
			S = string(int(DisplayAccel - 0.5));
			Canvas.SetDrawColor(DecelColor.R, DecelColor.G, DecelColor.B, DecelColor.A);
		}

		Canvas.StrLen(S, XL, YL);
		Canvas.SetPos((Canvas.ClipX * 0.5) - (XL * 0.5), BaseY + YL + 2);
		Canvas.DrawText(S, false);
	}
}

// the velgraph

simulated final function DrawVelocityGraph(canvas Canvas, GoldSrcMovement M)
{
	local int   i, idx, Count;
	local float GW, GH, GX, GY, BarW, Peak, V, H;

	GW = 192.0;
	GH = 48.0;
	GX = (Canvas.ClipX * 0.5) - (GW * 0.5);
	GY = Canvas.ClipY - (Canvas.ClipY * 0.18) - GH - 12;

	if (bGraphFilled)
		Count = GRAPH_SAMPLES;
	else
		Count = GraphIndex;

	if (Count < 2)
		return;

	// scale to tallest sample
	Peak = 320.0;
	for (i = 0; i < Count; i++)
	{
		if (GraphSpeed[i] > Peak)
			Peak = GraphSpeed[i];
	}

	// backing panel
	Canvas.SetDrawColor(0, 0, 0, 90);
	Canvas.SetPos(GX, GY);
	Canvas.DrawTile(Texture'engine.WhiteSquareTexture', GW, GH, 0, 0, 1, 1);

	BarW = GW / float(GRAPH_SAMPLES);

	Canvas.SetDrawColor(SpeedColor.R, SpeedColor.G, SpeedColor.B, 200);

	for (i = 0; i < Count; i++)
	{
		// walk the buffer oldest-to-newest so the graph scrolls left
		if (bGraphFilled)
			idx = (GraphIndex + i) % GRAPH_SAMPLES;
		else
			idx = i;

		V = GraphSpeed[idx];
		H = (V / Peak) * GH;

		if (H < 1.0)
			H = 1.0;

		Canvas.SetPos(GX + (float(i) * BarW), GY + GH - H);
		Canvas.DrawTile(Texture'engine.WhiteSquareTexture', FMax(BarW - 1, 1), H, 0, 0, 1, 1);
	}
}

// framerate which is averaged over FPS_WINDOW seconds.
simulated final function UpdateFps()
{
	local float dt;

	if (LastFrameTime <= 0.0)
	{
		LastFrameTime = Level.TimeSeconds;
		return;
	}

	dt            = (Level.TimeSeconds - LastFrameTime) / FMax(Level.TimeDilation, 0.0001);
	LastFrameTime = Level.TimeSeconds;

	if (dt <= 0.0)
		return;

	FpsAccumTime += dt;
	FpsFrames++;

	if (FpsAccumTime >= FPS_WINDOW)
	{
		DisplayFps   = float(FpsFrames) / FpsAccumTime;
		FpsAccumTime = 0.0;
		FpsFrames    = 0;
	}
}

// EVERY SOURCE ENGINE PLAYER'S FAVOURITE COMMAND ON JAH.

simulated final function DrawNetGraph(canvas Canvas)
{
	local float RX, Y, XL, YL;
	local int   Ping;

	Canvas.Font       = Canvas.SmallFont;
	Canvas.Style      = ERenderStyle.STY_Normal;
	Canvas.FontScaleX = 1.0;
	Canvas.FontScaleY = 1.0;

	Canvas.StrLen("Wg", XL, YL);

	if (PlayerOwner != None && PlayerOwner.PlayerReplicationInfo != None)
		Ping = PlayerOwner.PlayerReplicationInfo.Ping;

	RX = Canvas.ClipX - 16;
	Y  = Canvas.ClipY - 16 - (YL * 4);

	DrawRight(Canvas, RX, Y, "fps: " $ int(DisplayFps + 0.5) $ "   ping: " $ Ping,
		NetGraphColor);
	Y += YL;

	DrawRight(Canvas, RX, Y, "in :  0.00   0.00 k/s   0.0/s", NetGraphColor);
	Y += YL;

	DrawRight(Canvas, RX, Y, "out:  0.00   0.00 k/s   0.0/s", NetGraphColor);
	Y += YL;

	DrawRight(Canvas, RX, Y, "loss: 0   choke: 0", NetGraphColor);
}
// hello half life 2


simulated final function DrawShowPos(canvas Canvas, GoldSrcMovement M)
{
	local vector  Pos, Vel;
	local rotator R;
	local float   X, Y, YL, XL, Scale;

	if (PlayerOwner == None)
		return;

	if (M != None)
		Scale = M.WorldScale;
	else
		Scale = class'GoldSrcMovement'.default.WorldScale;

	Scale = FMax(Scale, 0.0001);

	if (PlayerOwner.Pawn != None)
	{
		Pos = PlayerOwner.Pawn.Location;
		Vel = PlayerOwner.Pawn.Velocity;
	}
	else
	{
		Pos = PlayerOwner.Location;
	}

	// our own velocity when we have it

	if (M != None)
		Vel = M.velocity;

	R = PlayerOwner.Rotation;

	Canvas.Font       = Canvas.SmallFont;
	Canvas.Style      = ERenderStyle.STY_Normal;
	Canvas.FontScaleX = 1.0;
	Canvas.FontScaleY = 1.0;

	Canvas.StrLen("Wg", XL, YL);

	X = 12;
	Y = 12;

	DrawPosLine(Canvas, X, Y, "pos:", Fmt2(Pos.X), Fmt2(Pos.Y), Fmt2(Pos.Z));
	Y += YL;

	DrawPosLine(Canvas, X, Y, "ang:", Fmt2(-UnrToDeg(R.Pitch)), Fmt2(UnrToDeg(R.Yaw)),
		Fmt2(UnrToDeg(R.Roll)));
	Y += YL;

	DrawPosLine(Canvas, X, Y, "vel:", Fmt2(VSize(Vel) / Scale), "", "");
}

simulated final function DrawPosLine(canvas Canvas, float X, float Y, string Label,
	string A, string B, string C)
{
	local float ColW;

	ColW = 76;

	DrawShadowed(Canvas, X, Y, Label, ShowPosColor);

	if (A != "")
		DrawRight(Canvas, X + 44 + ColW, Y, A, ShowPosColor);

	if (B != "")
		DrawRight(Canvas, X + 44 + (ColW * 2), Y, B, ShowPosColor);

	if (C != "")
		DrawRight(Canvas, X + 44 + (ColW * 3), Y, C, ShowPosColor);
}

// another like dumbahh dev readout because i gotta keep it safe

simulated final function DrawMoveDebug(canvas Canvas, GoldSrcMovement M)
{
	local GoldSrcPlayer GP;
	local float X, Y, YL, XL;
	local string GroundStr;
	local string StompStr;
	local name  BodyAnim;
	local float BodyFrame, BodyRate;

	GP = GoldSrcPlayer(PlayerOwner);

	X = 16;
	Y = Canvas.ClipY * 0.30;

	Canvas.Font       = Canvas.SmallFont;
	Canvas.Style      = ERenderStyle.STY_Normal;
	Canvas.FontScaleX = 1.0;
	Canvas.FontScaleY = 1.0;

	Canvas.StrLen("Wg", XL, YL);

	if (M.onground)
		GroundStr = "ONGROUND";
	else
		GroundStr = "AIR";

	DebugLine(Canvas, X, Y, YL, 0, "-- GoldSrc debug HUD --");
	Y += YL;

	DebugLine(Canvas, X, Y, YL, 0, "velocity   " $ VecStr(M.velocity / FMax(M.WorldScale, 0.0001)));
	Y += YL;

	DebugLine(Canvas, X, Y, YL, 0, "horiz spd  " $ FmtF(M.HorizontalSpeedHL()) @ "ups");
	Y += YL;

	// same speed measured the other way round

	if (GP != None)
	{
		DebugLine(Canvas, X, Y, YL, 0, "measured   " $ FmtF(GP.MeasuredSpeedHL) @ "ups");
		Y += YL;

		// who moved the pawn and what we did about it. every hit takes us off
		// PHYS_None (Pawn.TakeDamage), so "stomp" counts hits landing on us;
		// "drift" is the displacement that produced. kept means the simulation
		// adopted it, put back means it was native physics and we refused it.
		// sustained fire should show stomps with put-back climbing and kept at
		// zero. see GoldSrcPlayer.RestorePawnPosition.
		if (GP.LastStompPhysics != '')
		{
			StompStr = string(GP.LastStompPhysics);
			if (Level.TimeSeconds - GP.LastStompTime > 1.0)
				StompStr = StompStr $ " (idle)";

			DebugLine(Canvas, X, Y, YL, 0, "stomp      " $ StompStr
				$ "  " $ GP.StompsPerSec $ "/s");
			Y += YL;
		}

		if (GP.DriftAdoptedHL > 0.5 || GP.DriftRefusedHL > 0.5)
		{
			DebugLine(Canvas, X, Y, YL, 0, "drift      kept " $ FmtF(GP.DriftAdoptedHL)
				$ "  put back " $ FmtF(GP.DriftRefusedHL) @ "ups");
			Y += YL;
		}

		// The pawn's body animation and the mode it was chosen for. A run loop
		// left behind by a stolen physics window is audible forever on a pawn
		// whose footstep notify checks nothing. Standing still here should read
		// an idle pose on phys PHYS_None; a run name while stopped is that bug.
		// See GoldSrcPlayer.SyncPawnAnimation.
		//
		// The mode, the base and the hold count belong on this row too, because
		// they are the same story: the pawn loses PHYS_None whenever it loses a
		// base it should not have had, and holds counts every time that had to
		// be undone. phys must read PHYS_None at all times; base is None once
		// the simulation has settled, and anything else means a stolen mode
		// based us on something. See HoldPhysNone.
		if (GP.Pawn != None)
		{
			GP.Pawn.GetAnimParams(0, BodyAnim, BodyFrame, BodyRate);

			DebugLine(Canvas, X, Y, YL, 0, "body anim  " $ BodyAnim
				$ "  rate " $ FmtF(BodyRate)
				$ "  " $ GetEnum(enum'EPhysics', GP.Pawn.Physics));
			Y += YL;

			DebugLine(Canvas, X, Y, YL, 0, "phys hold  " $ GP.PhysHolds
				$ "  base " $ GP.Pawn.Base);
			Y += YL;

			// The other two thirds of the position diagnostic (GoldSrcPlayer):
			// whether SetLocation is being refused, and whether the pawn was
			// inside something the last time it was.
			DebugLine(Canvas, X, Y, YL, 0, "setloc     refused " $ GP.SetLocFails
				$ "  salvaged " $ GP.SetLocSalvaged
				$ "  clipped " $ GP.SetLocClipped
				$ "  embedded " $ YesNo(GP.bLastMoveEmbedded, "YES", "no"));
			Y += YL;

			// ...and WHAT refused it, which no other row can tell you, because the
			// touch row is filtered through BlocksPlayer and a refusal is by
			// definition something that filter passes. Watch this one while walking
			// into a snag: it names the actor, or says the engine objected to the
			// destination itself rather than to anything on the way to it.
			if (GP.RefuseTime > 0.0)
			{
				DebugLine(Canvas, X, Y, YL, 0, "refused    " $ GP.RefuseName
					$ " (" $ GP.RefuseClass $ ")"
					$ "  want " $ FmtF(GP.RefuseWanted)
					$ "  got " $ FmtF(GP.RefuseMoved)
					$ "  " $ FmtF(GP.Level.TimeSeconds - GP.RefuseTime) $ "s");
				Y += YL;
			}
		}
	}

	// what the frame actually costs
	DebugLine(Canvas, X, Y, YL, 0, "cost       " $ M.TracesPerFrame $ " traces  "
		$ M.WaterScansPerFrame $ " wscan");
	Y += YL;

	DebugLine(Canvas, X, Y, YL, 0, "vert spd   " $ FmtF(M.VerticalSpeedHL()) @ "ups");
	Y += YL;

	DebugLine(Canvas, X, Y, YL, 0, "state      " $ GroundStr @ "/" @ M.DebugMoveState);
	Y += YL;

	// what the ground trace actually found, and how steep the last plane we hit
	// was. the row above is derived from this one -- onground is nothing more than
	// "the downward trace found something" -- so AIR here while standing on a floor
	// means the trace is being masked by something non-blocking parked in it, and
	// LevelInfo means BSP while a name like StaticMeshActor42 means a mesh. normal
	// z under 0.70 is too steep to stand on by HL's rule and reads as AIR on purpose.
	DebugLine(Canvas, X, Y, YL, 0, "ground     " $ M.groundEntity
		$ "  normal z " $ FmtF(M.TracePlaneNormal.Z));
	Y += YL;

	// What is in the way. "touch" is the last thing a sideways or upward move ran
	// into -- an invisible wall is an actor here with hidden in its flags -- and
	// "overlap" is everything the hull is standing inside right now, straight off
	// the pawn's own touch list, which is where triggers and volumes show up.
	DebugLine(Canvas, X, Y, YL, 0, "touch      " $ BlockerStr(M));
	Y += YL;

	DebugLine(Canvas, X, Y, YL, 0, "overlap    " $ OverlapStr(M.PM));
	Y += YL;

	DebugLine(Canvas, X, Y, YL, 0, "ducking    " $ YesNo(M.bDucking, "yes", "no")
		$ "  hull " $ M.usehull);
	Y += YL;

	// the input side

	if (GP != None)
	{
		DebugLine(Canvas, X, Y, YL, 0, "axis       " $ VecStr(GP.DebugRawAxes)
			$ "  peak " $ FmtF(GP.DebugAxisPeak) $ "/" $ FmtF(GP.MoveAxisMax));
		Y += YL;
	}

	DebugLine(Canvas, X, Y, YL, 0, "wishdir    " $ VecStr(M.DebugWishDir));
	Y += YL;

	DebugLine(Canvas, X, Y, YL, 0, "wishspeed  " $ FmtF(M.DebugWishSpeed / FMax(M.WorldScale, 0.0001)));
	Y += YL;

	DebugLine(Canvas, X, Y, YL, 0, "accel      " $ FmtF(DisplayAccel) @ "ups/s");
	Y += YL;

	DebugLine(Canvas, X, Y, YL, 0, "takeoff    " $ FmtF(M.DebugTakeoffSpeed / FMax(M.WorldScale, 0.0001)));
	Y += YL;

	DebugLine(Canvas, X, Y, YL, 0, "frametime  " $ FmtF(M.frametime * 1000.0) @ "ms");
	Y += YL;

	// every time PM_WalkMove had to nudge us out of a flush contact to move at
	// all. climbing while you cannot move means the weld is the flush-trace one
	// and the nudge is not enough, staying at zero while you cannot move means
	// whatever is holding you is not the walk move
	DebugLine(Canvas, X, Y, YL, 0, "weld       nudges " $ M.WeldNudges
		$ "   stuck " $ YesNo(M.bWasStuck, "YES", "no") $ "/" $ M.StuckFrames);
	Y += YL;

	// what the last hit actually added to the simulation, in hammer units, and how
	// long ago. this is the number to watch when tuning the knockback dials, a
	// blast reading far above the cap means the push did not come through
	// GoldSrcPlayer.DriveDamage at all
	if (M.DebugLastPushTime > 0.0)
	{
		DebugLine(Canvas, X, Y, YL, 0, "dmg push   "
			$ FmtF(VSize(M.DebugLastPush) / FMax(M.WorldScale, 0.0001)) @ "ups   z "
			$ FmtF(M.DebugLastPush.Z / FMax(M.WorldScale, 0.0001)) $ "   "
			$ FmtF(Level.TimeSeconds - M.DebugLastPushTime) $ "s ago");
	}
	else
	{
		DebugLine(Canvas, X, Y, YL, 0, "dmg push   none yet");
	}
	Y += YL;

	// the bob magnitudes, in Source units: the offset CalcViewModelBob produced this frame
	DebugLine(Canvas, X, Y, YL, 0, "vm bob     v " $ FmtF(VerticalBob)
		$ "  l " $ FmtF(LateralBob) $ "   " $ BobDiag);
	Y += YL;

	// what became of it
	DebugLine(Canvas, X, Y, YL, 0, "vm bob     off " $ VecStr(BobWrote)
		$ "  drawn " $ YesNo(bBobDrawn, "y", "N")
		$ "  stomp " $ YesNo(bBobStomped, "Y", "n")
		$ "  hud " $ BobHUDCalls $ "  ctrl " $ BobCtrlCalls);
	Y += YL;

	// the sway offset, in Source units: the offset CalcViewModelLag produced this frame
	DebugLine(Canvas, X, Y, YL, 0, "vm sway    " $ VecStr(LagOffset)
		$ "  gap " $ FmtF(LagGap) $ "/" $ FmtF(MAX_VM_LAG));
	Y += YL;

	Y += YL * 0.5;

	DebugLine(Canvas, X, Y, YL, 0, "sv_maxspeed      " $ FmtF(M.sv_maxspeed));
	Y += YL;
	DebugLine(Canvas, X, Y, YL, 0, "sv_accelerate    " $ FmtF(M.sv_accelerate));
	Y += YL;
	DebugLine(Canvas, X, Y, YL, 0, "sv_airaccelerate " $ FmtF(M.sv_airaccelerate));
	Y += YL;
	DebugLine(Canvas, X, Y, YL, 0, "sv_friction      " $ FmtF(M.sv_friction));
	Y += YL;
	DebugLine(Canvas, X, Y, YL, 0, "sv_stopspeed     " $ FmtF(M.sv_stopspeed));
	Y += YL;
	DebugLine(Canvas, X, Y, YL, 0, "sv_gravity       " $ FmtF(M.sv_gravity));
	Y += YL;
	DebugLine(Canvas, X, Y, YL, 0, "knockback        " $ FmtF(M.sv_knockback)
		$ "  expl " $ FmtF(M.sv_explosionknockback)
		$ "  cap " $ int(M.sv_maxdamagepush / FMax(M.WorldScale, 0.0001) + 0.5));
	Y += YL;
	DebugLine(Canvas, X, Y, YL, 0, "bhop cap         "
		$ YesNo(M.sv_enablebunnyhopcap, "ON", "OFF"));
	Y += YL;
	DebugLine(Canvas, X, Y, YL, 0, "autobhop         "
		$ YesNo(M.sv_autobunnyhop, "ON", "OFF"));
}

simulated final function DebugLine(canvas Canvas, float X, float Y, float YL, int Kind, string S)
{
	Canvas.SetDrawColor(0, 0, 0, 170);
	Canvas.SetPos(X + 1, Y + 1);
	Canvas.DrawText(S, false);

	Canvas.SetDrawColor(DebugColor.R, DebugColor.G, DebugColor.B, DebugColor.A);
	Canvas.SetPos(X, Y);
	Canvas.DrawText(S, false);
}

// unrealscript has no ternary operator, this is just a small helper for readability.
simulated final function string YesNo(bool b, string sTrue, string sFalse)
{
	if (b)
		return sTrue;
	return sFalse;
}

// text with the same drop shadow DebugLine uses in any color
simulated final function DrawShadowed(canvas Canvas, float X, float Y, string S, color C)
{
	Canvas.SetDrawColor(0, 0, 0, 170);
	Canvas.SetPos(X + 1, Y + 1);
	Canvas.DrawText(S, false);

	Canvas.SetDrawColor(C.R, C.G, C.B, C.A);
	Canvas.SetPos(X, Y);
	Canvas.DrawText(S, false);
}

// as above but ending at RX instead of starting at X.
simulated final function DrawRight(canvas Canvas, float RX, float Y, string S, color C)
{
	local float XL, YL;

	Canvas.StrLen(S, XL, YL);
	DrawShadowed(Canvas, RX - XL, Y, S, C);
}

// unreal's 16-bit rotator units to degrees, wrapped to (-180, 180].
simulated final function float UnrToDeg(int Unr)
{
	local float Deg;

	Deg = (float(Unr & 65535) * 360.0) / 65536.0;

	if (Deg > 180.0)
		Deg -= 360.0;

	return Deg;
}

// two decimal places - the width cl_showpos and net_graph print at.
simulated final function string Fmt2(float V)
{
	local int Whole, Frac;
	local string Sign, FracStr;

	if (V < 0)
	{
		Sign = "-";
		V    = -V;
	}

	Whole = int(V);
	Frac  = int((V - float(Whole)) * 100.0 + 0.5);

	if (Frac >= 100)
	{
		Whole++;
		Frac = 0;
	}

	FracStr = string(Frac);
	if (Frac < 10)
		FracStr = "0" $ FracStr;

	return Sign $ Whole $ "." $ FracStr;
}

// compact fixed-ish float formatting (unrealscript has no printf).
simulated final function string FmtF(float V)
{
	local int Whole, Frac;
	local string Sign;

	if (V < 0)
	{
		Sign = "-";
		V    = -V;
	}

	Whole = int(V);
	Frac  = int((V - float(Whole)) * 10.0 + 0.5);

	if (Frac >= 10)
	{
		Whole++;
		Frac = 0;
	}

	return Sign $ Whole $ "." $ Frac;
}

simulated final function string VecStr(vector V)
{
	return "(" $ FmtF(V.X) $ ", " $ FmtF(V.Y) $ ", " $ FmtF(V.Z) $ ")";
}

// The "touch" row: what the tracer last refused to let us through, sideways or
// upwards. GoldSrcMovement.NoteBlocker resolved the identity when it recorded it,
// so this only formats. Age is shown because a blocker goes stale the moment you
// walk away from it and a name left on screen would read as a wall that is still
// there.
simulated final function string BlockerStr(GoldSrcMovement M)
{
	local float Age;
	local string Flags;

	if (M.BlockActor == None)
		return "nothing yet";

	// Resolve the diagnostic strings lazily (see NoteBlocker): the trace path
	// only records WHO, the reads happen here where a destroyed actor can be
	// caught before anything touches its members.
	M.ResolveBlockInfo();

	if (M.BlockActor == None)
		return "nothing yet";

	Age = Level.TimeSeconds - M.BlockTime;

	if (Age > 1.0)
		return "clear   (last was " $ M.BlockName $ ", " $ FmtF(Age) $ "s ago)";

	if (M.BlockHidden)
		Flags = Flags $ " hidden";
	if (M.BlockWorldGeo)
		Flags = Flags $ " worldgeo";
	if (M.BlockIsVolume)
		Flags = Flags $ " volume";

	// Read the block flags off the actor rather than caching them: they are what
	// says whether this thing has any business being solid to a player. Cheap,
	// and BlockActor goes None by itself if it is destroyed.
	// bBlockPlayers is obsolete/always false in UT2004; bBlockActors is the live
	// flag, and its absence on something the trace returned is the "why is this
	// thing passable" answer this row exists to give.
	if (!M.BlockActor.bBlockActors)
		Flags = Flags $ " NOblkActors";

	// EMBEDDED means the hull is inside it, not walking into it -- the difference
	// between a wall and being stuck.
	return M.BlockName $ " (" $ M.BlockClass $ ")"
		$ YesNo(M.BlockProbe, "  EMBEDDED", "  nz " $ FmtF(M.BlockNormal.Z))
		$ Flags;
}

// The "overlap" row: everything the hull is inside right now. This is the pawn's
// own Touching list, which the engine keeps up to date through our SetLocation
// calls, so it costs nothing to read and it is where triggers and volumes -- the
// things with no visible surface at all -- turn up. Capped at three names because
// a fourth would run off the side of the screen.
simulated final function string OverlapStr(Pawn P)
{
	local Actor A;
	local string S;
	local int N;

	if (P == None)
		return "no pawn";

	foreach P.TouchingActors(class'Actor', A)
	{
		if (N >= 3)
		{
			S = S $ " +more";
			break;
		}

		if (N > 0)
			S = S $ ", ";

		S = S $ string(A.Name);
		N++;
	}

	if (N == 0)
		return "nothing";

	return S;
}

// --- killfeed ----------------------------------------------------------------
// One entry per kill: "Killer  [weapon]  Victim". The list scrolls down as
// entries expire; ours are highlighted.

simulated function NoteKill(string Killer, string Victim, string Weapon,
	bool bSuicide, bool bMine)
{
	local int i;

	// Shift down: the newest entry takes slot 0, the oldest falls off.
	for (i = KILLFEED_MAX - 1; i > 0; i--)
		KillFeed[i] = KillFeed[i - 1];

	KillFeed[0].Killer   = Killer;
	KillFeed[0].Victim   = Victim;
	KillFeed[0].Weapon   = Weapon;
	KillFeed[0].bSuicide = bSuicide;
	KillFeed[0].bMine    = bMine;
	KillFeed[0].Time     = Level.TimeSeconds;
}

simulated final function DrawKillfeed(canvas Canvas)
{
	local int   i, Line;
	local float Y, XL, YL, Fade;
	local color C;
	local string S;

	for (i = 0; i < KILLFEED_MAX; i++)
	{
		if (KillFeed[i].Killer == "" && KillFeed[i].Victim == "")
			continue;

		Fade = 1.0 - (Level.TimeSeconds - KillFeed[i].Time) / KILLFEED_TIME;
		if (Fade <= 0.0)
		{
			KillFeed[i].Killer = "";
			KillFeed[i].Victim = "";
			continue;
		}

		if (KillFeed[i].bSuicide)
			S = KillFeed[i].Victim $ "  " $ KillFeed[i].Weapon;
		else
			S = KillFeed[i].Killer $ "  " $ KillFeed[i].Weapon $ "  " $ KillFeed[i].Victim;

		Canvas.Font = Canvas.SmallFont;
		Canvas.TextSize(S, XL, YL);

		if (KillFeed[i].bMine)
			C = MyFeedColor;
		else
			C = FeedColor;

		Y = 24 + Line * (YL + 4);
		Canvas.SetDrawColor(0, 0, 0, int(140 * Fade));
		Canvas.SetPos(Canvas.ClipX - XL - 22, Y + 1);
		Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', XL + 12, YL + 2);
		Canvas.SetDrawColor(C.R, C.G, C.B, int(255 * Fade));
		Canvas.SetPos(Canvas.ClipX - XL - 16, Y);
		Canvas.DrawText(S);
		Line++;
	}
}

// --- damage-direction arrow ring ----------------------------------------------
// Replaces the HL pain wedges: a ring of arrows around the crosshair, each
// pointing at a recent attacker in world space. Latched at hit time, so it
// behaves like the wedges: turning afterwards doesn't drag the arrows around.

simulated function NoteArrow(vector From, vector PlayerLoc)
{
	local int   i, Oldest;
	local float BestAge;

	// Refresh in place if this direction is already on the ring.
	for (i = 0; i < ARROWS_MAX; i++)
	{
		if (Arrows[i].Time > 0.0
			&& Normal(Arrows[i].Dir) dot Normal(From - PlayerLoc) > 0.995)
		{
			Arrows[i].Time = Level.TimeSeconds;
			return;
		}
	}

	Oldest = 0;
	for (i = 0; i < ARROWS_MAX; i++)
	{
		if (Arrows[i].Time <= 0.0)
		{
			Oldest = i;
			break;
		}
		if (Level.TimeSeconds - Arrows[i].Time > BestAge)
		{
			BestAge = Level.TimeSeconds - Arrows[i].Time;
			Oldest  = i;
		}
	}

	Arrows[Oldest].Dir  = Normal(From - PlayerLoc);
	Arrows[Oldest].Time = Level.TimeSeconds;
}

simulated final function DrawArrowRing(canvas Canvas)
{
	local int    i, s;
	local float  CX, CY, Age, Alpha, Angle, Rad, Step, Scale, Thick, DirX, DirY;
	local vector ScreenDir;

	CX    = Canvas.ClipX * 0.5;
	CY    = Canvas.ClipY * 0.5;
	Scale = FMax(Canvas.ClipY / 600.0, 0.5);

	for (i = 0; i < ARROWS_MAX; i++)
	{
		if (Arrows[i].Time <= 0.0)
			continue;

		Age = Level.TimeSeconds - Arrows[i].Time;
		if (Age > ARROW_TIME)
		{
			Arrows[i].Time = 0.0;
			continue;
		}

		Alpha = 1.0 - Age / ARROW_TIME;

		// Project the world-space attacker direction into screen space:
		// flatten Z (the ring reads direction, not elevation) and rotate into
		// view space, where the yaw maps straight onto a screen angle.
		ScreenDir = Arrows[i].Dir >> PlayerOwner.Rotation;
		Angle     = rotator(ScreenDir).Yaw * (3.14159265 / 32768.0);
		DirX      = Sin(Angle);
		DirY      = -Cos(Angle);
		Rad       = ARROW_RING_R * Scale;

		// The arrow: a stepped line pointing outward from the ring, with a
		// wider head at the tip. Axis-aligned rect stairs, as everywhere else.
		for (s = 0; s < ARROW_STEPS; s++)
		{
			Step = float(s) / float(ARROW_STEPS - 1);
			// head: last three steps widen
			if (s >= ARROW_STEPS - 3)
				Thick = (3.6 + (s - ARROW_STEPS + 3) * 1.2) * Scale;
			else
				Thick = 2.4 * Scale;

			Canvas.SetDrawColor(ArrowColor.R, ArrowColor.G, ArrowColor.B,
				int(255.0 * Alpha * (1.0 - 0.5 * Step)));
			Canvas.SetPos(CX + DirX * (Rad + Step * 10.0 * Scale) - Thick * 0.5,
			              CY + DirY * (Rad + Step * 10.0 * Scale) - Thick * 0.5);
			Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', Thick, Thick);
		}
	}
}

// --- enemy HP bars -------------------------------------------------------------

simulated final function DrawEnemyHPBar(canvas Canvas)
{
	local int    i;
	local float  Age, Fade, W, Scale, Frac, ShieldFrac;
	local vector Head, Screen;

	Scale = FMax(Canvas.ClipY / 600.0, 0.5);
	W     = HPBAR_W * Scale;

	for (i = 0; i < HPBAR_MAX; i++)
	{
		if (HPTracks[i].Victim == None)
			continue;

		Age = Level.TimeSeconds - HPTracks[i].Time;
		if (Age > HPBAR_TIME || HPTracks[i].Victim.Health <= 0
			|| HPTracks[i].Victim.bDeleteMe)
		{
			HPTracks[i].Victim = None;
			continue;
		}

		Head = HPTracks[i].Victim.Location;
		Head.Z += HPTracks[i].Victim.CollisionHeight + 12;

		Screen = Canvas.WorldToScreen(Head);
		if (Screen.Z <= 0.0 || !IsInFront(Canvas, Head))
			continue;

		Fade  = 1.0 - Age / HPBAR_TIME;
		Frac  = float(Clamp(HPTracks[i].Victim.Health, 0, 100)) / 100.0;
		ShieldFrac = float(Clamp(HPTracks[i].Victim.ShieldStrength, 0, 100)) / 100.0;

		// backing
		Canvas.SetDrawColor(0, 0, 0, int(160 * Fade));
		Canvas.SetPos(Screen.X - W * 0.5 - 1, Screen.Y - 1);
		Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', W + 2, HPBAR_H * Scale + 2);

		// health fill, red as it drops
		if (Frac > 0.5)
			Canvas.SetDrawColor(HPBarColor.R, HPBarColor.G, HPBarColor.B, int(220 * Fade));
		else
			Canvas.SetDrawColor(255, 40, 40, int(220 * Fade));
		Canvas.SetPos(Screen.X - W * 0.5, Screen.Y);
		Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', W * Frac, HPBAR_H * Scale);

		// shield strip above
		if (ShieldFrac > 0.0)
		{
			Canvas.SetDrawColor(ShieldBarColor.R, ShieldBarColor.G, ShieldBarColor.B, int(220 * Fade));
			Canvas.SetPos(Screen.X - W * 0.5, Screen.Y - HPBAR_H * Scale - 3);
			Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', W * ShieldFrac, 2.5 * Scale);
		}
	}
}

// --- revenge marker --------------------------------------------------------------
// A chevron over the head of the player who last killed us, until we get them
// back or die again.

simulated final function DrawRevengeMarker(canvas Canvas, GoldSrcPlayer GP)
{
	local vector Head, Screen;
	local float  Alpha;
	local int    CX;

	if (GP.RevengeTarget == None || GP.RevengeTarget.bDeleteMe
		|| GP.RevengeTarget.Health <= 0)
		return;

	Head = GP.RevengeTarget.Location;
	Head.Z += GP.RevengeTarget.CollisionHeight + 30;

	Screen = Canvas.WorldToScreen(Head);
	if (Screen.Z <= 0.0 || !IsInFront(Canvas, Head))
		return;

	// Pulse so it reads as a marker and not a floating decoration.
	Alpha = 0.75 + 0.25 * Sin(Level.TimeSeconds * 6.0);

	Canvas.SetDrawColor(255, 60, 30, int(255 * Alpha));
	// chevron: two stepped diagonals meeting at the top
	for (CX = 0; CX < 5; CX++)
	{
		Canvas.SetPos(Screen.X - 7 + CX, Screen.Y + CX);
		Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', 3, 3);
		Canvas.SetPos(Screen.X + 5 - CX, Screen.Y + CX);
		Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', 3, 3);
	}
}

// --- multikill pips --------------------------------------------------------------
// Pips under the crosshair while a multikill chain is live. Feeds off
// UnrealPlayer.MultiKillLevel, which the game keeps for the announcer.

simulated final function DrawMultikillPips(canvas Canvas, GoldSrcPlayer GP)
{
	local int   i, N, CX, CY;
	local float Scale;

	N     = GP.MultiKillLevel;
	Scale = FMax(Canvas.ClipY / 600.0, 0.5);
	if (N <= 0)
		return;

	CX = Canvas.ClipX * 0.5;
	CY = Canvas.ClipY * 0.5 + 40 * Scale;

	for (i = 0; i < N && i < 6; i++)
	{
		Canvas.SetDrawColor(255, 200, 60, 230);
		Canvas.SetPos(CX - (N * 9 * Scale) * 0.5 + i * 9 * Scale, CY);
		Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', 6 * Scale, 6 * Scale);
	}
}

// --- weapon pickup respawn timers --------------------------------------------------
// Countdown text at pickup spots that are currently hidden. Polled, because
// there is no event for "pickup went hidden".

simulated final function DrawPickupTimers(canvas Canvas)
{
	local int    i, Slot;
	local float  Left, XL, YL;
	local vector Screen;
	local string S;
	local Pickup P;

	if (Level.NetMode != NM_Standalone)
		return;   // server-authoritative respawn times differ

	if (Level.TimeSeconds < NextPickupScan)
	{
		// fall through to draw, list is fresh
	}
	else
	{
		NextPickupScan = Level.TimeSeconds + PICKUP_SCAN;
		foreach DynamicActors(class'Pickup', P)
		{
			if (WeaponPickup(P) == None)
				continue;

			// find or create its slot
			for (Slot = 0; Slot < PICKUP_MAX; Slot++)
			{
				if (PickupList[Slot].Pickup == P)
					break;
				if (PickupList[Slot].Pickup == None)
				{
					PickupList[Slot].Pickup = P;
					PickupList[Slot].Label  = TrimWeaponName(P.InventoryType);
					PickupList[Slot].Respawn = P.GetRespawnTime();
					break;
				}
			}
			if (Slot >= PICKUP_MAX)
				continue;

			if (!P.bHidden && PickupList[Slot].HiddenSince > 0.0)
				PickupList[Slot].HiddenSince = 0.0;        // came back
			else if (P.bHidden && PickupList[Slot].HiddenSince <= 0.0)
				PickupList[Slot].HiddenSince = Level.TimeSeconds;
		}
	}

	for (i = 0; i < PICKUP_MAX; i++)
	{
		if (PickupList[i].Pickup == None || PickupList[i].HiddenSince <= 0.0)
			continue;

		Left = PickupList[i].Respawn - (Level.TimeSeconds - PickupList[i].HiddenSince);
		if (Left <= 0.0)
		{
			PickupList[i].HiddenSince = 0.0;
			continue;
		}

		Screen = Canvas.WorldToScreen(PickupList[i].Pickup.Location);
		if (Screen.Z <= 0.0 || !IsInFront(Canvas, PickupList[i].Pickup.Location))
			continue;

		S = PickupList[i].Label $ "  " $ string(int(Left + 0.999));
		Canvas.Font = Canvas.SmallFont;
		Canvas.TextSize(S, XL, YL);
		Canvas.SetDrawColor(255, 220, 120, 220);
		Canvas.SetPos(Screen.X - XL * 0.5, Screen.Y - YL);
		Canvas.DrawText(S);
	}
}

simulated final function string TrimWeaponName(class<Inventory> InvType)
{
	local string S;

	if (InvType == None)
		return "?";

	S = string(InvType.Name);
	if (Len(S) > 10 && InStr(S, "Ammo") < 0)
		S = Left(S, 10);
	return S;
}

// --- rocket-jump / boost stats popup ----------------------------------------------

simulated function NoteRJ(float HeightGain, float Speed)
{
	RJHeight = HeightGain;
	RJSpeed  = Speed;
	RJTime   = Level.TimeSeconds;
}

simulated final function DrawRJPopup(canvas Canvas, GoldSrcPlayer GP)
{
	local float Age, Alpha, XL, YL;
	local string S;

	if (!GP.bRJStats || RJTime <= 0.0)
		return;

	Age = Level.TimeSeconds - RJTime;
	if (Age > 1.6)
		return;

	Alpha = 1.0 - Age / 1.6;
	S = "boost: +" $ string(int(RJHeight)) $ " up  " $ string(int(RJSpeed)) $ " ups";
	Canvas.Font = Canvas.SmallFont;
	Canvas.TextSize(S, XL, YL);
	Canvas.SetDrawColor(255, 210, 120, int(255 * Alpha));
	Canvas.SetPos(Canvas.ClipX * 0.5 - XL * 0.5, Canvas.ClipY * 0.5 + 70 * FMax(Canvas.ClipY / 600.0, 0.5));
	Canvas.DrawText(S);
}

// --- death recap ---------------------------------------------------------------------
// Killer, weapon, distance, their remaining HP, plus the per-life damage-taken
// breakdown the player controller has been accumulating.

simulated final function DrawDeathRecap(canvas Canvas, GoldSrcPlayer GP)
{
	local float Age, Alpha, Y, XL, YL, X;
	local int    i;
	local string S;

	if (!bDeathRecap || GP.RecapShowUntil <= 0.0 || Level.TimeSeconds > GP.RecapShowUntil)
		return;

	Age   = GP.RecapShowUntil - Level.TimeSeconds;
	Alpha = FMin(1.0, Age * 2.0);   // fade only at the very end

	X = Canvas.ClipX * 0.5;
	Y = Canvas.ClipY * 0.3;

	// panel backing
	Canvas.SetDrawColor(0, 0, 0, int(150 * Alpha));
	Canvas.SetPos(X - 200, Y - 24);
	Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', 400, 150 + GP.RecapRows * 16);

	Canvas.Font = Canvas.MedFont;
	S = "KILLED BY  " $ GP.RecapKiller;
	Canvas.TextSize(S, XL, YL);
	Canvas.SetDrawColor(255, 60, 60, int(255 * Alpha));
	Canvas.SetPos(X - XL * 0.5, Y);
	Canvas.DrawText(S);

	Y += YL + 8;
	Canvas.Font = Canvas.SmallFont;
	S = GP.RecapWeapon $ "   at " $ string(int(GP.RecapDist)) $ " units   (" $ string(GP.RecapKillerHP) $ " HP left)";
	Canvas.TextSize(S, XL, YL);
	Canvas.SetDrawColor(220, 220, 220, int(255 * Alpha));
	Canvas.SetPos(X - XL * 0.5, Y);
	Canvas.DrawText(S);

	Y += YL + 12;
	S = "damage taken this life:";
	Canvas.TextSize(S, XL, YL);
	Canvas.SetDrawColor(160, 160, 160, int(255 * Alpha));
	Canvas.SetPos(X - XL * 0.5, Y);
	Canvas.DrawText(S);

	Y += YL + 2;
	for (i = 0; i < GP.RecapRows; i++)
	{
		S = GP.GetRecapRow(i);
		if (S == "")
			continue;
		Canvas.TextSize(S, XL, YL);
		Canvas.SetDrawColor(190, 190, 190, int(255 * Alpha));
		Canvas.SetPos(X - XL * 0.5, Y);
		Canvas.DrawText(S);
		Y += YL + 2;
	}
}

// --- stats panel (Tab) / modern scoreboard / MVP card ------------------------------------
// All three share the stats the player controller keeps on its PRI side. The
// panel replaces the stock scoreboard while it is up: DrawHudPassA checks
// bScoreboardDrawn (set here) and skips the stock board.

simulated final function DrawScorePanel(canvas Canvas)
{
	local GoldSrcPlayer GP;
	local float XL, YL, Y, X0, RowH;
	local string S;

	GP = GoldSrcPlayer(PlayerOwner);
	if (GP == None)
		return;

	if (!bModernScoreboard || !bShowScoreBoard)
		return;

	X0   = Canvas.ClipX * 0.5 - 260;
	Y    = Canvas.ClipY * 0.15;
	RowH = 20;

	// backing
	Canvas.SetDrawColor(0, 0, 0, 160);
	Canvas.SetPos(X0 - 16, Y - 30);
	Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', 552, 420);

	Canvas.Font = Canvas.MedFont;
	S = "GOLDSRC DEATHMATCH";
	Canvas.TextSize(S, XL, YL);
	Canvas.SetDrawColor(255, 210, 120, 255);
	Canvas.SetPos(Canvas.ClipX * 0.5 - XL * 0.5, Y - 26);
	Canvas.DrawText(S);

	Y += 10;

	// personal stats block
	Canvas.Font = Canvas.SmallFont;
	S = "YOUR SESSION";
	Canvas.TextSize(S, XL, YL);
	Canvas.SetDrawColor(160, 200, 255, 255);
	Canvas.SetPos(X0, Y);
	Canvas.DrawText(S);
	Y += YL + 4;

	S = "kills " $ GP.StatKills $ "   deaths " $ GP.StatDeaths
		$ "   K/D " $ Fmt2(float(GP.StatKills) / FMax(1.0, float(GP.StatDeaths)));
	Canvas.SetDrawColor(230, 230, 230, 255);
	Canvas.SetPos(X0, Y);
	Canvas.DrawText(S);
	Y += YL + 2;

	S = "damage dealt " $ GP.StatDamageDealt $ "   taken " $ GP.StatDamageTaken;
	Canvas.SetDrawColor(230, 230, 230, 255);
	Canvas.SetPos(X0, Y);
	Canvas.DrawText(S);
	Y += YL + 2;

	S = "best streak " $ GP.StatBestStreak $ "   accuracy " $ Fmt2(GP.GetAccuracy()) $ "%";
	Canvas.SetDrawColor(230, 230, 230, 255);
	Canvas.SetPos(X0, Y);
	Canvas.DrawText(S);
	Y += YL + 14;

	// scoreboard table
	Canvas.Font = Canvas.SmallFont;
	S = "PLAYER                        KILLS   DEATHS   PING";
	Canvas.SetDrawColor(160, 160, 160, 255);
	Canvas.SetPos(X0, Y);
	Canvas.DrawText(S);
	Y += YL + 6;

	DrawPlayerRows(Canvas, X0, Y, RowH);
}

// The table rows shared by the panel and the MVP card's ranking list.

simulated final function DrawPlayerRows(canvas Canvas, float X0, float Y, float RowH)
{
	local GameReplicationInfo GRI;
	local PlayerReplicationInfo PRI, Sorted[16];
	local int    i, j, N;
	local string S;
	local color  C;

	GRI = PlayerOwner.GameReplicationInfo;
	if (GRI == None)
		return;

	// insertion sort by kills, capped at 16 rows
	N = 0;
	for (i = 0; i < GRI.PRIArray.Length && N < 16; i++)
	{
		PRI = GRI.PRIArray[i];
		if (PRI == None || PRI.bOnlySpectator)
			continue;
		for (j = N; j > 0 && Sorted[j - 1].Kills < PRI.Kills; j--)
			Sorted[j] = Sorted[j - 1];
		Sorted[j] = PRI;
		N++;
	}

	for (i = 0; i < N; i++)
	{
		PRI = Sorted[i];
		S = PRI.PlayerName;
		while (Len(S) < 26)
			S = S $ " ";
		S = S $ string(PRI.Kills);
		while (Len(S) < 34)
			S = S $ " ";
		S = S $ string(int(PRI.Deaths));
		while (Len(S) < 44)
			S = S $ " ";
		S = S $ string(Max(0, PRI.Ping));

		if (PRI == PlayerOwner.PlayerReplicationInfo)
		{
			C.R = 255; C.G = 220; C.B = 120; C.A = 255;
		}
		else
		{
			C.R = 220; C.G = 220; C.B = 220; C.A = 255;
		}

		Canvas.SetDrawColor(C.R, C.G, C.B, 255);
		Canvas.SetPos(X0, Y + i * RowH);
		Canvas.DrawText(S);
	}
}

// --- MVP card: end-of-match -----------------------------------------------------------

simulated final function DrawMVPCard(canvas Canvas)
{
	local GoldSrcPlayer GP;
	local GameReplicationInfo GRI;
	local PlayerReplicationInfo PRI, MVP;
	local int    i;
	local float  XL, YL, Y, X;
	local string S;

	if (!bMVPCard || Level.Game == None || !Level.Game.bGameEnded)
		return;

	GP  = GoldSrcPlayer(PlayerOwner);
	GRI = PlayerOwner.GameReplicationInfo;
	if (GRI == None)
		return;

	// MVP = most kills
	for (i = 0; i < GRI.PRIArray.Length; i++)
	{
		PRI = GRI.PRIArray[i];
		if (PRI == None || PRI.bOnlySpectator)
			continue;
		if (MVP == None || PRI.Kills > MVP.Kills)
			MVP = PRI;
	}
	if (MVP == None)
		return;

	X = Canvas.ClipX * 0.5;
	Y = Canvas.ClipY * 0.22;

	Canvas.SetDrawColor(0, 0, 0, 170);
	Canvas.SetPos(X - 230, Y - 30);
	Canvas.DrawRect(Texture'Engine.WhiteSquareTexture', 460, 240);

	Canvas.Font = Canvas.MedFont;
	S = "MATCH OVER";
	Canvas.TextSize(S, XL, YL);
	Canvas.SetDrawColor(255, 210, 120, 255);
	Canvas.SetPos(X - XL * 0.5, Y - 24);
	Canvas.DrawText(S);
	Y += 16;

	Canvas.Font = Canvas.MedFont;
	S = "MVP:  " $ MVP.PlayerName $ "  (" $ string(MVP.Kills) $ " kills)";
	Canvas.TextSize(S, XL, YL);
	Canvas.SetDrawColor(255, 255, 255, 255);
	Canvas.SetPos(X - XL * 0.5, Y);
	Canvas.DrawText(S);
	Y += YL + 16;

	if (GP != None)
	{
		Canvas.Font = Canvas.SmallFont;
		S = "your match:  " $ GP.StatKills $ " kills  " $ GP.StatDeaths $ " deaths  "
			$ GP.StatDamageDealt $ " dmg dealt  " $ GP.StatDamageTaken $ " dmg taken";
		Canvas.TextSize(S, XL, YL);
		Canvas.SetDrawColor(230, 230, 230, 255);
		Canvas.SetPos(X - XL * 0.5, Y);
		Canvas.DrawText(S);
		Y += YL + 14;

		S = "best streak " $ GP.StatBestStreak $ "   accuracy " $ Fmt2(GP.GetAccuracy()) $ "%";
		Canvas.TextSize(S, XL, YL);
		Canvas.SetDrawColor(230, 230, 230, 255);
		Canvas.SetPos(X - XL * 0.5, Y);
		Canvas.DrawText(S);
		Y += YL + 12;
	}

	Canvas.Font = Canvas.SmallFont;
	S = "PLAYER                        KILLS   DEATHS   PING";
	Canvas.SetDrawColor(160, 160, 160, 255);
	Canvas.SetPos(X - 216, Y);
	Canvas.DrawText(S);
	Y += 18;

	DrawPlayerRows(Canvas, X - 216, Y, 16);
}

// The two the GoldSrcPlayer execs ask for by name. The HL row rides on the overlay
// pass, so there is no stock layout to save here -- these exist so cl_goldsrchud
// has somewhere to land and stay symmetric with the P2 version.

simulated final function ApplyGoldSrcLayout()
{
}

simulated final function RestoreUTLayout()
{
}

defaultproperties
{
	SpeedColor=(R=255,G=255,B=255,A=255)
	LabelColor=(R=190,G=190,B=190,A=255)
	DebugColor=(R=120,G=255,B=120,A=255)
	AccelColor=(R=120,G=255,B=120,A=255)
	DecelColor=(R=255,G=140,B=140,A=255)
	NetGraphColor=(R=255,G=255,B=255,A=255)
	ShowPosColor=(R=255,G=255,B=255,A=255)
	PainColor=(R=255,G=160,B=0,A=255)   // RGB_YELLOWISH, hud.h
	HudColor=(R=255,G=16,B=16,A=255)    // RGB_REDISH, hud.h
	HitColor=(R=255,G=255,B=255,A=255)  // hitmarker, plain white
	KillColor=(R=255,G=32,B=32,A=255)   // killing blow, red
	bHitmarker=true
	bDamageNumbers=true
	bKillfeed=true
	bArrowRing=true
	bEnemyHPBar=true
	bRevengeMarker=true
	bMultikillPips=true
	bDeathRecap=true
	bPickupTimers=true
	bModernScoreboard=true
	bMVPCard=true
	FeedColor=(R=180,G=180,B=180,A=255)
	MyFeedColor=(R=255,G=220,B=120,A=255)
	FeedSelfColor=(R=255,G=90,B=90,A=255)
	ArrowColor=(R=255,G=80,B=60,A=255)
	HPBarColor=(R=90,G=220,B=90,A=255)
	ShieldBarColor=(R=110,G=190,B=255,A=255)
	HudMinAlpha=200.0
	HudScale=0.85
	HudFontSize=1

	bGoldSrcHud=false
	bShowVelocityGraph=false
}

// this is all just a big fucking mess.
