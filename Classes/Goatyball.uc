class Goatyball extends GGKActor;

var StaticMeshComponent ballTopMesh;
var StaticMeshComponent ballBottomMesh;
var StaticMeshComponent circleMesh;
var StaticMeshComponent lockMesh;
var StaticMeshComponent captureMesh;
var StaticMeshComponent buttonMesh;

var GGGoat mGoat;
var float collRadius;
var GGPawn mMyPawn;
var Actor mMyActor;
var bool isEmpty;
var bool mForceCapture;

var bool isThrown;
var bool isGoingAway;
var float goatyballSpeed;
var float mShootVelocity;
var rotator mAimAdjust;
var vector mAngularVel;
var float mSpinSpeed;

var float ballDistance;
var vector desiredPosition;

var bool postRenderSet;
var vector mNameTagOffset;
var color mNameTagColor;

delegate OnGoatymonReleased(Goatyball ball, Actor releasedActor);
delegate OnGoatymonCatched(Goatyball ball, Actor catchedActor);

simulated event PostBeginPlay()
{
	super.PostBeginPlay();
	//WorldInfo.Game.Broadcast(self, "LaserwrenchSpawned=" $ self);
	//StaticMeshComponent.BodyInstance.CustomGravityFactor=0.f;
	CollisionComponent.WakeRigidBody();

	mGoat=GGGoat(Owner);
	ballTopMesh.SetLightEnvironment( mGoat.mesh.LightEnvironment );
	ballBottomMesh.SetLightEnvironment( mGoat.mesh.LightEnvironment );
	circleMesh.SetLightEnvironment( mGoat.mesh.LightEnvironment );
	lockMesh.SetLightEnvironment( mGoat.mesh.LightEnvironment );
	captureMesh.SetLightEnvironment( mGoat.mesh.LightEnvironment );
	buttonMesh.SetLightEnvironment( mGoat.mesh.LightEnvironment );

	SetBallCollision(false);

	if( !WorldInfo.bStartup )
	{
		SetPostRenderFor();
	}
	else
	{
		SetTimer( 1.0f, false, NameOf( SetPostRenderFor ));
	}
}

function SetBallCollision(bool collide)
{
	ballTopMesh.SetActorCollision(collide, collide);
	ballTopMesh.SetBlockRigidBody(collide);
	ballTopMesh.SetNotifyRigidBodyCollision(collide);
	ballBottomMesh.SetActorCollision(collide, collide);
	ballBottomMesh.SetBlockRigidBody(collide);
	ballBottomMesh.SetNotifyRigidBodyCollision(collide);
	circleMesh.SetActorCollision(collide, collide);
	circleMesh.SetBlockRigidBody(collide);
	circleMesh.SetNotifyRigidBodyCollision(collide);
	lockMesh.SetActorCollision(collide, collide);
	lockMesh.SetBlockRigidBody(collide);
	lockMesh.SetNotifyRigidBodyCollision(collide);
	captureMesh.SetActorCollision(collide, collide);
	captureMesh.SetBlockRigidBody(collide);
	captureMesh.SetNotifyRigidBodyCollision(collide);
	buttonMesh.SetActorCollision(collide, collide);
	buttonMesh.SetBlockRigidBody(collide);
	buttonMesh.SetNotifyRigidBodyCollision(collide);
}

function int GetScore()
{
	return 0;
}

function string GetActorName()
{
	return "Goatyball";
}

function OnGrabbed( Actor grabbedByActor )
{
	local GGGoat grabber;

	super.OnGrabbed( grabbedByActor );

	grabber=GGGoat(grabbedByActor);
	if(grabber != none)
	{
		grabber.DropGrabbedItem();
	}
}

function bool ShouldIgnoreActor(Actor act)
{
	//WorldInfo.Game.Broadcast(self, "shouldIgnoreActor=" $ act);
	return (
	act == none
	|| Volume(act) != none
	|| GGApexDestructibleActor(act) != none
	|| act == self
	|| act == Owner
	|| act.Owner == Owner);
}

