class GoatymonWorld extends GGMutator;

var array<GGGoat> mGoats;
var float timeElapsed;
var float managementTimer;
var float SRTimeElapsed;
var float spawnRemoveTimer;
var float spawnRadius;
var int minGoatymonCount;
var int maxGoatymonCount;

var array<GGNpcGoatymon> mGoatymonPool;
var float mTimeNotLookingForHide;
var array<GGNpcGoatymon> delayedRemovableNPCs;
var int mGoatymonNPCCount;
var array<int> mGoatymonNPCsToSpawnForPlayer;

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;

	goat = GGGoat( other );

	if( goat != none )
	{
		if( IsValidForPlayer( goat ) )
		{
			mGoats.AddItem(goat);
		}
	}

	super.ModifyPlayer( other );
}

simulated event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	timeElapsed=timeElapsed+deltaTime;
	if(timeElapsed > managementTimer)
	{
		timeElapsed=0.f;
		//ManageGoatymonNPCs();
		GenerateGoatymonLists();
	}
	SRTimeElapsed=SRTimeElapsed+deltaTime;
	if(SRTimeElapsed > spawnRemoveTimer)
	{
		SRTimeElapsed=0.f;
		RemoveGoatymonFromList();
		SpawnGoatymonFromList();
	}
}

function GenerateGoatymonLists()
{
	local GGNPCGoatymon goatymonNPC;
	local GGAIControllerGoatymon goatymonAI;
	local array<int> goatymonNPCsForPlayer;
	local bool isRemovable;
	local int nbPlayers, i;
	local vector dist;

	nbPlayers=mGoats.Length;
	mGoatymonNPCsToSpawnForPlayer.Length = 0;
	mGoatymonNPCsToSpawnForPlayer.Length = nbPlayers;
	goatymonNPCsForPlayer.Length = nbPlayers;
	mGoatymonNPCCount=0;
	//Find all Goatymon and infected NPCs close to each player
	foreach WorldInfo.AllControllers(class'GGAIControllerGoatymon', goatymonAI)
	{
		goatymonNPC=GGNPCGoatymon(goatymonAI.mMyPawn);
		if(goatymonNPC != none && goatymonAI.trainer == none && !goatymonAI.isInBattle)
		{
			//WorldInfo.Game.Broadcast(self, GoatymonAI $ " possess " $ GoatymonNPC);
			mGoatymonNPCCount++;
			isRemovable=true;

			for(i=0 ; i<nbPlayers ; i++)
			{
				dist=mGoats[i].Location - goatymonNPC.Location;
				if(VSize2D(dist) < spawnRadius)
				{
					goatymonNPCsForPlayer[i]++;
					isRemovable=false;
				}
			}

			if(isRemovable)
			{
				goatymonNPC.mHideImmediately=true;//Make sure the NPC dissapear
				DelayedHideNPC(goatymonNPC);
			}
		}
	}

	for(i=0 ; i<nbPlayers ; i++)
	{
		mGoatymonNPCsToSpawnForPlayer[i]=minGoatymonCount-goatymonNPCsForPlayer[i];
	}
	//WorldInfo.Game.Broadcast(self, "Goatymons to spawn " $ mGoatymonNPCsToSpawnForPlayer[0]);
}

function AddGoatymonToPool(GGNpcGoatymon goatymonNPC)
{
	local vector randomLoc;
	local GGAIControllerGoatymon goatymonAI;

	if(goatymonNPC == none
	|| goatymonNPC.bPendingDelete
	|| mGoatymonPool.Find(goatymonNPC) != INDEX_NONE)
		return;
	//Make sure we are not recycling a captured or fighting goatymon
	goatymonAI=GGAIControllerGoatymon(goatymonNPC.Controller);
	if(goatymonNPC != none
	&& (goatymonAI.trainer != none
	 || goatymonAI.isInBattle))
	 	return;

	//WorldInfo.Game.Broadcast(self, "Add zombie to pool " $ goatymonNPC $ ", size=" $ mGoatymonPool.Length+1);
	goatymonNPC.SetHidden(true);
	goatymonNPC.SetCollision( false, false, false );
	goatymonNPC.SetTickIsDisabled( true );
	if(!goatymonNPC.mIsRagdoll)
	{
		goatymonNPC.SetRagdoll(true);
	}
	goatymonNPC.DisableStandUp(class'GGNpc'.const.SOURCE_EDITOR);
	goatymonNPC.SetPhysics(PHYS_None);
	randomLoc=vect(0, 0, -900) + (vect(10, 0, 0) * int(GetRightMost(goatymonNPC.name))) + (vect(0, 1, 0) * (Rand(2000)-1000));
	goatymonNPC.SetLocation(randomLoc);
	goatymonNPC.mHideImmediately=false;
	mGoatymonPool.AddItem(goatymonNPC);
}

