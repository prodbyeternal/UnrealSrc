// GoldSrcSettingsPage
// The config menu for every modern-DM HUD toggle. Opened with the console
// command "cl_menu" (bindable: setbind X cl_menu). Reads the live values off
// the HUD on open, writes them back and saves on every change, so it doubles
// as the discoverability layer for the whole cl_* family.
class GoldSrcSettingsPage extends GUIPage;

#exec OBJ LOAD FILE=GUI2K4A.utx

var automated GUIButton b_Close;

var automated moCheckBox ck_Hitmarker, ck_DamageNumbers, ck_Killfeed;
var automated moCheckBox ck_ArrowRing, ck_EnemyHPBar, ck_RevengeMarker;
var automated moCheckBox ck_MultikillPips, ck_DeathRecap, ck_Killcam;
var automated moCheckBox ck_PickupTimers, ck_Desaturate, ck_Scoreboard;
var automated moCheckBox ck_MVPCard, ck_SpectatorHUD, ck_RJStats;
var automated moCheckBox ck_Speedo, ck_ViewmodelBob;

function InitComponent(GUIController MyController, GUIComponent MyOwner)
{
	local GoldSrcHUD H;

	Super.InitComponent(MyController, MyOwner);

	H = None;
	if (PlayerOwner() != None)
		H = GoldSrcHUD(PlayerOwner().myHUD);
	if (H == None)
		return;

	ck_Hitmarker.SetComponentValue(string(H.bHitmarker));
	ck_DamageNumbers.SetComponentValue(string(H.bDamageNumbers));
	ck_Killfeed.SetComponentValue(string(H.bKillfeed));
	ck_ArrowRing.SetComponentValue(string(H.bArrowRing));
	ck_EnemyHPBar.SetComponentValue(string(H.bEnemyHPBar));
	ck_RevengeMarker.SetComponentValue(string(H.bRevengeMarker));
	ck_MultikillPips.SetComponentValue(string(H.bMultikillPips));
	ck_DeathRecap.SetComponentValue(string(H.bDeathRecap));
	if (GoldSrcPlayer(PlayerOwner()) != None)
		ck_Killcam.SetComponentValue(string(GoldSrcPlayer(PlayerOwner()).bKillcam));
	ck_PickupTimers.SetComponentValue(string(H.bPickupTimers));
	ck_Desaturate.SetComponentValue(string(H.bDesaturate));
	ck_Scoreboard.SetComponentValue(string(H.bModernScoreboard));
	ck_MVPCard.SetComponentValue(string(H.bMVPCard));
	ck_SpectatorHUD.SetComponentValue(string(H.bSpectatorHUD));
	ck_Speedo.SetComponentValue(string(GoldSrcPlayer(PlayerOwner()).bShowSpeedometer));
	ck_ViewmodelBob.SetComponentValue(string(GoldSrcPlayer(PlayerOwner()).bViewModelBob));
}

function bool ButtonClicked(GUIComponent Sender)
{
	if (Sender == b_Close)
		Controller.CloseMenu(False);

	return true;
}

function CheckBoxChanged(GUIComponent Sender)
{
	local GoldSrcHUD H;
	local GoldSrcPlayer GP;

	H  = GoldSrcHUD(PlayerOwner().myHUD);
	GP = GoldSrcPlayer(PlayerOwner());
	if (H == None)
		return;

	if (Sender == ck_Hitmarker)        H.bHitmarker = ck_Hitmarker.IsChecked();
	else if (Sender == ck_DamageNumbers) H.bDamageNumbers = ck_DamageNumbers.IsChecked();
	else if (Sender == ck_Killfeed)    H.bKillfeed = ck_Killfeed.IsChecked();
	else if (Sender == ck_ArrowRing)   H.bArrowRing = ck_ArrowRing.IsChecked();
	else if (Sender == ck_EnemyHPBar)  H.bEnemyHPBar = ck_EnemyHPBar.IsChecked();
	else if (Sender == ck_RevengeMarker) H.bRevengeMarker = ck_RevengeMarker.IsChecked();
	else if (Sender == ck_MultikillPips) H.bMultikillPips = ck_MultikillPips.IsChecked();
	else if (Sender == ck_DeathRecap)  H.bDeathRecap = ck_DeathRecap.IsChecked();
	else if (Sender == ck_Killcam && GP != None) GP.bKillcam = ck_Killcam.IsChecked();
	else if (Sender == ck_PickupTimers) H.bPickupTimers = ck_PickupTimers.IsChecked();
	else if (Sender == ck_Desaturate)  H.bDesaturate = ck_Desaturate.IsChecked();
	else if (Sender == ck_Scoreboard)  H.bModernScoreboard = ck_Scoreboard.IsChecked();
	else if (Sender == ck_MVPCard)     H.bMVPCard = ck_MVPCard.IsChecked();
	else if (Sender == ck_SpectatorHUD) H.bSpectatorHUD = ck_SpectatorHUD.IsChecked();
	else if (Sender == ck_RJStats && GP != None) GP.bRJStats = ck_RJStats.IsChecked();
	else if (Sender == ck_Speedo && GP != None) GP.bShowSpeedometer = ck_Speedo.IsChecked();
	else if (Sender == ck_ViewmodelBob && GP != None) GP.bViewModelBob = ck_ViewmodelBob.IsChecked();

	H.SaveConfig();
	if (GP != None)
		GP.SaveConfig();
}

