# GoldSrcMovement for UT2004

Half-Life's GoldSrc player movement (`pm_shared.c`), ported to Unreal Tournament
2004 as an UnrealScript mod. Originally a POSTAL 2 mod; this is the UT2004 port.

What you get, tuned 1:1 to Half-Life units (sv_maxspeed 320, gravity 800,
stepsize 18):

- **Bunnyhopping air acceleration** — HL's air accel with the 30-ups wishspeed cap
  and the uncapped accelspeed that makes strafing gain speed. Turn
  `sv_autobunnyhop 1` on if holding jump should re-hop every landing.
- **HL friction and edge friction** — you slide off ledges, exactly like Valve.
- **Ducking / ducktap** — the 0.4s spline duck, duck-in-air hull change, and a
  bindable `ducktap` (Bunnymod XT style) for hopping without jumping.
- **Ladders, water, water-jump** — Valve's ladder math on UT2004's LadderVolumes,
  three-level water with the waterjump heave.
- **Fall damage** — Valve's realistic curve (sv_falldamage 2 by default).
- **View punch, strafe roll, stair smoothing** — the camera behaves like HL's.
- **HL2 viewmodel bob and sway** — Source's CalcViewmodelBob / CalcViewModelLag,
  bracketed around the weapon draw.
- **HUD overlays** — speedometer (with takeoff speed), movedebug, net_graph,
  cl_showpos, HL's four-wedge damage direction indicator, and an optional
  Half-Life bottom row (`cl_goldsrchud 1`).

Everything stock — weapons, bots, scoring, voice chat — is inherited untouched;
only the movement simulation and the client dials are replaced.

## Installing

Copy `GoldSrcMovement.u` (and `GoldSrcMovement.int` if you built one) into
`UT2004\System\`.

No ini edits are strictly required. Two optional ones:

**1. The GoldSrc console** (ducktap hold tracking; also ends a stuck hold on
level change or typing). In `UT2004.ini`:

```ini
[Engine.Engine]
Console=GoldSrcMovement.GoldSrcConsole
```

**2. The injector** — makes the movement apply to *any* gametype you launch in
Instant Action, without picking a custom one. Single player / standalone only.

```ini
[Engine.GameEngine]
ServerActors=GoldSrcMovement.GoldSrcInjector
```

## Playing it

- **Instant Action → GoldSrc DeathMatch** for the custom gametype, or just use
  the injector above with any gametype.
- `GoldSrc` toggles the movement on/off, `Speedo` the speedometer, `MoveDebug`
  the diagnostic readout, `net_graph 1` and `cl_showpos 1` do what they say.
- Every HL cvar has an exec: `sv_maxspeed`, `sv_gravity`, `sv_friction`,
  `sv_airaccelerate`, `sv_stepsize`, `sv_edgefriction`, `sv_bounce`,
  `sv_knockback`, `sv_falldamage`, `sv_enablebunnyhopcap`,
  `sv_autobunnyhop`, `sv_enableabh` (HL2's accelerated back hopping), etc.
  Settings persist to `GoldSrc.ini`.
- `StuckReport` dumps everything around the hull if you ever wedge into
  geometry.

### Recommended binds

```
set input V ducktap          // hold-to-hop, Bunnymod XT style
set input MouseWheelDown GoldSrcDuckPulse   // duckroll on the wheel
```

The wheel bind matters: the wheel sends its press and release in the same frame,
so the held-duck path never sees it — `GoldSrcDuckPulse` holds duck down for a
short window instead, which is what makes duckrolling work.

## Building

Sources are in `GoldSrcMovement\Classes\`. To build:

1. Mirror them to `<UT2004>\GoldSrcMovement\Classes\`.
2. Add to the `[Editor.EditorEngine]` section of `<UT2004>\System\UT2004.ini`:

   ```ini
   EditPackages=GoldSrcMovement
   ```

3. From `<UT2004>\System\`:

   ```
   UCC.exe make
   ```

## What changed from the POSTAL 2 version

- Bases: `xPlayer` / `HudCDeathmatch` / `ExtendedConsole` / `xDeathMatch`
  instead of the P2 classes.
- P2-only systems cut: police arrest AI, dual-wield forcing, P2 icons and damage
  types, the save-game machinery, crouch toggle (hold-duck only now).
- Explosive damage classification is `DamageType.KDamageImpulse > 0`; footsteps
  are `xPawn.PlayFootStep()` (no per-step volume, play-or-not only).
- The HL bottom row is plain canvas text and tiles — no P2 textures, no FontInfo.
- Wheel-duck is a bindable exec rather than a bind-name cache (UT2004 has no
  BINDING2KEYVAL).
