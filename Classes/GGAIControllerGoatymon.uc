class GGAIControllerGoatymon extends GGAIController;

enum EAttackType
{
    EAT_None,
	EAT_Charge,
    EAT_Jump,
    EAT_Uppercut,
    EAT_Throw
};
var EAttackType mCurrentAttackType;

struct BoneArray
{
	var array<name> names;
};

var bool postRenderSet;
var string mNPCName;
var float mSizeRatio;

var vector mNameTagOffset;
var color mNameTagColor;

/** Colors for the HP bar, 0, 50, 100 is lerped between on 0, 50 and 100 % health */
var color mHpBarBackgroundColor;
var color mHpBarColor0;
var color mHpBarColor50;
var color mHpBarColor100;

/** The MMO npc's have a health */
var int mHealth;
var int mHealthMax;
var bool isDead;
var bool shouldHeal;
var float mHealRate;
var float mAccumulatedHealth;
var float mBaseHealRate;

var bool isArrived;
var float totalTime;
var float mDestinationOffset;
var GGPawn mPawnToFollow;
var GGPawn mPawnFollowingMe;

var kActorSpawnable destActor;
var bool cancelNextRagdoll;
var bool mIsInAir;
var name mLastState;

var bool isPossessing;
// Battle infos
var GGGoat trainer;
var bool isInBattle;
var bool mCanFight;
var float mBattleDistance;
var bool mIsAttacking;//This means both Goatymons were ready and the attack started
var float mAttackMomentum;
var Pawn mBattleEnemy;
var vector mBattlePos;
var vector mEnemyBattlePos;
var bool mLosePriority;
var bool mCollidedWithEnemy;

// Jump attack
var bool isJumpDone;
var vector mLastVelocity;

// Throw attack
var ThrowAttack mThrownItem;
var ThrowAttack mThrowAttackModel;
var vector mThrowAttackSpinVelocity;
var int remainingThrows;
var int throwHits;
var float mAttackOffset;
var float mShootVelocity;
var rotator mAimAdjust;
var float mSpinSpeed;

var Goatyball mGoatyballContainer;

delegate OnBattleStarted();
delegate OnBattleEnded(bool battleWon);

/**
 * Cache the NPC and mOriginalPosition
 */
event Possess(Pawn inPawn, bool bVehicleTransition)
{
	local ProtectInfo destination;
	local GGNpcMMOAbstract MMONpc;
	local GGNpcZombieGameModeAbstract zombieNpc;

	if(mMyPawn == inPawn)//for some resons this happen sometimes
		return;

	super.Possess(inPawn, bVehicleTransition);

	isPossessing=true;
	if(mMyPawn == none)
		return;

	mMyPawn.mProtectItems.Length=0;
	SpawnDestActor();
	destination.ProtectItem = mMyPawn;
	destination.ProtectRadius = 1000000.f;
	mMyPawn.mProtectItems.AddItem(destination);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mMyPawn.mProtectItems[0].ProtectItem=" $ mMyPawn.mProtectItems[0].ProtectItem);
	if( !WorldInfo.bStartup )
	{
		SetPostRenderFor();
	}
	else
	{
		SetTimer( 1.0f, false, NameOf( SetPostRenderFor ));
	}

	SetStatsForGoatymon(GGNPCGoatymon(mMyPawn));

	mMyPawn.SightRadius=class'GoatymonWorld'.Default.spawnRadius;

	mMyPawn.mStandUpDelay=2.0f;
	mMyPawn.EnableStandUp( class'GGNpc'.const.SOURCE_EDITOR );
	mMyPawn.mTimesKnockedByGoat=0;
	mMyPawn.mTimesKnockedByGoatStayDownLimit=1000000.f;
	MMONpc = GGNpcMMOAbstract(mMyPawn);
	if(MMONpc != none)
	{
		MMONpc.mHealth=max(MMONpc.default.mHealthMax, MMONpc.default.mHealth);
		MMONpc.LifeSpan=0.f;
		MMONpc.mNameTagColor=MakeColor(255, 255, 255, 0);
		MMONpc.mHpBarBackgroundColor=MakeColor(0, 0, 0, 0);
		MMONpc.mHpBarColor0=MakeColor(255, 0, 0, 0);
		MMONpc.mHpBarColor50=MakeColor(255, 255, 0, 0);
		MMONpc.mHpBarColor100=MakeColor(0, 255, 0, 0);
	}
	zombieNpc = GGNpcZombieGameModeAbstract(mMyPawn);
	if(zombieNpc != none)
	{
		zombieNpc.mHealth=zombieNpc.default.mHealthMax;
		zombieNpc.mIsPendingDeath=false;
		zombieNpc.mCanDie=false;
		zombieNpc.LifeSpan=0.f;
	}
}

function SpawnDestActor()
{
	if(destActor == none || destActor.bPendingDelete)
	{
		destActor = Spawn(class'kActorSpawnable', mMyPawn,,,,,true);
		destActor.SetHidden(true);
		destActor.SetPhysics(PHYS_None);
		destActor.CollisionComponent=none;
	}
	destActor.SetLocation(mMyPawn.Location);
}

function SetGoatymonHealth(optional GGNPCGoatymon goatymon)
{
	if(goatymon != none)
	{
		mHealthMax=goatymon.mMaxHealth;
		mHealth=mHealthMax;
		mSizeRatio=mHealthMax;
	}
	else
	{
		mSizeRatio=class'GGNPCGoatymon'.static.GetRandomRatio(mMyPawn);
		mHealthMax=mSizeRatio;
		mHealth=mHealthMax;
	}
}

function SetStatsForGoatymon(GGNPCGoatymon goatymon)
{
	mMyPawn.mAttackRange=4.f * mMyPawn.GetCollisionRadius();
	mNameTagOffset.Z=-mMyPawn.GetCollisionHeight();
	SetGoatymonHealth(goatymon);
	SetGoatymonRandomBoneScalesAndName();
}

function SetGoatymonRandomBoneScalesAndName()
{
	local array<BoneArray> boneTree;
	local array<name> boneNames;
	local name boneName;
	local int i, j, level, growFactor;
	local SkelControlBase skelControl;
	local bool boneFound;
	local float newScale;

	mNPCName=mMyPawn.GetActorName();
	return;// The result is too ugly :/

	mMyPawn.mesh.GetBoneNames(boneNames);
	level=0;
	boneFound=true;
	while(boneFound)
	{
		boneFound=false;
		boneTree.Add(1);
		for(i=0 ; i<boneNames.Length ; i=i)
		{
			if(level-1 < 0)
			{
				if(mMyPawn.mesh.BoneIsChildOf(boneNames[i], 'Root'))
				{
					boneTree[level].names.AddItem(boneNames[i]);
					boneNames.Remove(i, 1);
					boneFound=true;
				}
			}
			else
			{
				for(j=0 ; j<boneTree[level-1].names.Length ; ++j)
				{
					if(mMyPawn.mesh.BoneIsChildOf(boneNames[i], boneNames[j]))
					{
						boneTree[level].names.AddItem(boneNames[i]);
						boneNames.Remove(i, 1);
						boneFound=true;
						break;
					}
				}
			}

			if(!boneFound)
			{
				++i;
			}
		}
		level++;
	}

	for(level=0 ; level<boneTree.Length ; ++level)
	{
		newScale = GetRandomFloat();
		if(newScale != 1.f)
		{
			if(growFactor != 0)
			{
				if((newScale > 1.f && growFactor > 0)
				|| (newScale < 1.f && growFactor < 0))
				{
					newScale=1.f/newScale;
				}
			}
			growFactor=newScale>1.f?1:-1;
		}

		MixName(level, newScale);
		for(i=0 ; i<boneTree[level].names.Length ; ++i)
		{
			boneName = boneTree[level].names[i];
			skelControl = mMyPawn.mesh.FindSkelControl( boneName );
			if( skelControl == none )
			{
				if( mMyPawn.Mesh.MatchRefBone( boneName ) != INDEX_NONE )
				{
					skelControl = mMyPawn.Mesh.AddSkelControl( boneName, class'SkelControlSingleBone' );
					skelControl.ControlName = boneName;
				}
			}

			if( skelControl != none )
			{
				skelControl.BoneScale = newScale;

				skelControl.SetSkelControlStrength( 0.0f, 0.0f );
				skelControl.SetSkelControlStrength( 1.0f, 1.0f );
			}
		}
	}
	if(Len(mNPCName) > 0)
	{
		mNPCName=Locs(mNPCName);
		mNPCName=Caps(Mid(mNPCName, 0, 1)) $ Right(mNPCName, Len(mNPCName)-1);
	}
}

