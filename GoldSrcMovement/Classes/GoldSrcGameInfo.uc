// drop-in replacement gametype that sets the default player controller and HUD
// to GoldSrcMovement's versions. Ported from the POSTAL 2 mod; xDeathMatch keeps
// every rule of stock UT2004 deathmatch, only the movement changes.
class GoldSrcGameInfo extends xDeathMatch;

// Blast jumping: the player's own rockets and shield-gun boosts still knock
// them flying -- Pawn.TakeDamage hands the momentum on untouched either way --
// but with sv_selfblastnodamage on (the default) the health cost is waived
// here, before ShieldAbsorb or anything else sees it. The player controller's
// DamageKnockback knows about this rule and keeps the push alive for exactly
// these hits; everything else (enemy rockets, fall damage) is untouched.
function int ReduceDamage(int Damage, pawn injured, pawn instigatedBy,
	vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local GoldSrcPlayer GP;
	local int           Actual;
	local bool          bWouldKill;

	// Combat feedback for the attacker: this is the one place in the engine
	// that sees every damage event -- ours included, whatever weapon dealt it
	// -- so the hitmarker and damage counters tap in here. Fed with the value
	// AFTER the stock rules have had their say, and with the would-kill flag
	// computed against that same number so armor can still rob the kill.
	if (Damage > 0 && injured != None && instigatedBy != None
		&& instigatedBy != injured)
	{
		GP = GoldSrcPlayer(instigatedBy.Controller);

		if (GP != None)
		{
			Actual     = Super.ReduceDamage(Damage, injured, instigatedBy, HitLocation, Momentum, DamageType);
			bWouldKill = (injured.Health - Actual <= 0);

			GP.NotifyEnemyHit(injured, HitLocation, Actual, bWouldKill);

			return Actual;
		}
	}

	// Blast jumping: the player's own rockets and shield-gun boosts still knock
	// them flying -- Pawn.TakeDamage hands the momentum on untouched either way --
	// but with sv_selfblastnodamage on (the default) the health cost is waived
	// here, before ShieldAbsorb or anything else sees it. The player controller's
	// DamageKnockback knows about this rule and keeps the push alive for exactly
	// these hits; everything else (enemy rockets, fall damage) is untouched.
	if (Damage > 0 && injured != None && instigatedBy == injured
		&& DamageType != None
		&& (DamageType.default.KDamageImpulse > 0
			|| ClassIsChildOf(DamageType, class'DamTypeShieldImpact')))
	{
		GP = GoldSrcPlayer(injured.Controller);

		if (GP != None && GP.Move != None && GP.Move.sv_selfblastnodamage
			&& GP.GetStateName() == 'PlayerGoldSrcWalking')
		{
			return 0;
		}
	}

	return Super.ReduceDamage(Damage, injured, instigatedBy, HitLocation, Momentum, DamageType);
}

defaultproperties
{
	GameName="GoldSrc DeathMatch"
	Description="Deathmatch with Half-Life GoldSrc player movement: bunnyhopping air acceleration, HL friction, duck/ducktap, ladders, water, fall damage."

	PlayerControllerClassName="GoldSrcMovement.GoldSrcPlayer"
	HUDType="GoldSrcMovement.GoldSrcHUD"

	Acronym="GDM"
	MapPrefix="DM"
}
