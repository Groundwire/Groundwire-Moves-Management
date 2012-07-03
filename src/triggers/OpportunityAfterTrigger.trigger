trigger OpportunityAfterTrigger on Opportunity (after insert, after update) {

	set<id> accountIds = new set<id>();
	set<id> contactIds = new set<id>();
	Moves_Management_Settings__c mmsettings = Moves_Management_Settings__c.getInstance();
	set<string> movesRecordTypes = new set<string>();
	
	for (string s:mmsettings.Opportunity_Record_Types__c.split(';')) {
		movesRecordTypes.add(s);
	}

	set<id> movesRecordTypeIds = GWBase.GW_RecTypes.GetRecordTypeIdSet('Opportunity',movesRecordTypes);

	if (trigger.isinsert) {
		MovesManagement mm = new MovesManagement();
		mm.addTeamToOppContactRoles(trigger.new);	
	}
	
	for (Opportunity o:trigger.new) {
		if (o.AccountId!=null && movesRecordTypeIds.contains(o.RecordTypeID)) {
			accountIds.add(o.accountId);			
		}
		if (o.GWBase__ContactId__c!=null && movesRecordTypeIds.contains(o.RecordTypeID)) {
			contactIds.add(o.GWBase__ContactId__c);
		}
	}
	
	if (!accountIds.isEmpty()) {
		AccountStatusRollup accrollup = new AccountStatusRollup(contactIds);
		accrollup.runRollups();
	}
	
	if (!contactIds.isEmpty()) {
		ContactStatusRollup conrollup = new ContactStatusRollup(contactIds);
		conrollup.runRollups();
	}
}