function MixName(int level, float value)
{
	local int index, nextIndex;
	local string tmp;

	if(mNPCName == "")
		return;

	index = level % Len(mNPCName);
	nextIndex = (level + 1) % Len(mNPCName);
	if(value > 1.f)
	{
		mNPCName = mNPCName $ Mid(mNPCName, index, 1);
	}
	else if(value < 1.f)
	{
		tmp=Mid(mNPCName, index, 1);
		mNPCName = Left(mNPCName, index) $ Mid(mNPCName, nextIndex, 1) $ Right(mNPCName, Len(mNPCName)-1-index);
		mNPCName = Left(mNPCName, nextIndex) $ tmp $ Right(mNPCName, Len(mNPCName)-1-nextIndex);
	}
}

//Pick a random value in 11/10, 0, 10/11
function float GetRandomFloat()
{
	switch(Rand(3))
	{
		case 0:
			return 11.f/10.f;
		case 1:
			return 1.f;
		case 2:
			return 10.f/11.f;
	}

	return 1.f;
}

function RenameGoatymon(string newName)
{
	mNPCName=newName;
	if(GGNPCGoatymon(mMyPawn) != none)
	{
		GGNPCGoatymon(mMyPawn).SetName(newName);
	}
}

event UnPossess()
{
	local GGNpcMMOAbstract MMONpc;
	local GGNpcZombieGameModeAbstract zombieNpc;

	if(mMyPawn != none)
	{
		mMyPawn.mStandUpDelay=mMyPawn.default.mStandUpDelay;
		mMyPawn.mTimesKnockedByGoat=0.f;
		mMyPawn.mTimesKnockedByGoatStayDownLimit=mMyPawn.default.mTimesKnockedByGoatStayDownLimit;
		mMyPawn.SightRadius=mMyPawn.default.SightRadius;
		mMyPawn.mProtectItems=mMyPawn.default.mProtectItems;
		mMyPawn.mAttackRange=mMyPawn.default.mAttackRange;
		MMONpc = GGNpcMMOAbstract(mMyPawn);
		if(MMONpc != none)
		{
			MMONpc.mHealth=MMONpc.default.mHealth;
			MMONpc.mHealthMax=MMONpc.mHealth;
		}
		zombieNpc = GGNpcZombieGameModeAbstract(mMyPawn);
		if(zombieNpc != none)
		{
			zombieNpc.mCanDie=zombieNpc.default.mCanDie;
		}
	}

	EndBattle();
	StopFollowPawn();
	StopBeingFollowed();
	StopHealing();
	if(destActor != none)
	{
		destActor.ShutDown();
		destActor.Destroy();
	}
	isPossessing=false;
	super.UnPossess();
	mMyPawn=none;
}

simulated event Destroyed()
{
	if(isPossessing)
	{
		UnPossess();
	}

	super.Destroyed();
}

function BeGoatymonOf(GGGoat myTrainer)
{
	trainer=myTrainer;
	mMyPawn.mRunAnimationInfo.MovementSpeed=trainer.mSprintSpeed;
	mMyPawn.GroundSpeed = trainer.mWalkSpeed;
	mMyPawn.AirSpeed = trainer.mWalkSpeed;
	mMyPawn.WaterSpeed = trainer.mWalkSpeed;
	mMyPawn.LadderSpeed = trainer.mWalkSpeed;
	mMyPawn.JumpZ = trainer.JumpZ;
}

//Kill AI if goatymon is destroyed
function bool KillAIIfPawnDead()
{
	if(mMyPawn == none || mMyPawn.bPendingDelete || mMyPawn.Controller != self)
	{
		UnPossess();
		Destroy();
		return true;
	}

	return false;
}

static function bool MakeItGoatymon(GGPawn gpawn)
{
	local Controller oldController;
	local GGAIControllerGoatymon newController;

	if(gpawn == none || GGAIControllerGoatymon(gpawn.Controller) != none)
		return false;

	oldController=gpawn.Controller;
	if(oldController != none)
	{
		oldController.Unpossess();
		if(PlayerController(oldController) == none)
		{
			oldController.Destroy();
		}
	}

	newController = gpawn.Spawn(class'GGAIControllerGoatymon');
	newController.Possess(gpawn, false);

	return true;
}

event Tick( float deltaTime )
{
	local float speed, max_speed;
	local vector newVel;

	//Kill destroyed goatymons
	if(isPossessing)
	{
		if(KillAIIfPawnDead())
		{
			return;
		}
	}

	// Optimisation
	if( mMyPawn.IsInState( 'UnrenderedState' ) )
	{
		return;
	}

	super.Tick( deltaTime );

	// Fix dead attacked pawns
	if( mBattleEnemy != none )
	{
		if( mBattleEnemy.bPendingDelete )
		{
			mBattleEnemy = none;
		}
	}

	// Fix Pawn to attack
	if( mPawnToAttack == none  && mBattleEnemy != none)
	{
		mPawnToAttack=mBattleEnemy;
	}

	//Respawn dest actor if destroyed
	if(destActor == none || destActor.bPendingDelete)
	{
		destActor=none;
		SpawnDestActor();
	}

	//if(isInBattle)
	//{
	//	WorldInfo.Game.Broadcast(self, mMyPawn $ " state=" $ mCurrentState $ " attack=" $ mCurrentAttackType $ " isArrived=" $ isArrived $ " phys=" $ mMyPawn.Physics);
	//}
	CollectNPCAirInfo();

	if(mCurrentState == 'ChasePawn')//Disable ragdoll when chasing
	{
		mMyPawn.mIsRagdollAllowed=false;
	}
	else if(mLastState == 'ChasePawn')
	{
		mMyPawn.AllowRagdoll();
	}

	cancelNextRagdoll=false;
	if(!mMyPawn.mIsRagdoll && isDead)
	{
		mMyPawn.SetRagdoll(true);//do this one tick after death to prevent "frozen ragdoll" bug
		mMyPawn.DisableStandUp(class'GGNpc'.const.SOURCE_EDITOR);
	}
	if(!mMyPawn.mIsRagdoll)
	{
		//Fix NPC with no collisions
		if(mMyPawn.CollisionComponent == none)
		{
			mMyPawn.CollisionComponent = mMyPawn.mesh;
		}

		//Fix NPC rotation
		UnlockDesiredRotation();
		if(isInBattle)
		{
			if(mPawnToAttack != none)
			{
				Pawn.SetDesiredRotation( rotator( Normal2D(GetPawnPosition(mPawnToAttack)-GetPawnPosition(Pawn) ) ) );
			}
			mMyPawn.LockDesiredRotation( true );
		}
		if(!mIsAttacking || mCurrentAttackType == EAT_Uppercut)
		{
			//Force speed reduction when close to target
			speed=VSize(mMyPawn.Velocity);
			max_speed=VSize(mMyPawn.Location-destActor.Location)*2.f;
			if(speed > max_speed)
			{
				mMyPawn.Velocity.X*=max_speed/speed;
				mMyPawn.Velocity.Y*=max_speed/speed;
				mMyPawn.Velocity.Z*=max_speed/speed;
			}
		}
		if(mCurrentAttackType == EAT_Jump && mMyPawn.Physics == PHYS_Falling && mIsAttacking)//Make sure the jump attack is done correctly
		{
			//WorldInfo.Game.Broadcast(self, mMyPawn @ "Jumping" @ VSize2D(GetPawnPosition(mMyPawn)-GetPawnPosition(mPawnToAttack)) @ (mBattleDistance + mPawnToAttack.GetCollisionRadius()));
			if(VSize2D(GetPawnPosition(mMyPawn)-mEnemyBattlePos)
			> mBattleDistance + mPawnToAttack.GetCollisionRadius())//Before center, force go up
			{
				if(mLastVelocity.Z > 0.f && mMyPawn.Velocity.Z < mLastVelocity.Z * 0.99f)
				{
					mMyPawn.Velocity.Z=mLastVelocity.Z * 0.99f;
				}
			}
			else // After center, force go down
			{
				if(mMyPawn.Velocity.Z > 0.f)
				{
					mMyPawn.Velocity.Z=0.f;
				}
			}
		}
		if(mMyPawn.Physics == PHYS_Falling)//Maintain forward velocity when falling
		{
			//if(isInBattle && IsMyTurn()) WorldInfo.Game.Broadcast(self, mMyPawn $ " Vel=" $ mMyPawn.Velocity);
			if(VSize2D(mMyPawn.Velocity) < VSize2D(mLastVelocity))
			{
				newVel=Normal2D(mLastVelocity)*VSize2D(mLastVelocity);
				newVel.Z=mMyPawn.Velocity.Z;
				mMyPawn.Velocity=newVel;
			}
			mLastVelocity=mMyPawn.Velocity;
		}
		else
		{
			mLastVelocity=vect(0, 0, 0);
		}
		//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mMyPawn.mCurrentAnimationInfo.AnimationNames[0] $ ")");
		//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mCurrentState $ ")");
		UpdateFollowDest();
		// Fix animations
		if(IsZero(mMyPawn.Velocity))
		{
			if(isArrived && !mMyPawn.isCurrentAnimationInfoStruct(mMyPawn.mIdleAnimationInfo) && !mMyPawn.isCurrentAnimationInfoStruct(mMyPawn.mAttackAnimationInfo))
			{
				mMyPawn.SetAnimationInfoStruct( mMyPawn.mIdleAnimationInfo );
			}

			if(trainer == none)
			{
				if(!IsTimerActive( NameOf( StartRandomMovement ) ))
				{
					SetTimer(RandRange(1.0f, 10.0f), false, nameof( StartRandomMovement ) );
				}
			}
			else
			{
				if(mPawnToFollow == none && !IsCaptured())
				{
					StartFollowTrainer();
				}
			}
		}
		else
		{
			if( !mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mRunAnimationInfo ) && !mMyPawn.isCurrentAnimationInfoStruct(mMyPawn.mAttackAnimationInfo))
			{
				mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );
			}
		}
		if(mCurrentState == '') FindBestState();
		// if waited too long to before reaching some place or some target, abandon
		totalTime = totalTime + deltaTime;
		if(totalTime > 11.f)
		{
			totalTime=0.f;
			mMyPawn.AllowRagdoll();
			mMyPawn.SetRagdoll(true);
		}
	}
	else
	{
		//Fix NPC not standing up
		if(!isDead && !IsTimerActive( NameOf( StandUp ) ))
		{
			StartStandUpTimer();
		}
		//Make drowning goatymons follow trainer
		if(trainer != none && mMyPawn.mIsInWater)
		{
			totalTime = totalTime + deltaTime;
			if(totalTime > 1.f)
			{
				totalTime=0.f;
				DoRagdollJump();
			}
		}
	}

	mLastState=mCurrentState;
}

