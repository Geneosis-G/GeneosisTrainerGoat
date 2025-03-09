class GGNPCGoatymon extends GGNpc;

var string mNPCName;
var int mID;
var int mMaxHealth;
var bool mHideImmediately;

struct FullMeshInfo
{
	var string mName;
	var SkeletalMesh mSkeletalMesh;
	var PhysicsAsset mPhysicsAsset;
	var AnimSet mAnimSet;
	var AnimTree mAnimTree;
	var array<MaterialInterface> mMaterials;
	var vector mTranslation;
	var vector2D mCollisionCylinder;
	var float mScale;
	var array<name> mAnimationNames;
};
var array< FullMeshInfo > mFullMeshes;

simulated event PostBeginPlay()
{
	super.PostBeginPlay();

	mKnockedOverSounds.Length = 0;

	if(GoatymonWorld(Owner) != none)
	{
		SetRandomMesh();
		//WorldInfo.Game.Broadcast(self, self $ " auto spawn Controller");
		if( Controller == none )
		{
			SpawnDefaultController();
		}
	}
}

function SetRandomMesh()
{
	SetCustomMesh(-1);
	SetName();
	SetMaxHealth();
}

function SetCustomMesh(int newMeshIndex)
{
	local int i;

	if( newMeshIndex < 0 || newMeshIndex >= mFullMeshes.Length )
	{
		newMeshIndex=rand( mFullMeshes.Length );
	}

	mID=newMeshIndex;
	// Set custom mesh and anims
	mesh.SetSkeletalMesh( mFullMeshes[ newMeshIndex ].mSkeletalMesh );
	mesh.SetPhysicsAsset( mFullMeshes[ newMeshIndex ].mPhysicsAsset, true);
	mesh.AnimSets[ 0 ] = mFullMeshes[ newMeshIndex ].mAnimSet;
	mesh.SetAnimTreeTemplate( mFullMeshes[ newMeshIndex ].mAnimTree );
	// Set custom material
	for(i=0 ; i<mFullMeshes[ newMeshIndex ].mMaterials.Length ; i++)
	{
		mesh.SetMaterial( i, mFullMeshes[ newMeshIndex ].mMaterials[i] );
	}
	// Set scale
	if(mFullMeshes[ newMeshIndex ].mScale != 0.f)
	{
		mesh.SetScale(mFullMeshes[ newMeshIndex ].mScale);
	}
	else
	{
		mesh.SetScale(1.f);
	}
	// Set default anims
	mDefaultAnimationInfo.AnimationNames[0]='Idle';
	if(!IsAnimInSet('Idle'))
	{
		mDefaultAnimationInfo.AnimationNames[0]='Idle_01';
		if(!IsAnimInSet('Idle_01'))
		{
			mDefaultAnimationInfo.AnimationNames[0]='Idle_02';
		}
	}
	mRunAnimationInfo.AnimationNames[0]='Sprint';
	if(!IsAnimInSet('Sprint'))
	{
		mRunAnimationInfo.AnimationNames[0]='Sprint_01';
		if(!IsAnimInSet('Sprint_01'))
		{
			mRunAnimationInfo.AnimationNames[0]='Sprint_02';
			if(!IsAnimInSet('Sprint_02'))
			{
				mRunAnimationInfo.AnimationNames[0]='Run';
				if(!IsAnimInSet('Run'))
				{
					mRunAnimationInfo.AnimationNames[0]='Walk';
				}
			}
		}
	}
	mAttackAnimationInfo.AnimationNames[0]='Ram';
	if(!IsAnimInSet('Ram'))
	{
		mAttackAnimationInfo.AnimationNames[0]='Attack';
		if(!IsAnimInSet('Attack'))
		{
			mAttackAnimationInfo.AnimationNames[0]='Kick';
		}
	}
	// Set custom anims
	if(mFullMeshes[ newMeshIndex ].mAnimationNames.Length > 0 && mFullMeshes[ newMeshIndex ].mAnimationNames[0] != '')
	{
		mDefaultAnimationInfo.AnimationNames[0]=mFullMeshes[ newMeshIndex ].mAnimationNames[0];
	}
	if(mFullMeshes[ newMeshIndex ].mAnimationNames.Length > 1 && mFullMeshes[ newMeshIndex ].mAnimationNames[1] != '')
	{
		mRunAnimationInfo.AnimationNames[0]=mFullMeshes[ newMeshIndex ].mAnimationNames[1];
	}
	if(mFullMeshes[ newMeshIndex ].mAnimationNames.Length > 2 && mFullMeshes[ newMeshIndex ].mAnimationNames[2] != '')
	{
		mAttackAnimationInfo.AnimationNames[0]=mFullMeshes[ newMeshIndex ].mAnimationNames[2];
	}
	// Copy iddentical animations
	mDanceAnimationInfo.AnimationNames[0]=mDefaultAnimationInfo.AnimationNames[0];
	mPanicAtWallAnimationInfo.AnimationNames[0]=mDefaultAnimationInfo.AnimationNames[0];
	mAngryAnimationInfo.AnimationNames[0]=mDefaultAnimationInfo.AnimationNames[0];
	mIdleAnimationInfo.AnimationNames[0]=mDefaultAnimationInfo.AnimationNames[0];
	mIdleSittingAnimationInfo.AnimationNames[0]=mDefaultAnimationInfo.AnimationNames[0];

	mPanicAnimationInfo.AnimationNames[0]=mRunAnimationInfo.AnimationNames[0];
	// Set custom translation and collision
	mesh.SetTranslation(mFullMeshes[ newMeshIndex ].mTranslation);
	SetLocation(Location + vect(0, 0, 1) * mFullMeshes[ newMeshIndex ].mCollisionCylinder.Y);
	SetCollisionSize(mFullMeshes[ newMeshIndex ].mCollisionCylinder.X, mFullMeshes[ newMeshIndex ].mCollisionCylinder.Y);
	//WorldInfo.Game.Broadcast(self, self $ " created with ID " $ mID);
}

