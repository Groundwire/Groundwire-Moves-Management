trigger AccountAfterTrigger on Account (after insert, after update) {

	MovesManagement mm = new MovesManagement();     
	mm.SetMovesManagerOnTeamMember(trigger.newMap, trigger.oldMap, trigger.isUpdate); 

}