function CollectNPCAirInfo()
{
	local vector hitLocation, hitNormal;
	local vector traceStart, traceEnd, traceExtent;
	local float traceOffsetZ, distanceToGround;
	local Actor hitActor;

	traceExtent = mMyPawn.GetCollisionExtent() * 0.75f;
	traceExtent.Y = traceExtent.X;
	traceExtent.Z = traceExtent.X;

	traceOffsetZ = traceExtent.Z + 10.0f + mMyPawn.GetCollisionHeight();
	traceStart = GetPawnPosition(mMyPawn) + vect( 0.0f, 0.0f, 1.0f ) * traceOffsetZ;
	traceEnd = traceStart - vect( 0.0f, 0.0f, 1.0f ) * 100000.0f;

	hitActor = mMyPawn.Trace( hitLocation, hitNormal, traceEnd, traceStart,, traceExtent );
	if(hitActor == none)
	{
		hitLocation=traceEnd;
	}

	distanceToGround = FMax( VSize( traceStart - hitLocation ) - mMyPawn.GetCollisionHeight() - traceOffsetZ, 0.0f );

	mIsInAir = !mMyPawn.mIsInWater && ( mMyPawn.Physics == PHYS_Falling || ( mMyPawn.Physics == PHYS_RigidBody && distanceToGround > class'GGGoat'.default.mIsInAirThreshold ) );
}

function bool StandUpAllowed()
{
	if(mIsInAir || mMyPawn.mIsInWater) return false;
	mMyPawn.mForceRagdollByVolume=false;
	return mMyPawn.CanStandUp();
}


/**
 * Do ragdoll jump, e.g. for jumping out of water.
 */
function DoRagdollJump()
{
	local vector newVelocity;

	newVelocity = Normal2D(GetPawnPosition(trainer)-GetPawnPosition(mMyPawn));
	newVelocity.Z = 1.f;
	newVelocity = Normal(newVelocity) * trainer.mRagdollJumpZ;

	mMyPawn.mesh.SetRBLinearVelocity( newVelocity );
}

function vector GetPawnPosition(Pawn pwn)
{
	return pwn.Physics==PHYS_RigidBody?pwn.mesh.GetPosition():pwn.Location;
}

function StartFollowTrainer()
{
	local GGPawn target;
	local GGAIControllerGoatymon goatymonContr;
	local bool goatymonFound;

	if(isInBattle || mPawnToFollow != none)
		return;

	totalTime=-10.f;
	target=trainer;

	// Find goatymon following goat
	goatymonFound=false;
	foreach AllActors(class'GGAIControllerGoatymon', goatymonContr)
	{
		if(goatymonContr == self || goatymonContr.trainer != trainer || goatymonContr.isInBattle)
			continue;

		if(goatymonContr.mPawnToFollow == trainer)
		{
			goatymonFound=true;
			break;
		}
	}
	// Find last goatymon in the queue
	if(goatymonFound)
	{
		while(goatymonContr.mPawnFollowingMe != none)
		{
			goatymonContr=GGAIControllerGoatymon(goatymonContr.mPawnFollowingMe.Controller);
		}
		target=goatymonContr.mMyPawn;
	}

	StartFollowPawn(target);
	isArrived=false;//WorldInfo.Game.Broadcast(self, mMyPawn $ " (2) isArrived=false");
}

function StartFollowPawn(GGPawn pawnToFollow)
{
	local GGAIControllerGoatymon goatymonContr;

	if(pawnToFollow == none)
		return;

	mPawnToFollow=pawnToFollow;
	destActor.SetLocation(GetPawnPosition(mPawnToFollow));
	destActor.SetBase(mPawnToFollow);
	goatymonContr=GGAIControllerGoatymon(mPawnToFollow.Controller);
	if(goatymonContr != none)
	{
		goatymonContr.StartBeingFollowed(mMyPawn);
	}
}

function StartBeingFollowed(GGPawn pawnFollowingMe)
{
	mPawnFollowingMe=pawnFollowingMe;
}

function StopFollowPawn()
{
	local GGAIControllerGoatymon goatymonContr;

	if(mPawnToFollow != none)
	{
		goatymonContr=GGAIControllerGoatymon(mPawnToFollow.Controller);
		mPawnToFollow=none;
		if(goatymonContr != none && goatymonContr.mPawnFollowingMe == mMyPawn)
		{
			goatymonContr.StopBeingFollowed();
		}
	}
	if(destActor != none)
	{
		destActor.SetBase(none);
		destActor.SetLocation(GetPawnPosition(mMyPawn));
	}
}

function StopBeingFollowed()
{
	local GGAIControllerGoatymon goatymonContr;

	if(mPawnFollowingMe != none)
	{
		goatymonContr=GGAIControllerGoatymon(mPawnFollowingMe.Controller);
		mPawnFollowingMe=none;
		if(goatymonContr != none && goatymonContr.mPawnToFollow == mMyPawn)
		{
			goatymonContr.StopFollowPawn();
		}
	}
}

