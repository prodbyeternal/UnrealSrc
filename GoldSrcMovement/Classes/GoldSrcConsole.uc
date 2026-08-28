/// persist & duck/ducktap fix, ported from the POSTAL 2 GoldSrcMovement mod to UT2004.
///
/// Only the ducktap key-hold tracking survives from the P2 version: the gametype
/// and the injector now handle what PatchGameDefaults did, and BINDING2KEYVAL is
/// not a UT2004 console command so the duck-key cache is gone with it. Wheel-duck
/// is a plain bind instead (see the README): set input MouseWheelDown GoldSrcDuckPulse

class GoldSrcConsole extends ExtendedConsole
	config(GoldSrc);

var config bool bEnabled;
var config bool bVerbose;

var LevelInfo LastLevel;

// init on every level change
function Tick(float DeltaTime)
{
	local PlayerController PC;
	local GoldSrcPlayer    GP;

	Super.Tick(DeltaTime);

	if (!bEnabled)
		return;

	PC = GetPC();
	if (PC == None)
		return;

	if (PC.Level != LastLevel)
	{
		LastLevel = PC.Level;

		// A key held across a level change never delivers its release to the new
		// level's controller, so end the hold rather than leave it stuck on.
		GP = GoldSrcPlayer(PC);
		if (GP != None)
			GP.DuckTapHoldEnd();
	}

	// The console eats keys while it is open, so a hold that survives into typing
	// would never see its release. End it as soon as typing starts. UT2004 types
	// through the GUI console rather than the old bTyping path, so an open menu
	// page counts as typing here.
	if (bTyping || IsGuiTyping())
	{
		GP = GoldSrcPlayer(PC);
		if (GP != None && GP.DuckTapHoldKey != 0)
			GP.DuckTapHoldEnd();
	}
}

final function PlayerController GetPC()
{
	if (ViewportOwner == None)
		return None;

	return ViewportOwner.Actor;
}

final function bool IsGuiTyping()
{
	// GUIController is the XInterface class; ViewportOwner.GUIController is only
	// declared as the Engine stub, so ActivePage needs the cast to be reachable.
	if (ViewportOwner == None || GUIController(ViewportOwner.GUIController) == None)
		return false;

	return GUIController(ViewportOwner.GUIController).ActivePage != None;
}

// raw key hook for the ducktap hold
//
// The ducktap half deliberately does NOT look the binding up by name. The key
// identifies itself instead: we publish the key whose press we are processing and
// GoldSrcPlayer.DuckTap claims it; if the engine happens to run bindings BEFORE
// its interactions, the exec has already left a timestamp and we adopt the key
// for it here instead. Either order works, so no assumption about the dispatch
// order is baked in -- and any key, any spelling, any compound bind containing
// ducktap, with no ini reading at all.

function bool KeyEvent(EInputKey Key, EInputAction Action, FLOAT Delta)
{
	local GoldSrcPlayer GP;

	if (bEnabled)
	{
		GP = GoldSrcPlayer(GetPC());

		if (GP != None && GP.bGoldSrcMovement)
		{
			// End of the hold. Not gated on typing: a release has to be honoured
			// wherever it arrives, or opening the console mid-hold strands it on.
			if (Action == IST_Release && GP.DuckTapHoldKey != 0
				&& GP.DuckTapHoldKey == int(Key))
			{
				GP.DuckTapHoldEnd();
			}

			if (Action == IST_Press && !bTyping && !IsGuiTyping())
			{
				GP.DuckTapKeyInFlight     = int(Key);
				GP.DuckTapKeyInFlightTime = GP.Level.TimeSeconds;

				// The exec already ran this frame and found no key published, so it
				// was dispatched ahead of us: this press is its key.
				if (GP.DuckTapHoldKey == 0
					&& GP.DuckTapExecTime == GP.Level.TimeSeconds)
				{
					GP.DuckTapHoldKey = int(Key);
					GP.bDuckTapHeld   = true;
				}
			}
		}
	}

	return Super.KeyEvent(Key, Action, Delta);
}

defaultproperties
{
	bEnabled=true
	bVerbose=false
}
