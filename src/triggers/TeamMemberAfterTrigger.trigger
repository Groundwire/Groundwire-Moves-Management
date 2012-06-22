trigger TeamMemberAfterTrigger on Moves_Mgmt_Team_Member__c (after delete, after insert, after undelete, 
after update) {
	
	MovesManagement mm = new MovesManagement();     
    mm.SetMovesManagerOnDonor(trigger.New, trigger.Old, (trigger.isInsert || trigger.isUndelete || trigger.isUpdate), trigger.isDelete); 
	
}