function UpdateFollowDest()
{
	local vector dest, voffset;
	local float offset;

	if(mMyPawn.mIsRagdoll)
		return;

	if(!isInBattle && mPawnToFollow != none)//Follow pawn
	{
		dest=GetPawnPosition(mPawnToFollow);
		offset=mMyPawn.GetCollisionRadius()*2.f + mPawnToFollow.GetCollisionRadius();
		voffset=Normal2D(GetPawnPosition(mMyPawn)-dest)*offset;//Make sure the MoveTo() function won't go too far
		dest+=voffset;
		dest.Z=GetPawnPosition(mMyPawn).Z;
	}
	else if(isInBattle)
	{
		if(mIsAttacking && (mCurrentState == 'ChasePawn' || mCurrentState == 'Attack'))// Chase enemy
		{
			dest=GetPawnPosition(mPawnToAttack);
			offset=mMyPawn.GetCollisionRadius() + mPawnToAttack.GetCollisionRadius() + mMyPawn.mAttackRange;
			voffset=Normal2D(GetPawnPosition(mMyPawn)-dest)*offset;//Make sure the MoveTo() function won't go too far
			dest+=voffset;
		}
		else// Go back to attack spot
		{
			dest=mBattlePos;
			offset=mMyPawn.GetCollisionRadius();
		}
	}
	else if(mCurrentState == 'WaitForNextEnemy')//Wait at your current location
	{
		dest=GetPawnPosition(mMyPawn) + Normal(vector(mMyPawn.Rotation));//Just to make sure the pawn keep looking in its current direction
		offset=mMyPawn.GetCollisionRadius();
	}
	else // follow random dest
	{
		dest=destActor.Location;
		offset=mMyPawn.GetCollisionRadius();
	}

	if(VSize2D(GetPawnPosition(mMyPawn)-dest) < offset)
	{
		if(!isArrived)
		{
			isArrived=true;//WorldInfo.Game.Broadcast(self, mMyPawn $ " (1) isArrived=true");
			mMyPawn.ZeroMovementVariables();//WorldInfo.Game.Broadcast(self, mMyPawn $ " ZeroMov by controller");
		}
		totalTime=0.f;
	}
	else
	{
		if(isArrived)
		{
			isArrived=false;//WorldInfo.Game.Broadcast(self, mMyPawn $ " (1) isArrived=false");
			totalTime=-10.f;
		}
	}

	//DrawDebugLine (mMyPawn.Location, dest, 0, 0, 0,);
	destActor.SetLocation(dest);
	if(!isArrived)
	{
		Pawn.SetDesiredRotation( rotator( Normal2D( destActor.Location - Pawn.Location ) ) );
	}
	mMyPawn.LockDesiredRotation( true );
}

function StartRandomMovement()
{
	local vector dest;
	local int OffsetX;
	local int OffsetY;
	local float range;

	if(isInBattle || mMyPawn.mIsRagdoll  || KillAIIfPawnDead())
		return;

	//WorldInfo.Game.Broadcast(self, mMyPawn $ " start random movement");
	totalTime=-10.f;

	range=mMyPawn.GetCollisionRadius()*20.f;
	OffsetX = RandRange(-range, range);
	OffsetY = RandRange(-range, range);

	dest.X = mMyPawn.Location.X + OffsetX;
	dest.Y = mMyPawn.Location.Y + OffsetY;
	dest.Z = mMyPawn.Location.Z;

	destActor.SetLocation(dest);
	isArrived=false;//WorldInfo.Game.Broadcast(self, mMyPawn $ " (3) isArrived=false");
}

function StartProtectingItem( ProtectInfo protectInformation, GGPawn threat )
{
	local GGAIControllerGoatymon enemyController;
	// Don't attack if pawn out of view or if already fighting or fighting is disabled
	if(mMyPawn.IsInState( 'UnrenderedState' ) || isInBattle || !mCanFight)
		return;
	//WorldInfo.Game.Broadcast(self, mMyPawn @ "StartProtectingItem against "$ threat);
	if(!StartBattle(threat))
		return;

	enemyController=GGAIControllerGoatymon(mBattleEnemy.Controller);
	if(enemyController.trainer == none && enemyController.mHealth == enemyController.mHealthMax)
	{
		WorldInfo.Game.Broadcast(self, "Wild" @ enemyController.mNPCName @ "appeared!");
	}

	StopAllScheduledMovement();
	StopFollowPawn();
	StopBeingFollowed();

	mCurrentlyProtecting = protectInformation;

	mPawnToAttack = threat;

	StartLookAt( threat, 5.0f );

	FindSpotForBattle();

	if(trainer == none)
	{
		StopHealing();
	}
	// Trainer component stop healing for every goatymon of that player
	OnBattleStarted();
	//WorldInfo.Game.Broadcast(self, mMyPawn @ "Battle started with" @ mPawnToAttack);
}

function GenerateThrowInfos()
{
	mThrowAttackSpinVelocity=vect(0, 0, 0);
	switch(Rand(3))
	{
		case 0:
			mThrowAttackSpinVelocity.X=mSpinSpeed*(Rand(3)-1);
			break;
		case 1:
			mThrowAttackSpinVelocity.Y=mSpinSpeed*(Rand(3)-1);
			break;
		case 2:
			mThrowAttackSpinVelocity.Z=mSpinSpeed*(Rand(3)-1);
			break;
	}

 	if(mThrowAttackModel != none)
 	{
 		mThrowAttackModel.SelfDestroy();
	}
	mThrowAttackModel=Spawn(class'ThrowAttack', mMyPawn,,,,, true);
	mThrowAttackModel.BeRandomModel();
}

function bool IsMyTurn()
{
	return mCurrentAttackType != EAT_None;
}

// Start a goatymon battle
function bool StartBattle(GGPawn threat)
{
	local GGAIControllerGoatymon goatymonContr;
	local float ratio;

	if(isInBattle)//Never start a new battle if another battle is happening
		return false;

	goatymonContr=GGAIControllerGoatymon(threat.Controller);
	if(goatymonContr != none)
	{
		if(!goatymonContr.isInBattle)
		{
			isInBattle=true;
			mBattleEnemy=threat;
			if(mLosePriority)//Used when you switch goatymon during battle
			{
				mLosePriority=false;
				mCurrentAttackType=EAT_None;
			}
			else
			{
				// The smallest goatymon have initiative, random if equal
				ratio=mSizeRatio - goatymonContr.mSizeRatio;
				if(ratio == 0.f)
				{
					if(Rand(2)==0)
					{
						SetRandomAttackType();//MyTurn
					}
				}
				else
				{
					if(ratio<0.f)
					{
						SetRandomAttackType();//MyTurn
					}
				}
			}
			goatymonContr.FightWith(mMyPawn);

			GotoState( 'PrepareNextAttack' );
		}
		else if(goatymonContr.mBattleEnemy == mMyPawn)
		{
			isInBattle=true;
			mBattleEnemy=threat;
			if(!goatymonContr.IsMyTurn())//if it's not the turn of the enemy, then it's my turn
			{
				SetRandomAttackType();
			}

			GotoState( 'PrepareNextAttack' );
		}
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn @ "StartBattle "$ isInBattle);
	return isInBattle;
}

function FightWith(GGPawn gpawn, optional bool losePriority)//Force battle to start wth the given pawn
{
	local ProtectInfo protInfos;
	mCanFight=true;
	mLosePriority=losePriority;
	NearProtectItem(none, protInfos);
	StartProtectingItem(protInfos, gpawn);
}

function FindSpotForBattle()
{
	local vector center, myPos, enemyPos;

	myPos=GetPawnPosition(mMyPawn);
	enemyPos=GetPawnPosition(mBattleEnemy);
	center=myPos + (enemyPos - myPos)*0.5f;
 	mBattlePos=center + Normal(myPos-center)*(mBattleDistance + mMyPawn.GetCollisionRadius());
 	mEnemyBattlePos=center + Normal(enemyPos-center)*(mBattleDistance + mBattleEnemy.GetCollisionRadius());
}

function EndBattle(optional bool isWinner)
{
	local GGAIControllerGoatymon goatymonController;

	if(!isInBattle)
		return;
	//WorldInfo.Game.Broadcast(self, mMyPawn @ "EndBattle" @ isWinner);
	isInBattle=false;
	mCurrentAttackType=EAT_None;
	mCanFight=false;

	if(mBattleEnemy != none)
	{
		goatymonController=GGAIControllerGoatymon(mBattleEnemy.Controller);
		if(goatymonController != none)
		{
			goatymonController.EndBattle(!isWinner);
		}
		mBattleEnemy=none;
	}

	EndAttack();
	if(trainer == none)
	{
		StartHealing();
	}
	// Trainer component enable healing if allowed
	OnBattleEnded(isWinner);
}

function bool IsReadyToAttack(optional bool noArrivedCheck)
{
	return isInBattle
		&& IsMyTurn()
		&& GGAIControllerGoatymon(mPawnToAttack.Controller) != none
		&& GGAIControllerGoatymon(mPawnToAttack.Controller).isInBattle
		&& (noArrivedCheck || AreFightersArrived());
}

