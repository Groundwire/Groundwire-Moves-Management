trigger AccountBeforeTrigger on Account (before insert, before update) {

	list<Account> accountsToProcess = new list<Account>();
	
	for (Account a:trigger.new) {
		if (a.Moves_Manager__c != null && (trigger.isinsert || a.Moves_Manager__c!=trigger.oldmap.get(a.id).Moves_Manager__c)) {
			accountsToProcess.add(a);
		}
	}
	
	if (accountsToProcess.size()>0) {
		MovesManagement mm = new MovesManagement();     
    	mm.updateOwnerToMovesManager(accountsToProcess);
	}
}