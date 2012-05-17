trigger OpportunityAfterTrigger on Opportunity (after insert) {
	
	MovesManagement mm = new MovesManagement();
	mm.addTeamToOppContactRoles(trigger.new);
	
}