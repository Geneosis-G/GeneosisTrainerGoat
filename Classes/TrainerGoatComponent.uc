class TrainerGoatComponent extends GGMutatorComponent
	config(Geneosis);

var GGGoat gMe;
var TrainerGoat myMut;
var config bool mUseSpeech;//Moved here from TrainerGoat because mixing static config and non-static config is not working well
var config bool mIsPvPEnabled;
var bool mLastPvP;
var float mLastSpeed;

const NB_GOATYBALLS = 6;

var GoatyballsInventory mGBInventory;
var Goatyball mGoatyballs[NB_GOATYBALLS];
var bool areBallsDeployed;
var int currentBallID;
var bool mUseMasterBall;
var float mLastSaveTime;
var bool mIsRightClicking;
var bool mIsLickPressed;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	local int i;
	local array<GGNPCGoatymon> capturedGoatymons;

	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=TrainerGoat(owningMutator);

		// Create inventory
	    mGBInventory = gMe.Spawn( class'GoatyballsInventory', gMe );
		mGBInventory.InitiateInventory();
		LoadCapturedGoatymons(capturedGoatymons);

		for(i=0 ; i<NB_GOATYBALLS ; i++)
		{
			if(mGoatyballs[i] == none || mGoatyballs[i].bPendingDelete)
			{
				mGoatyballs[i]=SpawnGoatyball();
			}
			//Capture loaded goatymons
			if(i<capturedGoatymons.Length)
			{
				GGAIControllerGoatymon(capturedGoatymons[i].Controller).trainer=gMe;//Just to avoid getting a "gotcha" log
				mGoatyballs[i].TryToCapture(capturedGoatymons[i], true);
			}
		}
	}
}

function LoadCapturedGoatymons(out array<GGNPCGoatymon> capturedGoatymons)
{
	myMut.LoadCapturedGoatymonsForPlayer(capturedGoatymons, gMe.mCachedSlotNr);
}

function SaveCapturedGoatymons()
{
	local int i;
	local array<GGNPCGoatymon> capturedGoatymons;
	local GGNPCGoatymon capturedGoatymon;
	local float timeNow;

	timeNow=myMut.WorldInfo.TimeSeconds;
	if(timeNow-mLastSaveTime < 1.f)//do not save more than once every second
		return;

 	for(i=0 ; i<NB_GOATYBALLS ; i++)
 	{
 		capturedGoatymon=GGNPCGoatymon(mGoatyballs[i].mMyActor);
		if(capturedGoatymon != none)
		{
			capturedGoatymons.AddItem(capturedGoatymon);
		}
 	}
 	mLastSaveTime=timeNow;
	myMut.SaveCapturedGoatymonsForPlayer(capturedGoatymons, gMe.mCachedSlotNr);
}

function Goatyball SpawnGoatyball()
{
	local Goatyball newGoatyball;

	newGoatyball=gMe.Spawn(class'Goatyball', gMe,,,,, true);
	newGoatyball.OnGoatymonReleased=OnGoatymonReleased;
	newGoatyball.OnGoatymonCatched=OnGoatymonCatched;

	return newGoatyball;
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PlayerController( gMe.Controller ).PlayerInput );

	if( keyState == KS_Down )
	{
		if(newKey == 'LEFTCONTROL' || newKey == 'XboxTypeS_DPad_Down')
		{
			NextBall();
		}

		if(localInput.IsKeyIsPressed("GBA_Special", string( newKey )))
		{
			ThrowGoatyball();
		}

		if(localInput.IsKeyIsPressed("GBA_Baa", string( newKey )))
		{
			GetBack();
		}

		if(localInput.IsKeyIsPressed("GBA_AbilityBite", string( newKey )))
		{
			mIsLickPressed=true;
		}

		if(localInput.IsKeyIsPressed("RightMouseButton", string( newKey )) || newKey == 'XboxTypeS_LeftTrigger')
		{
			mIsRightClicking=true;
			if(mIsLickPressed)
			{
				gMe.SetTimer(2.f, false, NameOf(ToggleDeployGoatballs), self);
			}
		}
	}
	else if( keyState == KS_Up )
	{
		if(localInput.IsKeyIsPressed("GBA_AbilityBite", string( newKey )))
		{
			mIsLickPressed=false;
		}

		if(localInput.IsKeyIsPressed("RightMouseButton", string( newKey )) || newKey == 'XboxTypeS_LeftTrigger')
		{
			mIsRightClicking=false;
			if(gMe.IsTimerActive(NameOf(ToggleDeployGoatballs), self))
			{
				gMe.ClearTimer(NameOf(ToggleDeployGoatballs), self);
			}
		}
	}
}

