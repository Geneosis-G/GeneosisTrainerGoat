class TrainerGoat extends GGMutator
	config(Geneosis);

var array<TrainerGoatComponent> mComponents;
var Goatyball mLastBallUsed;

struct GoatymonInfos
{
	var int playerSlot;
	var int ID;
	var string customName;
	var int maxHealth;
};
var config array<GoatymonInfos> mCapturedGoatymonInfos;

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local TrainerGoatComponent trainerComp;

	super.ModifyPlayer( other );

	goat = GGGoat( other );
	if( goat != none )
	{
		trainerComp=TrainerGoatComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'TrainerGoatComponent', goat.mCachedSlotNr));
		if(trainerComp != none && mComponents.Find(trainerComp) == INDEX_NONE)
		{
			mComponents.AddItem(trainerComp);
			if(mComponents.Length == 1)
			{
				InitTrainerInteraction();
			}
		}
	}
}

function InitTrainerInteraction()
{
	local TrainerInteraction ti;

	ti = new class'TrainerInteraction';
	ti.InitTrainerInteraction(self);
	GetALocalPlayerController().Interactions.AddItem(ti);
}

simulated event Tick( float delta )
{
	local TrainerGoatComponent comp;

	super.Tick( delta );

	foreach mComponents(comp)
	{
		comp.Tick(delta);
	}
}

function LoadCapturedGoatymonsForPlayer(out array<GGNPCGoatymon> capturedGoatymons, int playerSlot)
{
	local int i;
	local GGNPCGoatymon newGoatymon;
	//WorldInfo.Game.Broadcast(self, "LoadCapturedGoatymonsForPlayer " $ playerSlot $ " count=" $ mCapturedGoatymonInfos.Length);
	for(i=0 ; i<mCapturedGoatymonInfos.Length ; i++)
	{
		//WorldInfo.Game.Broadcast(self, "Loading" @ mCapturedGoatymonInfos[i].playerSlot @ mCapturedGoatymonInfos[i].ID @ mCapturedGoatymonInfos[i].customName @ mCapturedGoatymonInfos[i].maxHealth);
		if(mCapturedGoatymonInfos[i].playerSlot != playerSlot)
			continue;

		newGoatymon=Spawn( class'GGNPCGoatymon',,, vect(0, 0, 1000) + vect(0, 0, 100) * i + vect(100, 0, 0) * playerSlot,,, true);
		//WorldInfo.Game.Broadcast(self, "Loading spawned" @ newGoatymon);
		if(newGoatymon != none && !newGoatymon.bPendingDelete)
		{
			LoadGoatymon(mCapturedGoatymonInfos[i], newGoatymon);
			newGoatymon.SetPhysics( PHYS_Falling );
			capturedGoatymons.AddItem(newGoatymon);
		}
	}
}

function SaveCapturedGoatymonsForPlayer(array<GGNPCGoatymon> capturedGoatymons, int playerSlot)
{
	local int i;
	local GoatymonInfos newGoatymonInfos;
	//WorldInfo.Game.Broadcast(self, "SaveCapturedGoatymonsForPlayer " $ playerSlot);
	for(i=mCapturedGoatymonInfos.Length-1 ; i>=0 ; i--)
	{
		if(mCapturedGoatymonInfos[i].playerSlot != playerSlot)
			continue;

		if(capturedGoatymons.Length > 0)//Override existing goatymons
		{
			mCapturedGoatymonInfos[i]=SaveGoatymon(capturedGoatymons[capturedGoatymons.Length-1]);
			mCapturedGoatymonInfos[i].playerSlot=playerSlot;
			capturedGoatymons.Remove(capturedGoatymons.Length-1, 1);
		}
		else//delete old goatymon remaining
		{
			mCapturedGoatymonInfos.Remove(i, 1);
		}
	}
	for(i=0 ; i<capturedGoatymons.Length ; i++)//Add new goatymons
	{
		newGoatymonInfos=SaveGoatymon(capturedGoatymons[i]);
		newGoatymonInfos.playerSlot=playerSlot;
		mCapturedGoatymonInfos.AddItem(newGoatymonInfos);
	}
	SaveConfig();
}

function LoadGoatymon(GoatymonInfos goatymonInf, GGNPCGoatymon goatymon)
{
	//WorldInfo.Game.Broadcast(self, "LoadGoatymon" @ goatymon @ goatymonInf.ID @ goatymonInf.customName @ goatymonInf.maxHealth);
	goatymon.SetCustomMesh(goatymonInf.ID);
	goatymon.SetName(goatymonInf.customName);
	goatymon.SetMaxHealth(goatymonInf.maxHealth);
	goatymon.SpawnDefaultController();
}

function GoatymonInfos SaveGoatymon(GGNPCGoatymon goatymon)
{
	local GoatymonInfos goatymonInf;

	goatymonInf.ID=goatymon.mID;
	goatymonInf.customName=goatymon.mNPCName;
	goatymonInf.maxHealth=goatymon.mMaxHealth;
	//WorldInfo.Game.Broadcast(self, "SaveGoatymon" @ goatymon @ goatymonInf.ID @ goatymonInf.customName @ goatymonInf.maxHealth);

	return goatymonInf;
}

/*
function SaveInventory()
{
	local TrainerGoatComponent comp;
	local PlayerController pc;
	local GGPersistantInventory perInv;
	//WorldInfo.Game.Broadcast(self, "SaveInventory");
	foreach mComponents(comp)
	{
		pc=PlayerController(comp.gMe.Controller);
		if( pc != none )
		{
			perInv = class'GGGameViewportClient'.static.FindOrAddInventory( LocalPlayer( pc.Player ).ControllerId, WorldInfo.GetMapName( false ) $ "_Goatymon" );
			perInv.Clear();

			perInv.SaveInventory( comp.mGBInventory );
		}
	}
}*/

DefaultProperties
{
	mMutatorComponentClass=class'TrainerGoatComponent'
}