function SetName(optional string newName)
{
	mNPCName=newName==""?mFullMeshes[mID].mName:newName;
}

function SetMaxHealth(optional int newMax)
{
	mMaxHealth=class'GGNPCGoatymon'.static.GetRandomRatio(self);
	if(newMax>0 && newMax<2.f*mMaxHealth)
	{
		mMaxHealth=newMax;
	}
}

static function float GetRandomRatio(GGPawn gpawn)
{
	local float r, h;

	gpawn.GetBoundingCylinder(r, h);
	return (r + h) * RandRange(0.80f, 1.20f);
}

function bool IsAnimInSet(name animName)
{
	local AnimSequence animSeq;

	foreach mesh.AnimSets[0].Sequences(animSeq)
	{
		if(animSeq.SequenceName == animName)
		{
			return true;
		}
	}

	return false;
}

function string GetActorName()
{
	return mNPCName==""?super.GetActorName():mNPCName;
}

/** Overloaded to stop functionality */
function KnockedByGoat();
//Fix warnings for old goat / horse / donkey
function FootDownLeft();
function FootDownRight();
//Debug functions
/*
function float SetAnimationInfoStruct( NPCAnimationInfo animationInfoStruct, optional bool noSound )
{
	`log(mNPCName @ "SetAnimationInfoStruct");
	return super.SetAnimationInfoStruct(animationInfoStruct, noSound);
}*/
/*
function GGPhysicalMaterialProperty GetPhysProp()
{
	local GGPhysicalMaterialProperty res;
	WorldInfo.Game.Broadcast(self, self $ " GetPhysProp Before material(0)=" $ mesh.GetMaterial( 0 ));
	res = super.GetPhysProp();//Here Accessed none 'mesh' error ????
	WorldInfo.Game.Broadcast(self, self $ " GetPhysProp After material(0)=" $ mesh.GetMaterial( 0 ));
	return res;
}*/
/*function float SetAnimationInfoStruct( NPCAnimationInfo animationInfoStruct, optional bool noSound )
{
	//WorldInfo.Game.Broadcast(self, self $ " SetAnimationInfoStruct " $ animationInfoStruct.AnimationNames[0] @ IsAnimInSet(animationInfoStruct.AnimationNames[0]));
	if(!IsAnimInSet(animationInfoStruct.AnimationNames[0]))//for some reasons this happen sometimes
		return 0.f;

	return super.SetAnimationInfoStruct(animationInfoStruct, noSound);
}*/
/*simulated function ZeroMovementVariables()
{
	WorldInfo.Game.Broadcast(self, self $ " ZeroMovementVariables");
	super.ZeroMovementVariables();
}*/