function NextBall()
{
	local int i;

	if(!areBallsDeployed)
		return;

	currentBallID++;
	if(currentBallID == NB_GOATYBALLS)
	{
		currentBallID=0;
	}
	ComputeDesiredBallPositions();
	for(i=0 ; i<NB_GOATYBALLS ; i++)
	{
		if(!mGoatyballs[i].isThrown)
		{
			mGoatyballs[i].ComeBack();
		}
	}
}

function ThrowGoatyball()
{
	local GGAIControllerGoatymon goatymonContr;

	if(!areBallsDeployed || gMe.mIsRagdoll)
		return;

	if(mGoatyballs[currentBallID] == none)
	{
		mGoatyballs[currentBallID]=SpawnGoatyball();
	}
	if(mUseMasterBall)
	{
		mGoatyballs[currentBallID].mForceCapture=true;
	}
	if(mGoatyballs[currentBallID].ThrowGoatyball())
	{
		if(!mGoatyballs[currentBallID].isEmpty && mGoatyballs[currentBallID].mMyPawn != none)
		{
			goatymonContr=GGAIControllerGoatymon(mGoatyballs[currentBallID].mMyPawn.Controller);
			if(goatymonContr != none && PlayerController(gMe.Controller) != none)
			{
				SayText(PlayerController(gMe.Controller), "Go " $ goatymonContr.mNPCName $ "!");
			}
		}
	}
}

function GetBack()
{
	if(!areBallsDeployed)
		return;
	//myMut.WorldInfo.Game.Broadcast(myMut, mGoatyballs[currentBallID] @ "GetBack" @ mGoatyballs[currentBallID].mMyActor);
	if(mGoatyballs[currentBallID].mMyActor != none && mGoatyballs[currentBallID].isEmpty)
	{
		mGoatyballs[currentBallID].TryToCapture(mGoatyballs[currentBallID].mMyActor);
	}
}

function ToggleDeployGoatballs()
{
	local int i;

	areBallsDeployed=!areBallsDeployed;//myMut.WorldInfo.Game.Broadcast(myMut, "ToggleDeployGoatballs=" $ areBallsDeployed);
	if(areBallsDeployed)
	{
		ShowHideBalls();
	}
	else
	{
		gMe.SetTimer(1.f, false, NameOf(ShowHideBalls), self);
	}
	ComputeDesiredBallPositions();
	for(i=0 ; i<NB_GOATYBALLS ; i++)
	{
		mGoatyballs[i].ComeBack();
	}
}

function ShowHideBalls()
{
	local int i;
	//myMut.WorldInfo.Game.Broadcast(myMut, "HideBalls=" $ hide);
	for(i=0 ; i<NB_GOATYBALLS ; i++)
	{
		mGoatyballs[i].SetHidden(!areBallsDeployed);
	}
}

function OnGoatymonReleased(Goatyball ball, Actor releasedActor)
{
	local int i, invSize;
	local GGAIControllerGoatymon releasedAI, fightingAI;
	local GGPawn previousEnemy;

	invSize=mGBInventory.mInventorySlots.Length;
	for(i=0 ; i<invSize ; i++)
	{
		if(mGBInventory.mInventorySlots[i].mItem == GGInventoryActorInterface(releasedActor))
		{
   			mGBInventory.baseSpawnLoc=ball.Location;
			mGBInventory.RemoveFromInventory(i);
			break;
		}
	}
	releasedAI=GGNpc(releasedActor)!=none?GGAIControllerGoatymon(GGNpc(releasedActor).Controller):releasedAI;
	if(mIsRightClicking && releasedAI != none)//if right clicking start battle or switch goatymon in current battle
	{
		releasedAI.mCanFight=true;
		for(i=0 ; i<NB_GOATYBALLS ; i++)
		{
			if(mGoatyballs[i] == ball)
					continue;

			if(mGoatyballs[i].mMyPawn != none)
			{
				fightingAI=GGAIControllerGoatymon(mGoatyballs[i].mMyPawn.Controller);
				if(fightingAI != none && fightingAI.isInBattle)//Switch goatymon
				{
					previousEnemy=GGPawn(fightingAI.mBattleEnemy);
					fightingAI.EndBattle();
					releasedAI.FightWith(previousEnemy, true);
					break;
				}
			}
		}
	}
}

