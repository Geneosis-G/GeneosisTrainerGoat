class ThrowAttack extends GGKactor;

var StaticMeshComponent mItemMesh;
var float collRadius;
var float desiredSize;
var vector mSpinVelocity;
var bool isInit;
var bool isModel;

delegate OnAttackHit(Actor hitAct);
delegate bool IsTargetEnemy(Actor target);

simulated event PostBeginPlay()
{
	super.PostBeginPlay();
	//WorldInfo.Game.Broadcast(self, "LaserwrenchSpawned=" $ self);
	//StaticMeshComponent.BodyInstance.CustomGravityFactor=0.f;
	//WorldInfo.Game.Broadcast(self, self @ "Spawned" @ CollisionComponent);
	SetTimer(5.f, false, NameOf(SelfDestroy));
	isInit=true;
}

function int GetScore()
{
	return 0;
}

function string GetActorName()
{
	return "Attack";
}

function BeRandomModel()
{
	local StaticMeshComponent comp;
	local float r, h, maxRH;
	local GGKActor hitKActor;
	local int actorsCount, randKact, i;

	//Count valid actors
	actorsCount=0;
	foreach AllActors( class'GGKActor', hitKActor )
	{
		actorsCount++;
	}
	//Get random actor
	randKact=Rand(actorsCount);
	i=0;
	foreach AllActors( class'GGKActor', hitKActor )
	{
		if(i == randKact)
		{
			comp=hitKActor.StaticMeshComponent;
			SetStaticMesh(comp.StaticMesh, comp.Translation, comp.Rotation, comp.Scale3D);
			break;
		}
		i++;
	}

	SetPhysics(PHYS_None);
	SetHidden(true);

	GetBoundingCylinder(r, h);
	maxRH=FMax(r, h);
	SetDrawScale(desiredSize/maxRH);

	CollisionComponent.SetActorCollision(false, false);
	CollisionComponent.SetBlockRigidBody(false);
	CollisionComponent.SetNotifyRigidBodyCollision(false);
	//WorldInfo.Game.Broadcast(self, self @ "isThrowModel" @ CollisionComponent);
	isModel=true;
}

function SetupItemForThrow(GGAIControllerGoatymon attackInstigator)
{
	isModel=false;
	CollisionComponent.SetActorCollision(true, true);
	CollisionComponent.SetBlockRigidBody(true);
	CollisionComponent.SetNotifyRigidBodyCollision(true);
	OnAttackHit=attackInstigator.OnAttackHit;
	IsTargetEnemy=attackInstigator.IsTargetEnemy;
	mSpinVelocity=attackInstigator.mThrowAttackSpinVelocity;
	SetPhysics(PHYS_RigidBody);
	CollisionComponent.WakeRigidBody();
	SetHidden(false);
}

function bool ShouldIgnoreActor(Actor act)
{
	//WorldInfo.Game.Broadcast(self, "shouldIgnoreActor=" $ act);
	return (!isInit
	|| isModel
	|| act == none
	|| Volume(act) != none
	|| GGApexDestructibleActor(act) != none
	|| act == self
	|| act == Owner);
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
	local Actor currTarget;
	//WorldInfo.Game.Broadcast(self, self @ "HitActor" @ target);
	if(!ShouldIgnoreActor(target))
    {
		if(!IsTargetEnemy(target))//Extra check to see if the target was near the hit impact
		{
			foreach OverlappingActors(class'Actor', currTarget, collRadius, Location)
		    {
				if(IsTargetEnemy(currTarget))
				{
					target=currTarget;
					break;
				}
		    }
		}
		SelfDestroy(target);
	}
}

simulated event Tick( float delta )
{
	super.Tick( delta );

	FindExtraTargets();
	StaticMeshComponent.SetRBAngularVelocity(mSpinVelocity);
}

function SelfDestroy(optional Actor causer)
{
	//WorldInfo.Game.Broadcast(self, self @ "SelfDestroy" @ causer);
	if(IsTimerActive(NameOf(SelfDestroy)))
	{
		ClearTimer(NameOf(SelfDestroy));
	}
	if(!isModel)
	{
		OnAttackHit(causer);
	}
	ShutDown();
}

DefaultProperties
{
	bNoDelete=false
	bStatic=false
	mBlockCamera=false

	collRadius=20.0f
	desiredSize=20.f

	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Food.mesh.WaterMelon_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Translation=(X=0, Y=0, Z=0)
		scale=0.05f
	End Object
	mItemMesh=StaticMeshComponent0

	bCollideActors=true
	bBlockActors=true
	bCollideWorld=true;
}