function bool SpawnGoatymonFromPool(vector spawnLoc, rotator spawnRot)
{
	local GGNPCGoatymon spawnedNPC;

	if(mGoatymonPool.Length == 0)
	{
		spawnedNPC=Spawn(class'GGNPCGoatymon', self,, spawnLoc, spawnRot,, true);
		//WorldInfo.Game.Broadcast(self, "Spawn new zombie " $ spawnedNPC);
	}
	else
	{
		spawnedNPC=mGoatymonPool[mGoatymonPool.Length-1];
		mGoatymonPool.RemoveItem(spawnedNPC);
		if(GGAIControllerGoatymon(spawnedNPC.Controller) != none)
		{
			GGAIControllerGoatymon(spawnedNPC.Controller).FullRegen();
		}
		//WorldInfo.Game.Broadcast(self, "Get zombie from pool " $ spawnedNPC);
		//Force unragdoll instantly
		spawnedNPC.SetLocation(spawnLoc);
		spawnedNPC.SetPhysics(PHYS_RigidBody);
		spawnedNPC.SetCollision( true, true, true );
		spawnedNPC.EnableStandUp(class'GGNpc'.const.SOURCE_EDITOR);
		spawnedNPC.SetOnFire(false);
		spawnedNPC.SetIsInWater(false);
		spawnedNPC.ReleaseFromHogtie();
		if(spawnedNPC.mIsRagdoll)
		{
			spawnedNPC.Velocity=vect(0, 0, 0);
			spawnedNPC.StandUp();
			spawnedNPC.mesh.PhysicsWeight=0;
			spawnedNPC.TerminateRagdoll(0.f);
		}
		spawnedNPC.SetDrawScale(1.f);
		spawnedNPC.mesh.SetScale(1.f);
		spawnedNPC.SetLocation(spawnLoc);
		spawnedNPC.SetRotation(spawnRot);
		spawnedNPC.SetTickIsDisabled( false );
		spawnedNPC.SetHidden(false);
	}

	if(spawnedNPC == none
	|| spawnedNPC.bPendingDelete
	|| !spawnedNPC.IsAliveAndWell())
	{
		DestroyNPC(spawnedNPC);
		return false;
	}

	spawnedNPC.SetRandomMesh();
	spawnedNPC.SetPhysics( PHYS_Falling );
	if(GGAIControllerGoatymon(spawnedNPC.Controller) != none)
	{
		GGAIControllerGoatymon(spawnedNPC.Controller).SetStatsForGoatymon(spawnedNPC);
	}

	return true;
}

function SpawnGoatymonFromList()
{
	local int nbPlayers, i;
	local vector center;

	//Spawn new Goatymon NPCs if needed
	nbPlayers=mGoats.Length;
	for(i=0 ; i<nbPlayers ; i++)
	{
		if(mGoatymonNPCsToSpawnForPlayer.Length > 0 && mGoatymonNPCsToSpawnForPlayer[i] > 0)
		{
			center=mGoats[i].mIsRagdoll?mGoats[i].mesh.GetPosition():mGoats[i].Location;
			if(SpawnGoatymonFromPool(GetRandomSpawnLocation(center), GetRandomRotation()))
			{
				mGoatymonNPCsToSpawnForPlayer[i]--;
				mGoatymonNPCCount++;
			}
			break;
		}
	}
}

function RemoveGoatymonFromList()
{
	local int i;

	for(i=delayedRemovableNPCs.Length-1 ; i>=0 ; i--)
	{
		if(`TimeSince( delayedRemovableNPCs[i].LastRenderTime ) > mTimeNotLookingForHide
		|| delayedRemovableNPCs[i].mHideImmediately)
		{
			AddGoatymonToPool(delayedRemovableNPCs[i]);
			delayedRemovableNPCs.RemoveItem(delayedRemovableNPCs[i]);
		}
	}
}

function DelayedHideNPC(GGNpcGoatymon npc)
{
	delayedRemovableNPCs.AddItem(npc);
}

function DestroyNPC(GGPawn gpawn)
{
	local int i;

	if(gpawn == none || gpawn.bPendingDelete)
		return;

	for( i = 0; i < gpawn.Attached.Length; i++ )
	{
		if(GGGoat(gpawn.Attached[i]) == none)
		{
			gpawn.Attached[i].ShutDown();
			gpawn.Attached[i].Destroy();
		}
	}
	gpawn.ShutDown();
	gpawn.Destroy();
}

function vector GetRandomSpawnLocation(vector center)
{
	local vector dest;
	local rotator rot;
	local float dist;
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;

	rot=GetRandomRotation();

	dist=spawnRadius;
	dist=RandRange(dist/2.f, dist);

	dest=center+Normal(Vector(rot))*dist;
	traceStart=dest;
	traceEnd=dest;
	traceStart.Z=10000.f;
	traceEnd.Z=-3000;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
	if( hitActor == none )
	{
		hitLocation = traceEnd;
	}

	hitLocation.Z+=85;

	return hitLocation;
}

function rotator GetRandomRotation()
{
	local rotator rot;

	rot=Rotator(vect(1, 0, 0));
	rot.Yaw+=RandRange(0.f, 65536.f);

	return rot;
}

DefaultProperties
{
	mTimeNotLookingForHide=0.5f
	managementTimer=1.f
	spawnRemoveTimer=0.1f
	spawnRadius=5000.f
	minGoatymonCount=5
	maxGoatymonCount=10
}