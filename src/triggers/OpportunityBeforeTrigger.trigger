trigger OpportunityBeforeTrigger on Opportunity (before insert) {

	if (trigger.new.size()==1) {
		Opportunity opp = trigger.new[0];
		
		MovesManagement mm = new MovesManagement();
		id newOwnerId = mm.setOppOwnerToDonorMM (opp);
		if (newOwnerId != null) opp.OwnerId = newOwnerId;		
	}

}