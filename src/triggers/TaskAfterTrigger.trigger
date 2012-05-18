trigger TaskAfterTrigger on Task (after delete, after insert, after undelete, after update) {
	set<id> oppsToRollup = new set<id>();
	//change Status or ActivityDate or WhatID -> send to rollup
	//rollup first completed and and first not completed

	if (trigger.isDelete) {
		for (Task t:trigger.old) {
			if (((string)t.whatId).startsWith('006')) {
				oppsToRollup.add(t.whatId);
			}
		}
	}

	if (trigger.isInsert || trigger.isUndelete) {
		for (Task t:trigger.new) {
			if (((string)t.whatId).startsWith('006')) {
				oppsToRollup.add(t.whatId);
			}
		}
	}

	if (trigger.isUpdate) {
		for (Task t:trigger.new) {
			Task oldTask = trigger.oldMap.get(t.Id);
			
			if (((string)t.whatId).startsWith('006')) {
				if (
					t.Status != oldTask.Status ||
					t.ActivityDate != oldTask.ActivityDate ||
					t.whatId != oldTask.whatId
				) {
					oppsToRollup.add(t.whatId);
				}
			}
			
			if (((string)oldTask.whatId).startsWith('006')) {
				if (t.whatId != oldTask.whatId) {
					oppsToRollup.add(oldTask.whatId);
				}
			}
		}
	}
	
	if (oppsToRollup.size() > 0) {
		MovesManagement mm = new MovesManagement();
		mm.movesOppRollup(oppsToRollup);
	}
}