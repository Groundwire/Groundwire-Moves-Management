trigger ContactBeforeTrigger on Contact (before insert, before update) {
	list<Contact> contactsToProcess = new list<Contact>();
	
	for (Contact c:trigger.new) {
		if (c.Moves_Manager__c != null && (trigger.isinsert || c.Moves_Manager__c!=trigger.oldmap.get(c.id).Moves_Manager__c)) {
			contactsToProcess.add(c);
		}
	}
	
	if (contactsToProcess.size()>0) {
		MovesManagement mm = new MovesManagement();     
    	mm.updateOwnerToMovesManager(contactsToProcess);
	}
}