function bool AreFightersArrived()
{
	return isInBattle && isArrived && GGAIControllerGoatymon(mPawnToAttack.Controller).isArrived;
}

function StartChasing()
{
	if(!mIsAttacking)//First time chasing during this turn
	{
		if(trainer != none)//Only say attacks for the controlled goatymons
		{
			class'TrainerGoatComponent'.static.SayText(GetALocalPlayerController(), mNPCName @ "use" @ GetAttackName());
		}
		else
		{
			WorldInfo.Game.Broadcast(self, mNPCName @ "use" @ GetAttackName());
		}
	}

	mIsAttacking=true;
	isArrived=false;
	totalTime=5.f;

	GotoState('ChasePawn');
}

function StartAttack( Pawn pawnToAttack )
{
	local bool missAttack;

	if(pawnToAttack == none
	|| pawnToAttack.bPendingDelete
	|| pawnToAttack.bHidden
	|| !isInBattle)
	{
		EndBattle();//break the attack loop if battle ended
		return;
	}

	if(!IsReadyToAttack(true))
	{
		SetTimer(0.1f, false, NameOf(DelayedStartAttack));
		return;
	}

	missAttack=ShouldAttackMiss();
	switch(mCurrentAttackType)
	{
		case EAT_Charge:
			if(!missAttack)
			{
				AttackPawn();
			}
			else
			{
				AttackMissed();
			}
			break;
		case EAT_Jump:
			AttackPawn();
			break;
		case EAT_Uppercut:
			StopLatentExecution();
			mMyPawn.ZeroMovementVariables();
			mMyPawn.SetPhysics(PHYS_Falling);
			mMyPawn.Velocity.Z=mMyPawn.mAttackMomentum;
			mLastVelocity=mMyPawn.Velocity;
			if(!missAttack)
			{
				AttackPawn();
			}
			else
			{
				AttackMissed();
			}
			break;
		case EAT_Throw:
			AttackPawn();
			break;
	}

	if(mCurrentAttackType != EAT_Throw || remainingThrows == 0)
	{
		EndTurn();
	}
}

function AttackMissed()
{
	WorldInfo.Game.Broadcast(self, "But it missed!");
	switch(mCurrentAttackType)
	{
		case EAT_Charge:
		case EAT_Jump:
			mMyPawn.SetRagdoll(true);
			break;
	}
}

function DelayedStartAttack()
{
	StartAttack(mBattleEnemy);
}

function EndTurn()
{
	local GGAIControllerGoatymon goatymonContr;
	//Throw attack battle text
	if(mCurrentAttackType == EAT_Throw)
	{
		if(throwHits == 0)
		{
			AttackMissed();
		}
		else
		{
			WorldInfo.Game.Broadcast(self, "Hit" @ throwHits @ "times!");
		}
	}

	mIsAttacking=false;
	isArrived=false;//Makes sure the enemy won't attack before we are back to the battle spot
	if(isInBattle)// Battle may end after an attack
	{
		goatymonContr=GGAIControllerGoatymon(mPawnToAttack.Controller);
		if(IsValidEnemy(mPawnToAttack) && PawnInRange(mPawnToAttack) && goatymonContr != none)
		{
			mCurrentAttackType=EAT_None;
			goatymonContr.SetRandomAttackType();
			GotoState( 'PrepareNextAttack' );
		}
		else
		{
			EndBattle();
		}
	}
	else//Should never happen
	{
		FindBestState();
	}
}

function bool ShouldAttackMiss()
{
	local GGAIControllerGoatymon goatymonContr;

	goatymonContr=GGAIControllerGoatymon(mPawnToAttack.Controller);
	if(goatymonContr == none)
		return true;

	switch(mCurrentAttackType)
	{
		case EAT_Charge:
			if(Rand(3)==0)
			{
				return (RandRange(0.f, goatymonContr.mSizeRatio) <= mSizeRatio);
			}
			return false;
		case EAT_Uppercut:
			if(Rand(5)==0)
			{
				return (RandRange(0.f, goatymonContr.mSizeRatio) <= mSizeRatio);
			}
			return false;
		case EAT_Jump:
		case EAT_Throw:
			return false;
	}

	return false;
}

/**
 * Attacks mPawnToAttack using mMyPawn.mAttackMomentum
 * called when our pawn needs to protect and item from a given pawn
 */
function AttackPawn()
{
	local vector dir;
	local rotator oldRot;
	local float	momentum;

	if(!IsAttackAllowed())
		return;

	StartLookAt( mPawnToAttack, 5.0f );

	dir = Normal( GetPawnPosition(mPawnToAttack) - GetPawnPosition(mMyPawn) );
	if(mCurrentAttackType == EAT_Uppercut)
	{
		dir = vect(0, 0, 1);
	}

	if(mPawnToAttack.DrivenVehicle == none)
	{
		if(mCurrentAttackType == EAT_Charge || mCurrentAttackType == EAT_Uppercut)
		{
			oldRot=mPawnToAttack.Rotation;
			GGPawn(mPawnToAttack).SetRagdoll(true);
			GGPawn(mPawnToAttack).mesh.SetRBAngularVelocity(vect(0, -3000, 0) >> oldRot, true);
		}

		if(mPawnToAttack.Physics != PHYS_RigidBody)
		{
			mPawnToAttack.SetPhysics( PHYS_Falling );
		}
		momentum=mAttackMomentum;
		dir.Z += 1.0f;//This double the force for the Uppercut case
		if(mPawnToAttack.Physics == PHYS_RigidBody)
		{
			mPawnToAttack.mesh.SetRBLinearVelocity(mPawnToAttack.mesh.GetRBLinearVelocity() + dir * momentum);
		}
		else
		{
			mPawnToAttack.Velocity+=dir * momentum;
		}
	}

	// Deal goatymon damages
	mPawnToAttack.TakeDamage(GetDamagesForCurrentAttack(), self, GetPawnPosition(mPawnToAttack), vect(0, 0, 0), class'DamageTypeGoatymon',, mMyPawn);

	mAttackIntervalInfo.LastTimeStamp = WorldInfo.TimeSeconds;
	totalTime=0.f;
}

function bool IsAttackAllowed()
{
	local float	animLength;

	switch(mCurrentAttackType)
	{
		case EAT_Charge:
			animLength=mMyPawn.SetAnimationInfoStruct( mMyPawn.mAttackAnimationInfo );
			ClearTimer( nameof( AttackAnimEnded ) );
			SetTimer(FMin(animLength, 2.f), false, nameof( AttackAnimEnded ) );
			return true;
		case EAT_Jump:
			if(mCollidedWithEnemy || VSize2D( GetPawnPosition(mMyPawn) - GetPawnPosition(mPawnToAttack) ) <= mMyPawn.mAttackRange)
			{
				return true;
			}
			else // Attack failed
			{
				AttackMissed();
			}
			break;
		case EAT_Uppercut:
		case EAT_Throw:
			return true;
			break;
	}

	return false;
}

function PerformJumpAttack()
{
	local vector dir;

	dir=Normal2D(mPawnToAttack.Location-mMyPawn.Location) + (vect(0, 0, 1)*RandRange(1.f, 5.f));

	mMyPawn.SetPhysics(PHYS_Falling);
	mMyPawn.Velocity+=Normal(dir) * 1000.f;
	mLastVelocity=mMyPawn.Velocity;
	isJumpDone=true;
}

function AttackAnimEnded()
{
	ClearTimer( nameof( AttackAnimEnded ) );
	mMyPawn.SetAnimationInfoStruct( mMyPawn.mIdleAnimationInfo );
}

function PerformThrowAttack()
{
	local vector spawnLoc;
	local rotator randomAngle;
	local float	animLength;

	animLength=mMyPawn.SetAnimationInfoStruct( mMyPawn.mAttackAnimationInfo );
	ClearTimer( nameof( AttackAnimEnded ) );
	SetTimer(FMin(animLength, 2.f), false, nameof( AttackAnimEnded ) );

	randomAngle.Yaw=RandRange(-1000.f, 1000.f);
	spawnLoc=mMyPawn.Location + Normal(vector(mMyPawn.Rotation))*(mMyPawn.GetCollisionRadius()*2.f + mAttackOffset);

	mThrownItem=Spawn(class'ThrowAttack', mMyPawn,, spawnLoc,, mThrowAttackModel, true);
	mThrownItem.SetupItemForThrow(self);
	mThrownItem.CollisionComponent.SetRBLinearVelocity(Normal(vector(rotator(Normal(GetPawnPosition(mBattleEnemy)-spawnLoc)) + mAimAdjust + randomAngle)) * mShootVelocity);
	//WorldInfo.Game.Broadcast(self, mMyPawn @ "Throw" @ mThrownItem @ remainingThrows);
}