simulated event TakeDamage( int damage, Controller eventInstigator, vector hitLocation, vector momentum, class< DamageType > damageType, optional TraceHitInfo hitInfo, optional Actor damageCauser )
{
	super.TakeDamage(damage, eventInstigator, hitLocation, momentum, damageType, hitInfo, damageCauser);
	//WorldInfo.Game.Broadcast(self, "TakeDamage=" $ damageCauser);
	HitActor(damageCauser);
}

event Bump( Actor Other, PrimitiveComponent OtherComp, Vector HitNormal )
{
    super.Bump(Other, OtherComp, HitNormal);
	//WorldInfo.Game.Broadcast(self, "Bump=" $ other);
	HitActor(other);
}

event RigidBodyCollision(PrimitiveComponent HitComponent, PrimitiveComponent OtherComponent, const out CollisionImpactData RigidCollisionData, int ContactIndex)
{
	super.RigidBodyCollision(HitComponent, OtherComponent, RigidCollisionData, ContactIndex);
	//WorldInfo.Game.Broadcast(self, "RBCollision=" $ OtherComponent.Owner);
	HitActor(OtherComponent!=none?OtherComponent.Owner:none);
}

function FindExtraTargets()
{
	local Actor currTarget;

	//traceStart=Location + (wrenchMesh.Translation >> Rotation);
	//DrawDebugLine (traceStart, traceStart + (Normal(vector(Rotation)) * wrenchRadius), 0, 0, 0,);

	//WorldInfo.Game.Broadcast(self, "FindExtraTargets() wrenchRadius=" $ wrenchRadius);

	foreach CollidingActors( class'Actor', currTarget, collRadius, Location)
    {
		//WorldInfo.Game.Broadcast(self, "Found Extra Target :" $ currTarget);
		HitActor(currTarget);
    }
}

function HitActor(optional Actor target)
{
	if(ShouldIgnoreActor(target) || !(isThrown && isGoingAway))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "Hit Actor :" $ target);
	SetBallCollision(false);

	if(isEmpty)
	{
		TryToCapture(target);
	}
	else
	{
		ReleaseGoatymon();
	}

	ComeBack();
}

function ComeBack()
{
	ClearTimer(NameOf(ComeBack));
	SetBallCollision(false);
	isThrown=true;
	isGoingAway=false;
	mForceCapture=false;
}

simulated event Tick( float delta )
{
	local float dist;
	local vector currPosition;

	super.Tick( delta );

	if(!isEmpty && (mMyActor == none || mMyActor.bPendingDelete))
	{
		mMyPawn=none;
		mMyActor=none;
		isEmpty=true;
	}

	if(isThrown && isGoingAway)
	{
		if(collRadius < 100.f)// Radius grow with throw distance
		{
			collRadius=collRadius+(100.f*delta);
			collRadius=FMin(collRadius, 100.f);
		}
		// Find missed items
		FindExtraTargets();
		StaticMeshComponent.SetRBAngularVelocity(mAngularVel);
	}
	else if(!IsZero(desiredPosition))
	{
    	currPosition=StaticMeshComponent.GetPosition();
		dist=VSize(currPosition-desiredPosition);
		if(isThrown && dist <= 5.f)
		{
			isThrown=false;
		}

		if(isThrown)
    	{
			StaticMeshComponent.SetRBLinearVelocity(Normal(desiredPosition-currPosition) * FMin(goatyballSpeed, (dist*2.f + 60.f)) + mGoat.Velocity);
    	}
    	else
    	{
    		StaticMeshComponent.SetRBPosition(desiredPosition);
    		StaticMeshComponent.SetRBLinearVelocity(vect(0, 0, 0));
    	}

    	StaticMeshComponent.SetRBRotation(rotator(currPosition-mGoat.Location));
    	StaticMeshComponent.SetRBAngularVelocity(vect(0, 0, 0));
	}
}