function OnGoatymonCatched(Goatyball ball, Actor catchedActor)
{
	local int i;
	local GGPawn catchedPawn;
	local GGAIControllerGoatymon goatymonContr;
	//myMut.WorldInfo.Game.Broadcast(myMut, "OnGoatymonCatched" @ ball @ catchedActor);
	if(ball.mMyActor != catchedActor)// Swap pawn ball if there was already someone in this ball or if this item was already in another ball
	{
		if(ball.mMyPawn != none)
		{
			goatymonContr=GGAIControllerGoatymon(ball.mMyPawn.Controller);
			if(goatymonContr != none)// Realease Goatymon if his ball is used on someone else
			{
				goatymonContr.mGoatyballContainer=none;
			}
		}
		for(i=0 ; i<NB_GOATYBALLS ; i++)
		{
			if(mGoatyballs[i] == ball || mGoatyballs[i] == none)
				continue;

			if(mGoatyballs[i].mMyActor == catchedActor)
			{
				mGoatyballs[i].mMyActor=ball.mMyActor;
				mGoatyballs[i].mMyPawn=ball.mMyPawn;
				if(goatymonContr != none)
				{
					goatymonContr.mGoatyballContainer=mGoatyballs[i];
				}
				break;
			}
		}
		// if Goatymon have no ball any more, relase it
		if(goatymonContr != none && goatymonContr.mGoatyballContainer == none)
		{
			goatymonContr.OnReleased();
		}
	}
	mGBInventory.AddToInventory(GGInventoryActorInterface(catchedActor));

	catchedPawn=GGPawn(catchedActor);
	if(catchedPawn != none)
	{
		goatymonContr=GGAIControllerGoatymon(catchedPawn.Controller);
		if(goatymonContr != none)
		{
			goatymonContr.OnCaptured(self, gMe, ball);
			if(ball.mMyActor == catchedActor && PlayerController(gMe.Controller) != none)
			{
				SayText(PlayerController(gMe.Controller), "Get back");
			}
		}
	}
	myMut.mLastBallUsed=ball;
}
// Stop healing for every Goatymon of this trainer when battle start
function OnBattleStarted()
{
	DisableGoatymonsRegen();
}
// Start healing for every Goatymon of this trainer when all battle stopped
function OnBattleEnded(bool battleWon)
{
	local int i;
	local GGAIControllerGoatymon goatymonContr;
	local bool isBattleRunning;

	isBattleRunning=false;
	for(i=0 ; i<NB_GOATYBALLS ; i++)
	{
		if(mGoatyballs[i].mMyPawn != none)
		{
			goatymonContr=GGAIControllerGoatymon(mGoatyballs[i].mMyPawn.Controller);
			if(goatymonContr != none && goatymonContr.isInBattle)
			{
				isBattleRunning=true;
				break;
			}
		}
	}

	if(!isBattleRunning && !default.mIsPvPEnabled)
	{
		EnableGoatymonsRegen();
	}
}

function Tick( float deltaTime )
{
	if(!IsZero(gMe.Velocity) && gMe.IsTimerActive(NameOf(ToggleDeployGoatballs), self))
	{
		gMe.ClearTimer(NameOf(ToggleDeployGoatballs), self);
	}
	if(VSize(gMe.Velocity) < 0.1f && mLastSpeed > 0.1f)
	{
		SaveCapturedGoatymons();
	}

	ComputeDesiredBallPositions();

	if(default.mIsPvPEnabled && !mLastPvP)//PvP enabled
	{
		DisableGoatymonsRegen();
	}
	if(!default.mIsPvPEnabled && mLastPvP)//PvP disabled
	{
		EnableGoatymonsRegen();
	}

	mLastSpeed=VSize(gMe.Velocity);
	mLastPvP=default.mIsPvPEnabled;
}