function OnAttackHit(Actor hitAct)
{
	//WorldInfo.Game.Broadcast(self, mMyPawn @ "OnAttackHit" @ hitAct @ remainingThrows);
	mThrownItem=none;
	if(mCurrentAttackType != EAT_Throw)
		return;

	if(hitAct == mPawnToAttack)
	{
		throwHits++;
		ReachedEnemy();
	}
	else if(remainingThrows == 0)
	{
		EndTurn();
	}
}

function bool IsTargetEnemy(Actor act)
{
	return isInBattle && act == mPawnToAttack;
}

function EndAttack()
{
	if(isInBattle)
	{
		FindBestState();
	}
	else
	{
		super.EndAttack();
	}
}

function SetRandomAttackType()
{
	mCurrentAttackType=EAttackType(Rand(EAttackType.EnumCount-1)+1);
	switch(mCurrentAttackType)
	{
		case EAT_Charge:
			break;
		case EAT_Jump:
			isJumpDone=false;
			break;
		case EAT_Uppercut:
			break;
		case EAT_Throw:
			remainingThrows=Rand(4)+1;
			throwHits=0;
			GenerateThrowInfos();
			break;
		default:
			mCurrentAttackType=EAT_Charge;//Just make sure an attack have been selected
			break;
	}
}

function string GetAttackName()
{
	switch(mCurrentAttackType)
	{
		case EAT_Charge:
			return "Charge";
		case EAT_Jump:
			return "Stomp";
		case EAT_Uppercut:
			return "Uppercut";
		case EAT_Throw:
			return "Metronome";
	}

	return "";
}

function int GetDamagesForCurrentAttack()
{
	switch(mCurrentAttackType)
	{
		case EAT_Charge:
			return 20;
		case EAT_Jump:
			return 30;
		case EAT_Uppercut:
			return 40;
		case EAT_Throw:
			return 10;
	}

	return 0;
}

function bool ShouldAttackDamageEnemy( Actor target )
{
	//if(isInBattle) WorldInfo.Game.Broadcast(self, mMyPawn @ "ShouldAttackDamageEnemy" @ isInBattle @ target @ mIsAttacking @ mCurrentAttackType);
	return isInBattle && target == mPawnToAttack && mIsAttacking && mCurrentAttackType != EAT_Throw;
}

/**
 * We have to disable the notifications for changing states, since there are so many npcs which all have hundreds of calls.
 */
state MasterState
{
	function BeginState( name prevStateName )
	{
		mCurrentState = GetStateName();
	}
}

state WaitForNextEnemy extends MasterState
{
Begin:
	mMyPawn.ZeroMovementVariables();
	while(!KillAIIfPawnDead() && !isInBattle && class'TrainerGoatComponent'.default.mIsPvPEnabled)
	{
		Sleep(0.1f);//Just wait where you are until the next battle start
	}
}

state FollowTarget extends MasterState
{
Begin:
	mMyPawn.ZeroMovementVariables();
	while(!KillAIIfPawnDead() && !isInBattle && !class'TrainerGoatComponent'.default.mIsPvPEnabled)
	{
		if(!isArrived)
		{
			MoveToward (destActor);
		}
		else
		{
			Sleep(0.1f);// Ugly hack to prevent "runnaway loop" error
		}
	}
	mMyPawn.ZeroMovementVariables();
}

state PrepareNextAttack extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	while(!KillAIIfPawnDead() && isInBattle && !IsReadyToAttack())
	{
		if(!isArrived)
		{
			MoveToward (destActor);
		}
		else
		{
			Sleep(0.1f);// Ugly hack to prevent "runnaway loop" error
		}
	}

	if(IsReadyToAttack())
	{
		FinishRotation();
		StartChasing();
	}
	else
	{
		ReturnToOriginalPosition();
	}
}

state ChasePawn extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	switch(mCurrentAttackType)
	{
		case EAT_Charge:
		case EAT_Uppercut:
			break;//Nothing to do, we should chase pawn
		case EAT_Jump:
			if(mMyPawn.Physics == PHYS_Walking && !isJumpDone)
			{
				PerformJumpAttack();
			}
			if(mMyPawn.Physics == PHYS_Walking && isJumpDone)
			{
				ReachedEnemy();
			}
			else
			{
				Sleep(0.1f);
				GotoState('ChasePawn');
			}
			break;
		case EAT_Throw:
			if(mThrownItem == none)
			{
				totalTime=0.f;
				if(remainingThrows > 0)
				{
					remainingThrows--;
					PerformThrowAttack();
				}
			}
			Sleep(0.1f);
			GotoState('ChasePawn');
			break;
		default:
			FindBestState();
			break;
	}

	while(isInBattle && !KillAIIfPawnDead() && !isArrived)
	{
		MoveToward( mPawnToAttack );
	}

	if(!isInBattle)
	{
		ReturnToOriginalPosition();
	}
	else
	{
		FinishRotation();
		ReachedEnemy();
	}
}

state Attack extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	Focus = mPawnToAttack;

	StartAttack( mPawnToAttack );
	FinishRotation();
}

function ReachedEnemy(optional bool collidedEnemy)
{
	mCollidedWithEnemy=collidedEnemy;
	if(isInBattle)
	{
		GotoState( 'Attack' );
	}
	else
	{
		FindBestState();
	}
}

//All work done in EnemyNearProtectItem()
function bool GoatNearProtectItem( ProtectInfo protectInformation );
function CheckVisibilityOfGoats();
function CheckVisibilityOfEnemies();
event SeePlayer( Pawn Seen );
event SeeMonster( Pawn Seen );

/**
 * Helper function to determine if the last seen goat is near a given protect item
 * @param  protectInformation - The protectInfo to check against
 * @return true / false depending on if the goat is near or not
 */
function bool EnemyNearProtectItem( ProtectInfo protectInformation, out GGPawn enemyNear )
{
	local GGPawn gpawn;
	local float dist, minDist;

	if(mMyPawn.mIsRagdoll || !mCanFight)
		return false;

	//Find closest pawn to attack
	minDist=-1;
	foreach CollidingActors(class'GGPawn', gpawn, mMyPawn.SightRadius, mMyPawn.Location)
	{
		if(gpawn == mMyPawn || !IsValidEnemy(gpawn) || GeometryBetween(gpawn))
			continue;

		dist=VSize(GetPawnPosition(mMyPawn)-GetPawnPosition(gpawn));
		if(minDist == -1 || dist<minDist)
		{
			minDist=dist;
			enemyNear=gpawn;
		}
	}

	return (enemyNear != none);
}

/**
 * Helper function to determine if our pawn is close to a protect item, called when we arrive at a pathnode
 * @param currentlyAtNode - The pathNode our pawn just arrived at
 * @param out_ProctectInformation - The info about the protect item we are near if any
 * @return true / false depending on if the pawn is near or not
 */
function bool NearProtectItem( PathNode currentlyAtNode, out ProtectInfo out_ProctectInformation )
{
	out_ProctectInformation=mMyPawn.mProtectItems[0];
	return true;
}

function bool IsValidEnemy( Pawn newEnemy )
{
	local GGPawn gpawn;
	local GGAIControllerGoatymon goatymonController;

	//WorldInfo.Game.Broadcast(self, mMyPawn $ " canAttack(npc)=" $ npc);
	gpawn=GGPawn(newEnemy);
	if(gpawn != none)
	{
		goatymonController=GGAIControllerGoatymon(gpawn.Controller);
		//WorldInfo.Game.Broadcast(self, mMyPawn @ "IsValidEnemy" @ newEnemy @ goatymonController.trainer);
		if(mHealth > 0 && goatymonController != none && goatymonController.trainer != trainer && goatymonController.mHealth > 0)
		{
			if(trainer == none) return true;//Wild goatymons can fight against anyone else
			return (class'TrainerGoatComponent'.default.mIsPvPEnabled?(goatymonController.trainer!=none):(goatymonController.trainer==none));
		}
	}

	return false;
}