defaultproperties
{
	WinWidth=0.55
	WinHeight=0.9
	WinLeft=0.225
	WinTop=0.05
	bRenderWorld=True

	Begin Object Class=GUIButton Name=CloseButton
		Caption="CLOSE"
		WinWidth=0.2
		WinHeight=0.05
		WinLeft=0.4
		WinTop=0.92
		OnClick=GoldSrcSettingsPage.ButtonClicked
		bBoundToParent=true
	End Object
	b_Close=CloseButton

	Begin Object Class=moCheckBox Name=ckHitmarker
		Caption="Hitmarker"
		WinWidth=0.44
		WinLeft=0.03
		WinTop=0.06
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_Hitmarker=ckHitmarker

	Begin Object Class=moCheckBox Name=ckDamageNumbers
		Caption="Damage Numbers"
		WinWidth=0.44
		WinLeft=0.53
		WinTop=0.06
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_DamageNumbers=ckDamageNumbers

	Begin Object Class=moCheckBox Name=ckKillfeed
		Caption="Killfeed"
		WinWidth=0.44
		WinLeft=0.03
		WinTop=0.12
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_Killfeed=ckKillfeed

	Begin Object Class=moCheckBox Name=ckArrowRing
		Caption="Damage Arrow Ring"
		WinWidth=0.44
		WinLeft=0.53
		WinTop=0.12
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_ArrowRing=ckArrowRing

	Begin Object Class=moCheckBox Name=ckEnemyHPBar
		Caption="Enemy HP Bar"
		WinWidth=0.44
		WinLeft=0.03
		WinTop=0.18
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_EnemyHPBar=ckEnemyHPBar

	Begin Object Class=moCheckBox Name=ckRevengeMarker
		Caption="Revenge Marker"
		WinWidth=0.44
		WinLeft=0.53
		WinTop=0.18
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_RevengeMarker=ckRevengeMarker

	Begin Object Class=moCheckBox Name=ckMultikillPips
		Caption="Multikill Pips"
		WinWidth=0.44
		WinLeft=0.03
		WinTop=0.24
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_MultikillPips=ckMultikillPips

	Begin Object Class=moCheckBox Name=ckDeathRecap
		Caption="Death Recap"
		WinWidth=0.44
		WinLeft=0.53
		WinTop=0.24
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_DeathRecap=ckDeathRecap

	Begin Object Class=moCheckBox Name=ckKillcam
		Caption="Killcam (2s)"
		WinWidth=0.44
		WinLeft=0.03
		WinTop=0.30
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_Killcam=ckKillcam

	Begin Object Class=moCheckBox Name=ckPickupTimers
		Caption="Pickup Respawn Timers"
		WinWidth=0.44
		WinLeft=0.53
		WinTop=0.30
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_PickupTimers=ckPickupTimers

	Begin Object Class=moCheckBox Name=ckDesaturate
		Caption="Low-HP Desaturation"
		WinWidth=0.44
		WinLeft=0.03
		WinTop=0.36
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_Desaturate=ckDesaturate

	Begin Object Class=moCheckBox Name=ckScoreboard
		Caption="Modern Scoreboard"
		WinWidth=0.44
		WinLeft=0.53
		WinTop=0.36
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_Scoreboard=ckScoreboard

	Begin Object Class=moCheckBox Name=ckMVPCard
		Caption="End-of-Match MVP Card"
		WinWidth=0.44
		WinLeft=0.03
		WinTop=0.42
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_MVPCard=ckMVPCard

	Begin Object Class=moCheckBox Name=ckSpectatorHUD
		Caption="Spectator HUD"
		WinWidth=0.44
		WinLeft=0.53
		WinTop=0.42
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_SpectatorHUD=ckSpectatorHUD

	Begin Object Class=moCheckBox Name=ckRJStats
		Caption="Rocket-Jump Stats"
		WinWidth=0.44
		WinLeft=0.03
		WinTop=0.48
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_RJStats=ckRJStats

	Begin Object Class=moCheckBox Name=ckSpeedo
		Caption="Speedometer"
		WinWidth=0.44
		WinLeft=0.53
		WinTop=0.48
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_Speedo=ckSpeedo

	Begin Object Class=moCheckBox Name=ckViewmodelBob
		Caption="Viewmodel Bob"
		WinWidth=0.44
		WinLeft=0.03
		WinTop=0.54
		OnChange=GoldSrcSettingsPage.CheckBoxChanged
	End Object
	ck_ViewmodelBob=ckViewmodelBob
}