function EnableGoatymonsRegen()
{
	local int i;
	local GGAIControllerGoatymon goatymonContr;

	for(i=0 ; i<NB_GOATYBALLS ; i++)
	{
		if(mGoatyballs[i].mMyPawn != none)
		{
			goatymonContr=GGAIControllerGoatymon(mGoatyballs[i].mMyPawn.Controller);
			if(goatymonContr != none)
			{
				goatymonContr.StartHealing();
			}
		}
	}
}

function DisableGoatymonsRegen()
{
	local int i;
	local GGAIControllerGoatymon goatymonContr;

	for(i=0 ; i<NB_GOATYBALLS ; i++)
	{
		if(mGoatyballs[i].mMyPawn != none)
		{
			goatymonContr=GGAIControllerGoatymon(mGoatyballs[i].mMyPawn.Controller);
			if(goatymonContr != none)
			{
				goatymonContr.StopHealing();
			}
		}
	}
}

function ComputeDesiredBallPositions()
{
	local vector desiredPos;
	local rotator dir;
	local int i;
	local bool goatymonFound;

	goatymonFound=false;
	for(i=0 ; i<NB_GOATYBALLS ; i++)
	{
		if(!areBallsDeployed)
		{
			desiredPos=gMe.Location;
		}
		else
		{
			dir=gMe.Rotation;
			dir.Yaw+=(i-currentBallID)*(65536.f/NB_GOATYBALLS);
			desiredPos=gMe.Location + Normal(vector(dir))*(gMe.GetCollisionRadius() + mGoatyballs[i].ballDistance);
		}
		mGoatyballs[i].desiredPosition=desiredPos;

		goatymonFound=goatymonFound || ContainGoatymon(mGoatyballs[i]);
	}
	mUseMasterBall=!goatymonFound;
}

function bool ContainGoatymon(Goatyball ball)
{
	return !(ball == none || ball.mMyPawn == none || GGAIControllerGoatymon(ball.mMyPawn.Controller) == none);
}

function OnPlayerRespawn( PlayerController respawnController, bool died )
{
	local int i;
	local GGAIControllerGoatymon goatymonContr;

	super.OnPlayerRespawn(respawnController, died);

	if(respawnController == gMe.Controller)
	{
		for(i=0 ; i<NB_GOATYBALLS ; i++)
		{
			// Regen all Goatymons
			if(mGoatyballs[i].mMyPawn != none)
			{
				goatymonContr=GGAIControllerGoatymon(mGoatyballs[i].mMyPawn.Controller);
				if(goatymonContr != none)
				{
					goatymonContr.FullRegen();
				}
			}
			// Call back all to Goatyballs
			if(mGoatyballs[i].mMyActor != none && mGoatyballs[i].isEmpty)
			{
				mGoatyballs[i].TryToCapture(mGoatyballs[i].mMyActor);
			}
		}
		if(!areBallsDeployed)
		{
			ToggleDeployGoatballs();
		}
	}
}

static function bool ToggleUseSpeech()
{
	//class'WorldInfo'.static.GetWorldInfo().Game.Broadcast(class'WorldInfo'.static.GetWorldInfo(), "ToggleUseSpeech");
	default.mUseSpeech=!default.mUseSpeech;
	static.StaticSaveConfig();
	return default.mUseSpeech;
}

static function bool TogglePvP()
{
	default.mIsPvPEnabled=!default.mIsPvPEnabled;
	static.StaticSaveConfig();
	return default.mIsPvPEnabled;
}

static function SayText(PlayerController PC, string text)
{
	//PC.WorldInfo.Game.Broadcast(PC, "SayText 1 mUseSpeech=" $ default.mUseSpeech);
	if(default.mUseSpeech)
	{
		PC.SpeakTTS(text);
	}
	PC.WorldInfo.Game.Broadcast(PC, text);
	//PC.WorldInfo.Game.Broadcast(PC, "SayText 2 mUseSpeech=" $ default.mUseSpeech);
}

defaultproperties
{
	areBallsDeployed=true
	mUseMasterBall=true
}