/**
 * Called when an actor takes damage
 */
function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum )
{
	if(damagedActor == mMyPawn)
	{
		if(dmgType == class'GGDamageTypeCollision' && !mMyPawn.mIsRagdoll && (!isInBattle || damageCauser != mPawnToAttack))
		{
			cancelNextRagdoll=true;
		}

		if(dmgType == class'DamageTypeGoatymon')
		{
			mHealth-=damage;
			if(TestIfDead())
			{
				EndBattle();
			}
		}
		if(ShouldAttackDamageEnemy(damageCauser))
		{
			ReachedEnemy(true);
		}
	}
	/*if(damagedActor == mPawnToAttack || damageCauser == mPawnToAttack)
	{
		WorldInfo.Game.Broadcast(self, mMyPawn @ "enemy damage" @ damagedActor @ damageCauser);
	}*/
}

function bool TestIfDead()
{
	if(mHealth <= 0)
	{
		mHealth=0;
		Die();
	}

	return isDead;
}

function Die()
{
	if(isDead)
		return;

	WorldInfo.Game.Broadcast(self, mNPCName @ "fainted!");
	isDead=true;
	mNameTagColor = MakeColor( 128, 128, 128, 255 );
}

function FullRegen()
{
	mNameTagColor = MakeColor( 255, 255, 255, 255 );
	mHealth=mHealthMax;
	isDead=false;
	mMyPawn.EnableStandUp(class'GGNpc'.const.SOURCE_EDITOR);
}

function bool CanReturnToOrginalPosition()
{
	return false;
}

/**
 * Go back to where the position we spawned on
 */
function ReturnToOriginalPosition()
{
	FindBestState();
}

function ResumeDefaultAction()
{
	super.ResumeDefaultAction();
	FindBestState();
}

function DelayedGoToProtect()
{
	UnlockDesiredRotation();
	FindBestState();
}

function DeterminWhatToDoAfterStandup()
{
	FindBestState();
}

function FindBestState()
{
	if(KillAIIfPawnDead()
	|| mMyPawn.mIsRagdoll)
		return;

	if(isInBattle)
	{
		if(!IsValidEnemy(mPawnToAttack) || !PawnInRange(mPawnToAttack))
		{
			EndBattle();
		}
		else if(IsMyTurn() && mIsAttacking && mCurrentState != 'ChasePawn' && mCurrentState != 'Attack')
		{
			StartChasing();
		}
		else if(mCurrentState == '')
		{
			GotoState('PrepareNextAttack');
		}
	}
	else if(class'TrainerGoatComponent'.default.mIsPvPEnabled && mCurrentState != 'WaitForNextEnemy')
	{
		GoToState('WaitForNextEnemy');
	}
	else if(mCurrentState != 'FollowTarget')
	{
		GoToState('FollowTarget');
	}
}

//--------------------------------------------------------------//
//			GGNotificationInterface								//
//--------------------------------------------------------------//

function OnCollision( Actor actor0, Actor actor1 )
{
	//Destroy breakable items on contact
	if(actor0 == mMyPawn)
	{
		DestroyNearbyApex();
		if(ShouldAttackDamageEnemy(actor1))
		{
			ReachedEnemy(true);
		}
	}
	else if(actor1 == mMyPawn)
	{
		if(ShouldAttackDamageEnemy(actor0))
		{
			ReachedEnemy(true);
		}
	}
}

function DestroyNearbyApex()
{
	local GGApexDestructibleActor tmpApex;
	local float r, h;
	//Only break stuff if following trainer or in battle, or else it's laggy
	if(!isInBattle && trainer == none)
		return;

	mMyPawn.GetBoundingCylinder(r, h);
	foreach mMyPawn.OverlappingActors(class'GGApexDestructibleActor', tmpApex, FMax(r, h) + 1.f, GetPawnPosition(mMyPawn))
	{
		if(!tmpApex.mIsFractured)
		{
			tmpApex.Fracture(0, none, tmpApex.Location, vect(0, 0, 0), class'GGDamageTypeCollision');
		}
	}
}

/**
 * Called when an actor begins to ragdoll
 */
function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	if(ragdolledActor == mMyPawn)
	{
		if(isRagdoll)
		{
			DestroyNearbyApex();
			if(cancelNextRagdoll)
			{
				cancelNextRagdoll=false;
				StandUp();
				//mMyPawn.SetPhysics( PHYS_Falling);
				//mMyPawn.Velocity+=pushVector;
			}
			else
			{
				if( IsTimerActive( NameOf( StopPointing ) ) )
				{
					StopPointing();
					ClearTimer( NameOf( StopPointing ) );
				}

				if( IsTimerActive( NameOf( StopLookAt ) ) )
				{
					StopLookAt();
					ClearTimer( NameOf( StopLookAt ) );
				}

				if(isInBattle)
				{
					ClearTimer( nameof( AttackPawn ) );
					ClearTimer( nameof( DelayedGoToProtect ) );
				}
				StopAllScheduledMovement();
				StartStandUpTimer();
				UnlockDesiredRotation();
			}
		}
		else
		{
			if(mPawnToAttack == none || mPawnToFollow != none)
			{
				totalTime=0.f;
			}
		}
	}

	if( GGPawn(ragdolledActor) != none)
	{
		if( ragdolledActor == mLookAtActor )
		{
			StopLookAt();
		}
	}
}

function HealTimer()
{
	if(GetALocalPlayerController().IsTimerActive(NameOf(HealTimer), self))
	{
		GetALocalPlayerController().ClearTimer(NameOf(HealTimer), self);
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn @ "HealTimer" @ healRate);
	if(mHealth <= 0)
	{
		StopHealing();
	}
	if(shouldHeal)
	{
		mAccumulatedHealth+=mHealRate;
		mHealth=mAccumulatedHealth;
		mHealRate+=(trainer==none?2.f:1.f)*mBaseHealRate;
		GetALocalPlayerController().SetTimer(0.1f, false, NameOf(HealTimer), self);
		//WorldInfo.Game.Broadcast(self, mMyPawn @ "Healing" @ mAccumulatedHealth @ mHealRate @ mHealth @ mHealthMax);
		if(mHealth >= mHealthMax)
		{
			mHealth=mHealthMax;
			StopHealing();
		}
	}
}

function StartHealing()
{
	mHealRate=mBaseHealRate;
	mAccumulatedHealth=mHealth;
	shouldHeal=true;
	HealTimer();
}

function StopHealing()
{
	//WorldInfo.Game.Broadcast(self, mMyPawn @ "StopHealing");
	if(GetALocalPlayerController().IsTimerActive(NameOf(HealTimer), self))
	{
		GetALocalPlayerController().ClearTimer(NameOf(HealTimer), self);
	}
	shouldHeal=false;
}

function bool IsCaptured()
{
	return (mGoatyballContainer!=none && !mGoatyballContainer.isEmpty);
}

function OnCaptured(TrainerGoatComponent trainerComp, GGGoat newTrainer, Goatyball ball)
{
	//WorldInfo.Game.Broadcast(self, mMyPawn @ "OnCaptured inBattle=" $ isInBattle);
	if(mGoatyballContainer == none && trainer == none)
	{
		WorldInfo.Game.Broadcast(self, "Gotcha!" @ mNPCName @ "was caught!");
	}
	OnBattleStarted=trainerComp.OnBattleStarted;
	OnBattleEnded=trainerComp.OnBattleEnded;
	BeGoatymonOf(newTrainer);
	mGoatyballContainer=ball;
	EndBattle();
	StopFollowPawn();
	StopBeingFollowed();
}

function OnReleased()
{
	WorldInfo.Game.Broadcast(self, mNPCName @ "is now free!");
	trainer=none;
	mGoatyballContainer=none;
	EndBattle();
	StopFollowPawn();
	StopBeingFollowed();
	if(GGNPCGoatymon(mMyPawn) != none)
	{
		GGNPCGoatymon(mMyPawn).SetName();
	}
	mNPCName=mMyPawn.GetActorName();
}

