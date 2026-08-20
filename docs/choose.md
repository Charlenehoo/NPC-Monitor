```cpp
bool CAI_BaseNPC::ChooseEnemy( void )
{
	AI_PROFILE_SCOPE(CAI_Enemies_ChooseEnemy);

	DbgEnemyMsg( this, "ChooseEnemy() {\n" );

	//---------------------------------
	//
	// Gather initial conditions
	//

	CBaseEntity *pInitialEnemy = GetEnemy();
	CBaseEntity *pChosenEnemy  = pInitialEnemy;

	// Use memory bits in case enemy pointer altered outside this function, (e.g., ehandle goes NULL)
	bool fHadEnemy  	 = ( HasMemory( bits_MEMORY_HAD_ENEMY | bits_MEMORY_HAD_PLAYER ) );
	bool fEnemyWasPlayer = HasMemory( bits_MEMORY_HAD_PLAYER );
	bool fEnemyWentNull  = ( fHadEnemy && !pInitialEnemy );
	bool fEnemyEluded	 = ( fEnemyWentNull || ( pInitialEnemy && GetEnemies()->HasEludedMe( pInitialEnemy ) ) );

	//---------------------------------
	//
	// Establish suitability of choosing a new enemy
	//

	bool fHaveCondNewEnemy;
	bool fHaveCondLostEnemy;

	if ( !m_ScheduleState.bScheduleWasInterrupted && GetCurSchedule() && !FScheduleDone() )
	{
		Assert( InterruptFromCondition( COND_NEW_ENEMY ) == COND_NEW_ENEMY && InterruptFromCondition( COND_LOST_ENEMY ) == COND_LOST_ENEMY );
		fHaveCondNewEnemy  = GetCurSchedule()->HasInterrupt( COND_NEW_ENEMY );
		fHaveCondLostEnemy = GetCurSchedule()->HasInterrupt( COND_LOST_ENEMY );

		// See if they've been added as a custom interrupt
		if ( !fHaveCondNewEnemy )
		{
			fHaveCondNewEnemy = IsCustomInterruptConditionSet( COND_NEW_ENEMY );
		}
		if ( !fHaveCondLostEnemy )
		{
			fHaveCondLostEnemy = IsCustomInterruptConditionSet( COND_LOST_ENEMY );
		}
	}
	else
	{
		fHaveCondNewEnemy  = true; // not having a schedule is the same as being interruptable by any condition
		fHaveCondLostEnemy = true;
	}

	if ( !fEnemyWentNull )
	{
		if ( !fHaveCondNewEnemy && !( fHaveCondLostEnemy && fEnemyEluded ) )
		{
			// DO NOT mess with the npc's enemy pointer unless the schedule the npc is currently
			// running will be interrupted by COND_NEW_ENEMY or COND_LOST_ENEMY. This will
			// eliminate the problem of npcs getting a new enemy while they are in a schedule
			// that doesn't care, and then not realizing it by the time they get to a schedule
			// that does. I don't feel this is a good permanent fix.
			m_bSkippedChooseEnemy = true;

			DbgEnemyMsg( this, "Skipped enemy selection due to schedule restriction\n" );
			DbgEnemyMsg( this, "}\n" );
			return ( pChosenEnemy != NULL );
		}
	}
	else if ( !fHaveCondNewEnemy && !fHaveCondLostEnemy && GetCurSchedule() )
	{
		DevMsg( 2, "WARNING: AI enemy went NULL but schedule (%s) is not interested\n", GetCurSchedule()->GetName() );
	}

	m_bSkippedChooseEnemy = false;

	//---------------------------------
	//
	// Select a target
	//

	if ( ShouldChooseNewEnemy()	)
	{
		pChosenEnemy = BestEnemy();
	}

	//---------------------------------
	//
	// React to result of selection
	//

	bool fChangingEnemy = ( pChosenEnemy != pInitialEnemy );

	if ( fChangingEnemy || fEnemyWentNull )
	{
		DbgEnemyMsg( this, "Enemy changed from %s to %s\n", pInitialEnemy->GetDebugName(), pChosenEnemy->GetDebugName() );
		Forget( bits_MEMORY_HAD_ENEMY | bits_MEMORY_HAD_PLAYER );

		// Did our old enemy snuff it?
		if ( pInitialEnemy && !pInitialEnemy->IsAlive() )
		{
			SetCondition( COND_ENEMY_DEAD );
		}

		SetEnemy( pChosenEnemy );

		if ( fHadEnemy )
		{
			// Vacate any strategy slot on old enemy
			VacateStrategySlot();

			// Force output event for establishing LOS
			Forget( bits_MEMORY_HAD_LOS );
			// m_flLastAttackTime	= 0;
		}

		if ( !pChosenEnemy )
		{
			// Don't break on enemies going null if they've been killed
			if ( !HasCondition(COND_ENEMY_DEAD) )
			{
				SetCondition( COND_ENEMY_WENT_NULL );
			}

			if ( fEnemyEluded )
			{
				SetCondition( COND_LOST_ENEMY );
				LostEnemySound();
			}

			if ( fEnemyWasPlayer )
			{
				m_OnLostPlayer.FireOutput( pInitialEnemy, this );
			}
			m_OnLostEnemy.FireOutput( pInitialEnemy, this);
		}
		else
		{
			Remember( ( pChosenEnemy->IsPlayer() ) ? bits_MEMORY_HAD_PLAYER : bits_MEMORY_HAD_ENEMY );
		}
	}

	//---------------------------------

	return ( pChosenEnemy != NULL );
}
```