DefaultProperties
{
	ControllerClass=class'GGAIControllerGoatymon'

	mID=-1
	mMaxHealth=-1

	mFullMeshes.Add((mName="Goat",mSkeletalMesh=SkeletalMesh'goat.mesh.goat',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'goat.Materials.Goat_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Rippedgoat",mSkeletalMesh=SkeletalMesh'goat.mesh.GoatRipped',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'goat.Materials.Goat_Ripped_Mat_01'),mTranslation=(Z=20.f),mCollisionCylinder=(X=25.f,Y=30.f),mScale=1.2f))
	mFullMeshes.Add((mName="Devilgoat",mSkeletalMesh=SkeletalMesh'goat.mesh.goat',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'goat.Materials.Goat_Mat_02'),mTranslation=(Z=8.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Angelgoat",mSkeletalMesh=SkeletalMesh'goat.mesh.goat',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'goat.Materials.Goat_Mat_03'),mTranslation=(Z=8.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Browngoat",mSkeletalMesh=SkeletalMesh'goat.mesh.goat',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'goat.Materials.Goat_Mat_04'),mTranslation=(Z=8.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Whitegoat",mSkeletalMesh=SkeletalMesh'goat.mesh.goat',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'goat.Materials.Goat_Mat_05'),mTranslation=(Z=8.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Redgoat",mSkeletalMesh=SkeletalMesh'goat.mesh.goat',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'goat.Materials.Goat_Mat_06'),mTranslation=(Z=8.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Blackgoat",mSkeletalMesh=SkeletalMesh'goat.mesh.goat',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'goat.Materials.Goat_Mat_07'),mTranslation=(Z=8.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Unclegoat",mSkeletalMesh=SkeletalMesh'goat.mesh.goat',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'goat.Materials.Goat_Mat_08'),mTranslation=(Z=8.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Tyrannosaur",mSkeletalMesh=SkeletalMesh'MMO_OldGoat.mesh.OldGoat_01',mPhysicsAsset=PhysicsAsset'MMO_OldGoat.mesh.OldGoat_Physics_01',mAnimSet=AnimSet'MMO_OldGoat.Anim.OldGoat_Anim_01',mAnimTree=AnimTree'MMO_OldGoat.Anim.OldGoat_AnimTree',mMaterials=(Material'MMO_OldGoat.Materials.OldGoat_Mat_01'),mTranslation=(Z=20.f),mCollisionCylinder=(X=200.f,Y=250.f)))
	mFullMeshes.Add((mName="Cow",mSkeletalMesh=SkeletalMesh'MMO_Cow.mesh.Cow_01',mPhysicsAsset=PhysicsAsset'MMO_Cow.mesh.Cow_Physics_01',mAnimSet=AnimSet'MMO_Cow.Anim.Cow_Anim_01',mAnimTree=AnimTree'Characters.Anim.Characters_Animtree_01',mMaterials=(Material'MMO_Cow.Materials.Cow_Mat_01'),mTranslation=(Z=-140.f),mCollisionCylinder=(X=32.f,Y=140.f)))
	mFullMeshes.Add((mName="Dodo",mSkeletalMesh=SkeletalMesh'MMO_Dodo.mesh.Dodo_01',mPhysicsAsset=PhysicsAsset'MMO_Dodo.mesh.Dodo_Physics_01',mAnimSet=AnimSet'MMO_Dodo.Anim.Dodo_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'MMO_Dodo.Materials.Dodo_Mat_01'),mTranslation=(Z=-32.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Sheep",mSkeletalMesh=SkeletalMesh'MMO_Sheep.mesh.Sheep_01',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'MMO_Sheep.Materials.Sheep_Dif_Mat_01'),mTranslation=(Z=0.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Spider",mSkeletalMesh=SkeletalMesh'MMO_Spider.mesh.Spider_01',mPhysicsAsset=PhysicsAsset'MMO_Spider.mesh.Spider_Physics_01',mAnimSet=AnimSet'MMO_Spider.Anim.Spider_Anim_01',mAnimTree=AnimTree'MMO_Aborre.Anim.Aborre_AnimTree',mMaterials=(Material'MMO_Spider.Materials.Spider_Mat'),mTranslation=(Z=-50.f),mCollisionCylinder=(X=100.f,Y=50.f)))
	mFullMeshes.Add((mName="Bear",mSkeletalMesh=SkeletalMesh'MMO_Bear.mesh.Bear_01',mPhysicsAsset=PhysicsAsset'Characters.mesh.CasualMan_Physics_01',mAnimSet=AnimSet'MMO_Bear.Anim.Bear_Anim_01',mAnimTree=AnimTree'MMO_Bear.Anim.Bear_AnimTree',mMaterials=(Material'MMO_Bear.Materials.Bear_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=28.f,Y=30.f)))
	mFullMeshes.Add((mName="Demon",mSkeletalMesh=SkeletalMesh'MMO_Demon.mesh.Demon_01',mPhysicsAsset=PhysicsAsset'MMO_Demon.mesh.Demon_Physics_01',mAnimSet=AnimSet'MMO_Demon.Anim.Demon_Anim_01',mAnimTree=AnimTree'MMO_Aborre.Anim.Aborre_AnimTree',mMaterials=(Material'MMO_Demon.Materials.Demon_Mat'),mTranslation=(Z=-75.f),mCollisionCylinder=(X=28.f,Y=75.f),mAnimationNames=(,Idle,Spawn)))
	mFullMeshes.Add((mName="Dobomination",mSkeletalMesh=SkeletalMesh'MMO_Dodo.mesh.DodoAbomination_01',mPhysicsAsset=PhysicsAsset'MMO_Dodo.mesh.DodoAbomination_Physics_01',mAnimSet=AnimSet'MMO_Dodo.Anim.DodoAbomination_Anim_01',mAnimTree=AnimTree'MMO_Aborre.Anim.Aborre_AnimTree',mMaterials=(Material'MMO_Dodo.Materials.DodoAbomination_Mat_01'),mTranslation=(Z=-50.f),mCollisionCylinder=(X=100.f,Y=50.f)))
	mFullMeshes.Add((mName="Aborre",mSkeletalMesh=SkeletalMesh'MMO_Aborre.mesh.Aborre_01',mPhysicsAsset=PhysicsAsset'MMO_Aborre.mesh.Aborre_Physics_01',mAnimSet=AnimSet'MMO_Aborre.Anim.Aborre_Anim_01',mAnimTree=AnimTree'MMO_Aborre.Anim.Aborre_AnimTree',mMaterials=(Material'MMO_Aborre.Materials.Aborre_Mat_01'),mTranslation=(Z=0.f),mCollisionCylinder=(X=28.f,Y=75.f)))
	mFullMeshes.Add((mName="Horse",mSkeletalMesh=SkeletalMesh'MMO_JoustingGoat.mesh.Horse_01',mPhysicsAsset=PhysicsAsset'MMO_JoustingGoat.mesh.JoustingGoat_Physics_01',mAnimSet=AnimSet'MMO_JoustingGoat.Anim.JoustingGoat_Anim_01',mAnimTree=AnimTree'MMO_JoustingGoat.Anim.JoustingGoat_Animtree',mMaterials=(Material'MMO_JoustingGoat.Materials.Horse_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=40.f,Y=98.f)))
	mFullMeshes.Add((mName="Lavahorse",mSkeletalMesh=SkeletalMesh'MMO_JoustingGoat.mesh.Horse_01',mPhysicsAsset=PhysicsAsset'MMO_JoustingGoat.mesh.JoustingGoat_Physics_01',mAnimSet=AnimSet'MMO_JoustingGoat.Anim.JoustingGoat_Anim_01',mAnimTree=AnimTree'MMO_JoustingGoat.Anim.JoustingGoat_Animtree',mMaterials=(Material'MMO_JoustingGoat.Materials.Horse_Mat_02'),mTranslation=(Z=8.f),mCollisionCylinder=(X=40.f,Y=98.f)))
	mFullMeshes.Add((mName="Cubegoat",mSkeletalMesh=SkeletalMesh'GoatCraft.mesh.BuilderGoat_01',mPhysicsAsset=PhysicsAsset'goat.mesh.goat_Physics',mAnimSet=AnimSet'goat.Anim.Goat_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'GoatCraft.Materials.BuilderGoat_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=25.f,Y=30.f)))
	mFullMeshes.Add((mName="Penguin",mSkeletalMesh=SkeletalMesh'ClassyGoat.mesh.ClassyGoat_01',mPhysicsAsset=PhysicsAsset'ClassyGoat.mesh.ClassyGoat_Physics_01',mAnimSet=AnimSet'ClassyGoat.Anim.ClassyGoat_Anim_01',mAnimTree=AnimTree'ClassyGoat.Anim.ClassyGoat_AnimTree',mMaterials=(Material'ClassyGoat.Materials.ClassyGoat_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=20.f,Y=35.f)))
	mFullMeshes.Add((mName="Ostrich",mSkeletalMesh=SkeletalMesh'FeatherGoat.mesh.FeatherGoat_01',mPhysicsAsset=PhysicsAsset'FeatherGoat.mesh.FeatherGoat_Physics_01',mAnimSet=AnimSet'FeatherGoat.Anim.FeatherGoat_Anim_01',mAnimTree=AnimTree'FeatherGoat.Anim.FeatherGoat_AnimTree',mMaterials=(Material'FeatherGoat.Materials.FeatherGoat_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=50.f,Y=85.f)))
	mFullMeshes.Add((mName="Alien",mSkeletalMesh=SkeletalMesh'CH_HeadBobber.mesh.HeadBobber_01',mPhysicsAsset=PhysicsAsset'CH_HeadBobber.mesh.HeadBobber_Physics_01',mAnimSet=AnimSet'CH_HeadBobber.Anim.HeadBobber_Anim_01',mAnimTree=AnimTree'CH_HeadBobber.AnimTree.Creature_AnimTree',mMaterials=(Material'CH_HeadBobber.Materials.SpaceGoat_Mat'),mTranslation=(Z=8.f),mCollisionCylinder=(X=60.f,Y=130.f)))
	mFullMeshes.Add((mName="Giraffe",mSkeletalMesh=SkeletalMesh'TallGoat.mesh.TallGoat_01',mPhysicsAsset=PhysicsAsset'TallGoat.mesh.TallGoat_Physics_01',mAnimSet=AnimSet'TallGoat.Anim.TallGoat_Anim_01',mAnimTree=AnimTree'TallGoat.Anim.TallGoat_AnimTree',mMaterials=(Material'TallGoat.Materials.TallGoat_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=60.f,Y=130.f)))
	mFullMeshes.Add((mName="Elephant",mSkeletalMesh=SkeletalMesh'Goat_Zombie.Meshes.FiremanGoat_Rigged_01',mPhysicsAsset=PhysicsAsset'Goat_Zombie.Meshes.FiremanGoat_Rigged_01_Physics',mAnimSet=AnimSet'Goat_Zombie.Anim.FiremanGoat_Anim_01',mAnimTree=AnimTree'Goat_Zombie.Anim.FiremanGoat_AnimTree',mMaterials=(Material'Goat_Zombie.Materials.FiremanGoat_Eyes_01',Material'Goat_Zombie.Materials.FiremanGoat_Tusks_01',Material'Goat_Zombie.Materials.FiremanGoat_Eyes_01',Material'Goat_Zombie.Materials.FiremanGoat_Body_M',Material'Goat_Zombie.Materials.FiremanGoat_Body_M'),mTranslation=(Z=8.f),mCollisionCylinder=(X=80.f,Y=145.f)))
	mFullMeshes.Add((mName="Llama",mSkeletalMesh=SkeletalMesh'Llama.Meshes.Llama_Rigged',mPhysicsAsset=PhysicsAsset'Llama.Meshes.Llama__PhysicsAsset',mAnimSet=AnimSet'Llama.Anim.Llama_Anim_01',mAnimTree=AnimTree'Llama.Anim.Llama_AnimTree',mMaterials=(Material'Llama.Materials.Llama_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=50.f,Y=60.f)))
	mFullMeshes.Add((mName="Donkey",mSkeletalMesh=SkeletalMesh'MMO_Donkey.mesh.Donkey_01',mPhysicsAsset=PhysicsAsset'MMO_Donkey.mesh.Donkey_Physics_01',mAnimSet=AnimSet'MMO_Donkey.Anim.Donkey_Anim_01',mAnimTree=AnimTree'goat.Anim.Goat_AnimTree',mMaterials=(Material'MMO_Donkey.Materials.Donkey_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=25.f,Y=30.f),mAnimationNames=(,,Baa)))
	mFullMeshes.Add((mName="Pig",mSkeletalMesh=SkeletalMesh'MMO_Pig.mesh.Pig_01',mPhysicsAsset=PhysicsAsset'MMO_Pig.mesh.Pig_Physics_01',mAnimSet=AnimSet'MMO_Pig.Anim.Pig_Anim_01',mAnimTree=AnimTree'Characters.Anim.Characters_Animtree_01',mMaterials=(Material'MMO_Pig.Materials.Pig_Mat_01'),mTranslation=(Z=-38.f),mCollisionCylinder=(X=25.f,Y=30.f),mScale=3.f,mAnimationNames=(Graze,Walk,Scratch)))
	mFullMeshes.Add((mName="Cat",mSkeletalMesh=SkeletalMesh'Heist_CatCircle.mesh.Cat_01',mPhysicsAsset=PhysicsAsset'Heist_CatCircle.mesh.Cat_Physics_01',mAnimSet=AnimSet'Heist_CatCircle.Anim.Cat_Anim_01',mAnimTree=AnimTree'Characters.Anim.Characters_Animtree_01',mMaterials=(MaterialInstanceConstant'Heist_CatCircle.Materials.Cat_Mat_01'),mTranslation=(Z=-55.f),mCollisionCylinder=(X=25.f,Y=30.f),mScale=1.3f,mAnimationNames=(,,ToranRa_01)))
	mFullMeshes.Add((mName="Flamingo",mSkeletalMesh=SkeletalMesh'Heist_Flamingoat.mesh.Flamingoat_01',mPhysicsAsset=PhysicsAsset'Heist_Flamingoat.mesh.Flamingoat_Physics_01',mAnimSet=AnimSet'Heist_Flamingoat.Anim.Flamingoat_Anim_01',mAnimTree=AnimTree'Heist_Flamingoat.Anim.Flamingoat_AnimTree',mMaterials=(Material'Heist_Flamingoat.Materials.Flamingoat_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=33.f,Y=80.f)))
	mFullMeshes.Add((mName="Camel",mSkeletalMesh=SkeletalMesh'Heist_Camelgoat.mesh.Camelgoat_01',mPhysicsAsset=PhysicsAsset'Heist_Camelgoat.mesh.Camelgoat_Physics_01',mAnimSet=AnimSet'Heist_Camelgoat.Anim.Camelgoat_Anim_01',mAnimTree=AnimTree'Heist_Camelgoat.Anim.Camelgoat_AnimTree',mMaterials=(Material'Heist_Camelgoat.Materials.Camel_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=38.f,Y=100.f)))
	mFullMeshes.Add((mName="Dolphin",mSkeletalMesh=SkeletalMesh'Heist_Dolphwheelgoat.mesh.Dolphwheelgoat_01',mPhysicsAsset=PhysicsAsset'Heist_Dolphwheelgoat.mesh.Dolphwheelgoat_01_Physics',mAnimSet=AnimSet'Heist_Dolphwheelgoat.Anim.Dolphwheelgoat_Anim_01',mAnimTree=AnimTree'Heist_Dolphwheelgoat.Anim.Dolphwheelgoat_AnimTree',mMaterials=(Material'Heist_Dolphwheelgoat.Materials.Dolphwheelgoat_Mat_02',Material'Heist_Dolphwheelgoat.Materials.Dolphwheelgoat_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=33.f,Y=40.f)))
	mFullMeshes.Add((mName="Ibex",mSkeletalMesh=SkeletalMesh'Heist_Handsomegoat.mesh.Handsomegoat_01',mPhysicsAsset=PhysicsAsset'Heist_Handsomegoat.mesh.Handsomegoat_Physics_01',mAnimSet=AnimSet'Heist_Handsomegoat.Anim.Handsomegoat_Anim_01',mAnimTree=AnimTree'Heist_Handsomegoat.Anim.Handsomegoat_AnimTree',mMaterials=(Material'Heist_Handsomegoat.Materials.Handsomegoat_Mat_01'),mTranslation=(Z=8.f),mCollisionCylinder=(X=30.f,Y=57.f)))
	mFullMeshes.Add((mName="Xenogoat",mSkeletalMesh=SkeletalMesh'Space_SanctumCharacters.CH_Runner_Mommy.runner_mommy',mPhysicsAsset=PhysicsAsset'Space_SanctumCharacters.Anim.Runner_Physics',mAnimSet=AnimSet'Space_SanctumCharacters.Anim.Runner_Mommy_Anim_01',mAnimTree=AnimTree'Characters.Anim.Characters_Animtree_01',mMaterials=(Material'Space_SanctumCharacters.CH_Runner_Mommy.Runner_Mommy_Mat_01'),mTranslation=(Z=-20.f),mCollisionCylinder=(X=45.f,Y=60.f)))

	mDefaultAnimationInfo=(AnimationNames=(Idle),AnimationRate=1.0f,MovementSpeed=0.0f,LoopAnimation=true)
	mDanceAnimationInfo=(AnimationNames=(Idle),AnimationRate=1.0f,MovementSpeed=0.0f,LoopAnimation=true)
	mPanicAtWallAnimationInfo=(AnimationNames=(Idle),AnimationRate=1.0f,MovementSpeed=0.0f,LoopAnimation=true)
	mPanicAnimationInfo=(AnimationNames=(Sprint),AnimationRate=1.0f,MovementSpeed=700.0f,LoopAnimation=true,SoundToPlay=())
	mAttackAnimationInfo=(AnimationNames=(Ram),AnimationRate=1.0f,MovementSpeed=0.0f,LoopAnimation=false)
	mAngryAnimationInfo=(AnimationNames=(Idle),AnimationRate=1.0f,MovementSpeed=0.0f,LoopAnimation=true,SoundToPlay=())
	mIdleAnimationInfo=(AnimationNames=(Idle),AnimationRate=1.0f,MovementSpeed=0.0f,LoopAnimation=true)
	mRunAnimationInfo=(AnimationNames=(Sprint),AnimationRate=1.0f,MovementSpeed=700.0f,LoopAnimation=true)
	mIdleSittingAnimationInfo=(AnimationNames=(Idle),AnimationRate=1.0f,MovementSpeed=0.0f,LoopAnimation=true)
	mAutoSetReactionSounds=false
}