function SetPostRenderFor()
{
	local PlayerController PC;

	if(postRenderSet)
		return;

	postRenderSet=true;
	foreach WorldInfo.LocalPlayerControllers( class'PlayerController', PC )
	{
		if( GGHUD( PC.myHUD ) == none )
		{
			// OKAY! THIS IS REALLY LAZY! This assume all PC's is initialized at the same time
			SetTimer( 0.5f, false, NameOf( SetPostRenderFor ));
			postRenderSet=false;
			break;
		}
		GGHUD( PC.myHUD ).mPostRenderActorsToAdd.AddItem( self );
	}
}

simulated event PostRenderFor( PlayerController PC, Canvas c, vector cameraPosition, vector cameraDir )
{
	local vector nameTagLocation, locationToUse, offset;
	local bool isCloseEnough, isOnScreen, isVisible;
	local float cameraDistScale, cameraDist, cameraDistMax, cameraDistMin, cameraFadeDistMin, cameraFade;

	locationToUse = IsCaptured()?mGoatyballContainer.Location:GetPawnPosition(mMyPawn);

	if(!IsCaptured() && (mMyPawn.mesh.DetailMode > class'WorldInfo'.static.GetWorldInfo().GetDetailMode() || mMyPawn.bHidden))
		return;

	if(IsCaptured() && mGoatyballContainer.bHidden)
		return;

	cameraDist = VSize( cameraPosition - locationToUse );
	cameraDistMin = 500.0f;
	cameraDistMax = 4000.0f;
	cameraDistScale = GetScaleFromDistance( cameraDist, cameraDistMin, cameraDistMax );
	cameraFadeDistMin = 3000.0f;
	cameraFade = GetScaleFromDistance( cameraDist, cameraFadeDistMin, cameraDistMax ) * 255;

	isCloseEnough = cameraDist < cameraDistMax;
	isOnScreen = cameraDir dot Normal( locationToUse - cameraPosition ) > 0.0f;
	isVisible = false;

	if( isOnScreen && isCloseEnough )
	{
		// An extra check here as LastRenderTime is for all viewports (coop).
		isVisible = FastTrace( locationToUse, cameraPosition ) || IsCaptured();
	}

	c.Font = Font'UI_Fonts.InGameFont';
	c.PushDepthSortKey( int( cameraDist ) );

	if( isOnScreen && isCloseEnough && isVisible )
	{
		offset=IsCaptured()?mGoatyballContainer.mNameTagOffset:mNameTagOffset;
		nameTagLocation = c.Project( locationToUse + offset );

		RenderNameTag( c, nameTagLocation, cameraDistScale, cameraFade );
		RenderHpBar( c, nameTagLocation, cameraDistScale, cameraFade );
	}

	c.PopDepthSortKey();
}

/**
 * Renders an name tag for this npc.
 * @param c - Canvas to draw on.
 * @param screenLocation - Location on screen to draw the name (center/bottom of the text).
 * @param sceenScale - Scale of name, valid range is [0, 1] where 0 is smallest and 1 is biggest.
 * @param screenAlpha - How transparent the name tag should be, valid range is [0, 255] where 0 is invisible and 255 is visible.
 */
function RenderNameTag( Canvas c, vector screenLocation, float screenScale, float screenAlpha )
{
	local FontRenderInfo renderInfo;
	local float textScale;

	renderInfo.bClipText = true;
	textScale =  1.0f; //Lerp( .0f, 2.0f, screenScale );

	c.SetPos( screenLocation.X, screenLocation.Y );
	c.DrawColor = mNameTagColor;
	c.DrawColor.A = screenAlpha;
	c.DrawAlignedShadowText( mNPCName @ "[" $ mHealth $ "/" $ mHealthMax $ "]",, textScale, textScale, renderInfo,,, 0.5f, 1.0f );
}

/**
 * Renders an HP bar for this npc.
 * @param c - Canvas to draw on.
 * @param screenLocation - Location on screen to draw the HP bar (center/top of the bar).
 * @param sceenScale - Scale of the HP bar, valid range is [0, 1] where 0 is smallest and 1 is biggest.
 * @param screenAlpha - How transparent the name tag should be, valid range is [0, 255] where 0 is invisible and 255 is visible.
 */
function RenderHpBar( Canvas c, vector screenLocation, float screenScale, float screenAlpha )
{
	local int barHeight, barWidth;
	local vector adjustedScreenLocation;
	local float adjustedScreenScale, percent;

	adjustedScreenScale = Lerp( 1.0f, 2.0f, screenScale );

	barHeight = 4 * adjustedScreenScale;
	barWidth = 50 * adjustedScreenScale;

	adjustedScreenLocation.X = screenLocation.X - barWidth / 2;
	adjustedScreenLocation.Y = screenLocation.Y;

	// Background.
	c.DrawColor = mHpBarBackgroundColor;
	c.DrawColor.A = screenAlpha;
	c.SetPos( adjustedScreenLocation.X, adjustedScreenLocation.Y );
	c.DrawRect( barWidth, barHeight );

	// Bar.
	percent = GetHP();
	c.DrawColor = percent > 0.5f	? LerpColor( mHpBarColor50, mHpBarColor100, ( percent - 0.5f ) * 2.0f )
									: LerpColor( mHpBarColor0, mHpBarColor50, percent * 2.0f );
	c.DrawColor.A = screenAlpha;
	c.SetPos( adjustedScreenLocation.X + 1, adjustedScreenLocation.Y + 1 );
	c.DrawRect( FMax( percent > 0.0f ? 1.0f : 0.0f, ( barWidth - 2 ) * percent ), barHeight - 2 );
}

/**
 * Get the hp of this NPC in percent.
 *@return - Returns a value in the range [0, 1], 1 is max health and 0 is dead!
 */
function float GetHP()
{
	return float( mHealth ) / float( mHealthMax );
}

function float GetScaleFromDistance( float cameraDist, float cameraDistMin, float cameraDistMax )
{
	return FClamp( 1.0f - ( ( FMax( cameraDist, cameraDistMin ) - cameraDistMin ) / ( cameraDistMax - cameraDistMin ) ), 0.0f, 1.0f );
}

event PawnFalling();//Prevent going to "Waitforlanding" state
function bool GoatCarryingDangerItem();
function bool PawnUsesScriptedRoute();
function StartInteractingWith( InteractionInfo intertactionInfo );

function OnTrickMade( GGTrickBase trickMade );
function OnKismetActivated( SequenceAction activatedKismet );

function bool CanPawnInteract();
function OnManual( Actor manualPerformer, bool isDoingManual, bool wasSuccessful );
function OnWallRun( Actor runner, bool isWallRunning );
function OnWallJump( Actor jumper );

//--------------------------------------------------------------//
//			End GGNotificationInterface							//
//--------------------------------------------------------------//

function ApplaudGoat();
function PointAtGoat();
function StopPointing();
function bool WantToPanicOverTrick( GGTrickBase trickMade );
function bool WantToApplaudTrick( GGTrickBase trickMade  );
function bool WantToPanicOverKismetTrick( GGSeqAct_GiveScore trickRelatedKismet );
function bool WantToApplaudKismetTrick( GGSeqAct_GiveScore trickRelatedKismet );
function bool AfraidOfGoatWithDangerItem();
function bool NearInteractItem( PathNode currentlyAtNode, out InteractionInfo out_InteractionInfo );
function bool ShouldApplaud();
event GoatPickedUpDangerItem( GGGoat goat );
function bool PanicOnRagdoll();
function bool CanPanic();
function Panic();
function Dance(optional bool forever);
function PawnDied(Pawn inPawn);

DefaultProperties
{
	mNPCName="Missing No"
	mHealth=100
	mBaseHealRate=0.01f

	mAttackMomentum=600.f

	mNameTagOffset=(X=0.0f,Y=0.0f,Z=0.0f)
	mNameTagColor=(R=255,G=255,B=255,A=255)

	mHpBarBackgroundColor=(R=0,G=0,B=0,A=255)
	mHpBarColor0=(R=255,G=0,B=0,A=255)
	mHpBarColor50=(R=255,G=255,B=0,A=255)
	mHpBarColor100=(R=0,G=255,B=0,A=255)

	mDestinationOffset=200.f
	mBattleDistance=300.f

	mAttackOffset=20.f
	mShootVelocity=1000.f
	mSpinSpeed=3000.f
	mAimAdjust=(Roll=0,Pitch=2000,Yaw=0)

	bIsPlayer=true

	mAttackIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mCheckProtItemsThreatIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mVisibilityCheckIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)

	bPostRenderIfNotVisible=true
}