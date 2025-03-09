class GoatyballsInventory extends GGInventory;

var vector baseSpawnLoc;

/**
 * Used when the user removes an item from the inventory
 */
function RemoveFromInventory( int index, optional bool triggerEvent = true )
{
 	local GGNpc npc;
 	local GGAIController contr;

	 super.RemoveFromInventory(index, triggerEvent);

	npc=GGNpc(mLastItemRemoved);
 	if(npc != none)
	{
		if(npc.mIsRagdoll)
		{
			contr=GGAIController(npc.Controller);
			if(contr != none)
			{
				contr.StandUp();
			}

			if(npc.mIsRagdoll)
			{
				npc.StandUp();
			}
		}

		if(!npc.mIsRagdoll)
	 	{
	 		npc.SetPhysics(PHYS_Falling);
	 	}
 	}
}

/**
 * Where to try spawn the stuff coming out of the inventory.
 */
function vector GetSpawnLocationForItem( GGInventoryActorInterface item )
{
	local Actor itemActor, hitActor;
	local vector spawnLocation, itemExtent, itemExtentOffset, traceStart, traceEnd, traceExtent, hitLocation, hitNormal;
	local box itemBoundingBox;

	spawnLocation = vect( 0, 0, 0 );

	itemActor = Actor( item );
	if(itemActor != none)
	{
		spawnLocation = baseSpawnLoc;
		itemActor.GetComponentsBoundingBox( itemBoundingBox );

		itemExtent = ( itemBoundingBox.Max - itemBoundingBox.Min ) * 0.5f;
		itemExtentOffset = itemBoundingBox.Min + ( itemBoundingBox.Max - itemBoundingBox.Min ) * 0.5f - itemActor.Location;

		// Trace downward.
		traceStart = spawnLocation + vect( 0, 0, 1 ) * itemExtent.Z * 2.0f;
		traceEnd = spawnLocation - vect( 0, 0, 1 ) * itemExtent.Z;
		traceExtent = itemExtent;

		hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, false, traceExtent );
		if( hitActor == none )
		{
			hitLocation = traceEnd;
		}

		// The bounding box's location is not the same as the actors location so we need an offset.
		spawnLocation = hitLocation - itemExtentOffset;
	}
	else
	{
		`Log( "GGInventory failed to find spawn point for item actor " $ itemActor );
	}

	return spawnLocation;
}
/*
function LoadInventory()
{
	local GGPersistantInventory inv;
	local PlayerController PC;
	local LocalPlayer localPlayer;
	//WorldInfo.Game.Broadcast(self, "LoadInventory");
	if( mIsLoaded )
	{
		return;
	}

	mIsLoaded = true;

	PC = PlayerController( Pawn( Owner ).Controller );

	mInitiated = true;

	localPlayer = PC != none ? LocalPlayer( PC.Player ) : none;

	if( localPlayer != none )
	{
		inv = class'GGGameViewportClient'.static.FindOrAddInventory( localPlayer.ControllerId, WorldInfo.GetMapName( false ) $ "_Goatymon" );
		if( inv != none )
		{
			inv.RecreateInventory( self );
			//WorldInfo.Game.Broadcast(self, "Loaded");
		}
	}
}
*/
function NotifyHUDItemAdded();

DefaultProperties
{

}