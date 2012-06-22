trigger TaskBeforeTrigger on Task (before update) {
	
	set<string> closedStatus = new set<string>();
	map<id,Task> tasksToStamp = new map<id,Task>();
	
	//create a set of closed statuses
	for (TaskStatus ts : [SELECT MasterLabel from TaskStatus WHERE IsClosed=true]) {
		closedStatus.add(ts.MasterLabel);
	}

	//if this update closed the task and the MM Stage wasn't set manually, stamp with opp stage
	for (Task t:trigger.new) {
		Task oldTask = trigger.oldMap.get(t.Id);
		if (((string)t.whatId).startsWith('006') && t.Moves_Management_Stage__c==null && closedStatus.contains(t.Status) && !closedStatus.contains(oldtask.status)) {
			tasksToStamp.put(t.whatid, t);
		}
	}

	if (!tasksToStamp.isEmpty()) {
		MovesManagement mm = new MovesManagement();
		if (!tasksToStamp.isEmpty()) mm.stampTaskOppStage(tasksToStamp);
	}
	
}