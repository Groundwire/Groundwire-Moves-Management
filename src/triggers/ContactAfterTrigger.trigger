trigger ContactAfterTrigger on Contact (after insert, after update) {
	
	MovesManagement mm = new MovesManagement();     
    mm.SetMovesManagerOnTeamMember(trigger.newMap, trigger.oldMap, trigger.isUpdate); 

}