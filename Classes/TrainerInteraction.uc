class TrainerInteraction extends Interaction;

var TrainerGoat myMut;

function InitTrainerInteraction(TrainerGoat newMut)
{
	myMut=newMut;
}

exec function RenameGoatymon(string newName)
{
	local GGAIControllerGoatymon gContr;

	if(myMut.mLastBallUsed != none)
	{
		if(myMut.mLastBallUsed.mMyPawn != none)
		{
			gContr=GGAIControllerGoatymon(myMut.mLastBallUsed.mMyPawn.Controller);
			if(gContr != none)
			{
				gContr.RenameGoatymon(newName);
				return;
			}
		}
	}

	myMut.WorldInfo.Game.Broadcast(myMut, "The last Goatyball was not used on a Goatymon :(");
}

exec function GoatymonMaker()
{
	local GGAIControllerGoatymon gContr;

	if(myMut.mLastBallUsed != none)
	{
		if(myMut.mLastBallUsed.mMyPawn != none)
		{
			if(class'GGAIControllerGoatymon'.static.MakeItGoatymon(myMut.mLastBallUsed.mMyPawn))
			{
				gContr=GGAIControllerGoatymon(myMut.mLastBallUsed.mMyPawn.Controller);
				gContr.BeGoatymonOf(myMut.mLastBallUsed.mGoat);
				gContr.mGoatyballContainer=myMut.mLastBallUsed;
				return;
			}
		}
	}

	myMut.WorldInfo.Game.Broadcast(myMut, "The last Goatyball was not used on a creature, or this creature is already a Goatymon :(");
}

exec function ToggleGoatymonSpeech()
{
	local bool newUseSpeech;

	newUseSpeech=class'TrainerGoatComponent'.static.ToggleUseSpeech();
	myMut.WorldInfo.Game.Broadcast(myMut, "Goatymon speech" @ (newUseSpeech?"enabled":"disabled"));
}

exec function ToggleGoatymonPvP()
{
	local bool newPvP;

	newPvP=class'TrainerGoatComponent'.static.TogglePvP();
	myMut.WorldInfo.Game.Broadcast(myMut, "Goatymon PvP" @ (newPvP?"enabled":"disabled"));
}