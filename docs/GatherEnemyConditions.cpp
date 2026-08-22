//-----------------------------------------------------------------------------
// Purpose: part of the Condition collection process
//			gets and stores data and conditions pertaining to a npc's
//			enemy.
// 			@TODO (toml 07-27-03): this should become subservient to the senses. right
// 			now, it yields different result
// Input  :
// Output :
//-----------------------------------------------------------------------------
void CAI_BaseNPC::GatherEnemyConditions( CBaseEntity *pEnemy )
{
	AI_PROFILE_SCOPE(CAI_BaseNPC_GatherEnemyConditions);

	ClearCondition( COND_ENEMY_FACING_ME  );
	ClearCondition( COND_BEHIND_ENEMY   );

	// ---------------------------
	//  Set visibility conditions
	// ---------------------------
	if ( HasCondition( COND_NEW_ENEMY ) || GetSenses()->GetTimeLastUpdate( GetEnemy() ) == gpGlobals->curtime )
	{
		AI_PROFILE_SCOPE_BEGIN(CAI_BaseNPC_GatherEnemyConditions_Visibility);

		ClearCondition( COND_HAVE_ENEMY_LOS );
		ClearCondition( COND_ENEMY_OCCLUDED  );

		CBaseEntity *pBlocker = NULL;
		SetEnemyOccluder(NULL);

		bool bSensesDidSee = GetSenses()->DidSeeEntity( pEnemy );

		if ( !bSensesDidSee && ( ( EnemyDistance( pEnemy ) >= GetSenses()->GetDistLook() ) || !FVisible( pEnemy, MASK_BLOCKLOS, &pBlocker ) ) )
		{
			// No LOS to enemy
			SetEnemyOccluder(pBlocker);
			SetCondition( COND_ENEMY_OCCLUDED );
			ClearCondition( COND_SEE_ENEMY );

			if (HasMemory( bits_MEMORY_HAD_LOS ))
			{
				AI_PROFILE_SCOPE(CAI_BaseNPC_GatherEnemyConditions_Outputs);
				// Send output event
				if (GetEnemy()->IsPlayer())
				{
					m_OnLostPlayerLOS.FireOutput( GetEnemy(), this );
				}
				m_OnLostEnemyLOS.FireOutput( GetEnemy(), this );
			}
			Forget( bits_MEMORY_HAD_LOS );
		}
		else
		{
			// Have LOS but may not be in view cone
			SetCondition( COND_HAVE_ENEMY_LOS );

			if ( bSensesDidSee )
			{
				// Have LOS and in view cone
				SetCondition( COND_SEE_ENEMY );
			}
			else
			{
				ClearCondition( COND_SEE_ENEMY );
			}

			if (!HasMemory( bits_MEMORY_HAD_LOS ))
			{
				AI_PROFILE_SCOPE(CAI_BaseNPC_GatherEnemyConditions_Outputs);
				// Send output event
				EHANDLE hEnemy;
				hEnemy.Set( GetEnemy() );

				if (GetEnemy()->IsPlayer())
				{
					m_OnFoundPlayer.Set(hEnemy, this, this);
					m_OnFoundEnemy.Set(hEnemy, this, this);
				}
				else
				{
					m_OnFoundEnemy.Set(hEnemy, this, this);
				}
			}
			Remember( bits_MEMORY_HAD_LOS );
		}

		AI_PROFILE_SCOPE_END();
	}

  	// -------------------
  	// If enemy is dead
  	// -------------------
  	if ( !pEnemy->IsAlive() )
  	{
  		SetCondition( COND_ENEMY_DEAD );
  		ClearCondition( COND_SEE_ENEMY );
  		ClearCondition( COND_ENEMY_OCCLUDED );
  		return;
  	}	
	
	float flDistToEnemy = EnemyDistance(pEnemy);

	AI_PROFILE_SCOPE_BEGIN(CAI_BaseNPC_GatherEnemyConditions_SeeEnemy);
	
	if ( HasCondition( COND_SEE_ENEMY ) )
	{
		// Trail the enemy a bit if he's moving
		if (pEnemy->GetSmoothedVelocity() != vec3_origin)
		{
			Vector vTrailPos = pEnemy->GetAbsOrigin() - pEnemy->GetSmoothedVelocity() * random->RandomFloat( -0.05, 0 );
			UpdateEnemyMemory(pEnemy,vTrailPos);
		}
		else
		{
			UpdateEnemyMemory(pEnemy,pEnemy->GetAbsOrigin());
		}

		// If it's not an NPC, assume it can't see me
		if ( pEnemy->MyCombatCharacterPointer() && pEnemy->MyCombatCharacterPointer()->FInViewCone ( this ) )
		{
			SetCondition ( COND_ENEMY_FACING_ME );
			ClearCondition ( COND_BEHIND_ENEMY );
		}
		else
		{
			ClearCondition( COND_ENEMY_FACING_ME );
			SetCondition ( COND_BEHIND_ENEMY );
		}
	}
	else if ( (!HasCondition(COND_ENEMY_OCCLUDED) && !HasCondition(COND_SEE_ENEMY)) && ( flDistToEnemy <= 256 ) )
	{
		// if the enemy is not occluded, and unseen, that means it is behind or beside the npc.
		// if the enemy is near enough the npc, we go ahead and let the npc know where the
		// enemy is. Send the enemy in as the informer so this knowledge will be regarded as 
		// secondhand so that the NPC doesn't 
		UpdateEnemyMemory( pEnemy, pEnemy->GetAbsOrigin(), pEnemy );
	}

	AI_PROFILE_SCOPE_END();

	float tooFar = m_flDistTooFar;
	if ( GetActiveWeapon() && HasCondition(COND_SEE_ENEMY) )
	{
		tooFar = MAX( m_flDistTooFar, GetActiveWeapon()->m_fMaxRange1 );
	}

	if ( flDistToEnemy >= tooFar )
	{
		// enemy is very far away from npc
		SetCondition( COND_ENEMY_TOO_FAR );
	}
	else
	{
		ClearCondition( COND_ENEMY_TOO_FAR );
	}

	if ( FCanCheckAttacks() )
	{
		// This may also call SetEnemyOccluder!
		GatherAttackConditions( GetEnemy(), flDistToEnemy );
	}
	else
	{
		ClearAttackConditions();
	}

	// If my enemy has moved significantly, or if the enemy has changed update my path
	UpdateEnemyPos();

	// If my target entity has moved significantly, update my path
	// This is an odd place to put this, but where else should it go?
	UpdateTargetPos();

	// ----------------------------------------------------------------------------
	// Check if enemy is reachable via the node graph unless I'm not on a network
	// ----------------------------------------------------------------------------
	if (GetNavigator()->IsOnNetwork())
	{
		// Note that unreachablity times out
		if (IsUnreachable(GetEnemy()))
		{
			SetCondition(COND_ENEMY_UNREACHABLE);
		}
	}

	//-----------------------------------------------------------------------
	// If I haven't seen the enemy in a while he may have eluded me
	//-----------------------------------------------------------------------
	if (gpGlobals->curtime - GetEnemyLastTimeSeen() > 8)
	{
		//-----------------------------------------------------------------------
		// I'm at last known position at enemy isn't in sight then has eluded me
		// ----------------------------------------------------------------------
		Vector flEnemyLKP = GetEnemyLKP();
		if (((flEnemyLKP - GetAbsOrigin()).Length2D() < 48) &&
			!HasCondition(COND_SEE_ENEMY))
		{
			MarkEnemyAsEluded();
		}
		//-------------------------------------------------------------------
		// If enemy isn't reachable, I can see last known position and enemy
		// isn't there, then he has eluded me
		// ------------------------------------------------------------------
		if (!HasCondition(COND_SEE_ENEMY) && HasCondition(COND_ENEMY_UNREACHABLE))
		{
			if ( !FVisible( flEnemyLKP ) )
			{
				MarkEnemyAsEluded();
			}
		}
	}
}
