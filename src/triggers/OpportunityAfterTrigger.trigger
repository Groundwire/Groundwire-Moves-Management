trigger OpportunityAfterTrigger on Opportunity (after insert, after update) {

	set<id> accountIds = new set<id>();
	set<id> contactIds = new set<id>();
	
	/* refactored into class
	Moves_Management_Settings__c mmsettings = Moves_Management_Settings__c.getInstance();
	set<string> movesRecordTypes = new set<string>();
	
	for (string s:mmsettings.Opportunity_Record_Types__c.split(';')) {
		movesRecordTypes.add(s);
	}

	set<id> movesRecordTypeIds = GWBase.GW_RecTypes.GetRecordTypeIdSet('Opportunity',movesRecordTypes);
	*/

	MovesManagement mm = new MovesManagement();

	if (trigger.isinsert) {
		mm.addTeamToOppContactRoles(trigger.new);	
	}
	
	for (Opportunity o:trigger.new) {
		if (o.AccountId!=null && mm.isMMOppRectype(o.RecordTypeID)) {
			accountIds.add(o.accountId);			
		}
		if (o.GWBase__ContactId__c!=null && mm.isMMOppRectype(o.RecordTypeID)) {
			contactIds.add(o.GWBase__ContactId__c);
		}
	}
	
	if (!accountIds.isEmpty()) {
		AccountStatusRollup accrollup = new AccountStatusRollup(accountIds);
		accrollup.runRollups();
	}
	
	if (!contactIds.isEmpty()) {
		ContactStatusRollup conrollup = new ContactStatusRollup(contactIds);
		conrollup.runRollups();
	}
}