function bool ThrowGoatyball()
{
	local vector camLocation;
	local rotator camRotation, throwRot;

	if(isThrown)
	{
		if(isGoingAway)// if already thrown, call it back
		{
			ComeBack();
		}
		return false;
	}

	SetBallCollision(true);

	mAngularVel.X=mSpinSpeed*(Rand(5)-2);
	mAngularVel.Y=mSpinSpeed*(Rand(5)-2);
	mAngularVel.Z=mSpinSpeed*(Rand(5)-2);

	collRadius=0.f;

	isThrown=true;
	isGoingAway=true;

	StaticMeshComponent.SetRBLinearVelocity(mGoat.Velocity);
	if(GGPlayerControllerGame( mGoat.Controller ) != none)
	{
		GGPlayerControllerGame( mGoat.Controller ).PlayerCamera.GetCameraViewPoint( camLocation, camRotation );
		throwRot=mGoat.Rotation;
		throwRot.Pitch=camRotation.Pitch + mAimAdjust.Pitch;
	}
	else
	{
		throwRot=mGoat.Rotation + mAimAdjust;
	}
	ApplyImpulse( vector( throwRot ), mShootVelocity, Location );

	SetTimer(5.f, false, NameOf(ComeBack));

	return true;
}

function TryToCapture(Actor target, optional bool wasLoaded)
{
	local GGNpc npc;
	local GGInventoryActorInterface invAct;
	local GGAIControllerGoatymon newGoatymonContr;

	npc=GGNpc(target);
	invAct=GGInventoryActorInterface(target);
	if(invAct == none)
		return;
	//WorldInfo.Game.Broadcast(self, self @ "TryToCapture" @ target);
	if(npc != none && !wasLoaded)
	{
		newGoatymonContr=GGAIControllerGoatymon(npc.Controller);
		if(newGoatymonContr != none)
		{
			if(newGoatymonContr.trainer != none && newGoatymonContr.trainer != mGoat)
			{
				WorldInfo.Game.Broadcast(self, "You can't capture Goatymons of other players!");
				return;
			}

			if(newGoatymonContr.trainer == none)
			{
				if(newGoatymonContr.mHealth == 0)
				{
					WorldInfo.Game.Broadcast(self, "You can't capture a dead Goatymon.");
					return;
				}

				if((1.f*newGoatymonContr.mHealth/newGoatymonContr.mHealthMax) > 1.f/5.f && !mForceCapture)
				{
					WorldInfo.Game.Broadcast(self, "You can only capture this" @ npc.GetActorName() @ " when it have less than" @ int(newGoatymonContr.mHealthMax/5.f) @ "health.");
					return;
				}
			}
		}
	}

	OnGoatymonCatched(self, target);
	mMyPawn=GGPawn(target);
	mMyActor=target;
	isEmpty=false;
}

