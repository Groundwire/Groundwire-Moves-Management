public with sharing class EXT_NewMove {

	Opportunity thisopp;

    public EXT_NewMove(ApexPages.StandardController controller) {
        thisopp = (Opportunity)controller.getRecord();
	}

    public PageReference newTask() {
        PageReference ref;

        if (thisopp != null) {
            //standard new task URL if this is not a Move applied to contact
            if (thisopp.GWBase__ContactId__c!=null) {
				ref = new PageReference('/00T/e?what_id=' + thisopp.id + '&who_id=' + thisopp.GWBase__ContactId__c + '&retURL=%2F' + thisopp.id); //https://na9.salesforce.com/00T/e?what_id=006E0000003KFLD&retURL=%2F006E0000003KFLD who_id
            } else {
            	ref = new PageReference('/00T/e?what_id=' + thisopp.id + '&retURL=%2F' + thisopp.id); 
            }
        	ref.setRedirect(true);    
        }
        
        return ref;
    }
    
    static testmethod void test() {
    	MovesManagement.setSettingsForTests();
    	
		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			On_Moves_Management_Team__c=true
		);
		insert movesManager;

		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson',
			Moves_Manager__c = movesManager.id
		);
		insert donor;
		
		Contact someOtherTeamMember = new Contact(
			FirstName = 'Ned',
			LastName = 'Flander',
			On_Moves_Management_Team__c=true
		);
		insert someOtherTeamMember;
		
		Moves_Mgmt_Team_Member__c tm = new Moves_Mgmt_Team_Member__c(
			Donor_Contact__c = donor.id,
			Team_Member__c = someOtherTeamMember.id,
			Moves_Manager__c = false
		);
		insert tm;
		
		Opportunity opp = new Opportunity(
			RecordTypeID = MovesManagement.oppRectypeIdForTests,
			Amount = 888888,
			CloseDate = system.today().addDays(8),
			StageName = GWBase.ONEN_Constants.OPP_DEFAULT_STAGE,
			GWBase__CR_Contact_Id__c = donor.id,
			GWBase__CR_Contact_Role__c = 'Major Donor',
			GWBase__ContactId__c = donor.id
		);
		insert opp;
    	
		PageReference pageRef = page.NewMove;
		test.setCurrentPageReference(pageRef);
		
		ApexPages.StandardController sc = new ApexPages.standardController(opp);
		EXT_NewMove tmr = new EXT_NewMove(sc);
		tmr.newTask();
    }
}