function ReleaseGoatymon()
{
	OnGoatymonReleased(self, mMyActor);
	isEmpty=true;
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
	local bool isCloseEnough, isOnScreen;
	local float cameraDistScale, cameraDist, cameraDistMax, cameraDistMin, cameraFadeDistMin, cameraFade;

	locationToUse = Location;

	if(isEmpty
	|| bHidden
	|| (mMyPawn != none && GGAIControllerGoatymon(mMyPawn.Controller) != none)
	|| mMyActor.CollisionComponent.DetailMode > class'WorldInfo'.static.GetWorldInfo().GetDetailMode())
	{
		return;
	}

	cameraDist = VSize( cameraPosition - locationToUse );
	cameraDistMin = 500.0f;
	cameraDistMax = 4000.0f;
	cameraDistScale = GetScaleFromDistance( cameraDist, cameraDistMin, cameraDistMax );
	cameraFadeDistMin = 3000.0f;
	cameraFade = GetScaleFromDistance( cameraDist, cameraFadeDistMin, cameraDistMax ) * 255;

	isCloseEnough = cameraDist < cameraDistMax;
	isOnScreen = cameraDir dot Normal( locationToUse - cameraPosition ) > 0.0f;

	c.Font = Font'UI_Fonts.InGameFont';
	c.PushDepthSortKey( int( cameraDist ) );

	if( isOnScreen && isCloseEnough )
	{
		offset=mNameTagOffset;
		nameTagLocation = c.Project( locationToUse + offset );

		RenderNameTag( c, nameTagLocation, cameraDistScale, cameraFade );
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
	c.DrawAlignedShadowText( GGScoreActorInterface(mMyActor).GetActorName(),, textScale, textScale, renderInfo,,, 0.5f, 1.0f );
}

function float GetScaleFromDistance( float cameraDist, float cameraDistMin, float cameraDistMax )
{
	return FClamp( 1.0f - ( ( FMax( cameraDist, cameraDistMin ) - cameraDistMin ) / ( cameraDistMax - cameraDistMin ) ), 0.0f, 1.0f );
}

DefaultProperties
{
	bNoDelete=false
	bStatic=false
	mBlockCamera=false

	isEmpty=true

	collRadius=100.0f
	goatyballSpeed=2000.f
	ballDistance=30.f

	mShootVelocity=20.0f
	mAimAdjust=(Roll=0,Pitch=8192,Yaw=0)
	mSpinSpeed=3000.f

	mNameTagOffset=(X=0.0f,Y=0.0f,Z=10.0f)
	mNameTagColor=(R=255,G=255,B=255,A=255)

	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Zombie_Craftable_Items.Meshes.Crystal_Ball'
		Materials(0)=Material'Kitchen_01.Materials.White_Mat_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Scale3D=(X=0.5f, Y=0.5f, Z=0.5f)
	End Object
	ballBottomMesh=StaticMeshComponent0

	Begin Object class=StaticMeshComponent name=StaticMeshComponent1
		StaticMesh=StaticMesh'Zombie_Craftable_Items.Meshes.Crystal_Ball'
		Materials(0)=Material'Props_01.Materials.Bicycle_Red'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
        Scale3D=(X=0.5f, Y=0.5f, Z=0.5f)
		Translation=(X=0, Y=0, Z=1)
	End Object
	ballTopMesh=StaticMeshComponent1
	Components.Add(StaticMeshComponent1)

	Begin Object class=StaticMeshComponent Name=StaticMeshComponent2
		StaticMesh=StaticMesh'Living_Room_01.Mesh.House_Ashtray'
		Materials(0)=Material'Props_01.Materials.Bicycle_Black_Mat_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Scale3D=(X=0.72f, Y=0.72f, Z=0.30f)
		Translation=(X=0.f, Y=0.f, Z=0.f)
	End Object
	circleMesh=StaticMeshComponent2
	Components.Add(StaticMeshComponent2);

	Begin Object class=StaticMeshComponent Name=StaticMeshComponent3
		StaticMesh=StaticMesh'Living_Room_01.Mesh.House_Ashtray'
		Materials(0)=Material'Props_01.Materials.Bicycle_Black_Mat_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Scale3D=(X=0.22f, Y=0.22f, Z=0.22f)
		Translation=(X=4.5f, Y=0.f, Z=0.5f)
		Rotation=(Pitch=16384,Yaw=0,Roll=0)
	End Object
	lockMesh=StaticMeshComponent3
	Components.Add(StaticMeshComponent3);

	Begin Object class=StaticMeshComponent Name=StaticMeshComponent4
		StaticMesh=StaticMesh'Living_Room_01.Mesh.House_Ashtray'
		Materials(0)=Material'Kitchen_01.Materials.White_Mat_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Scale3D=(X=0.14f, Y=0.14f, Z=0.18f)
		Translation=(X=4.6f, Y=0.f, Z=0.5f)
		Rotation=(Pitch=16384,Yaw=0,Roll=0)
	End Object
	captureMesh=StaticMeshComponent4
	Components.Add(StaticMeshComponent4);

	Begin Object class=StaticMeshComponent Name=StaticMeshComponent5
		StaticMesh=StaticMesh'Living_Room_01.Mesh.House_Ashtray'
		Materials(0)=Material'Kitchen_01.Materials.White_Mat_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Scale3D=(X=0.10, Y=0.10f, Z=0.14f)
		Translation=(X=4.7f, Y=0.f, Z=0.5f)
		Rotation=(Pitch=16384,Yaw=0,Roll=0)
	End Object
	buttonMesh=StaticMeshComponent5
	Components.Add(StaticMeshComponent5);

	bCollideActors=true
	bBlockActors=true
	bCollideWorld=true;
}