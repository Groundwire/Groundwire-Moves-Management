public with sharing class CTRL_NewMove {

	private Opportunity thisopp;
	private string retURL;
	private string donorId = '';
	public Task thisTask {get; set;}
	public boolean error {get; set;}
	
	public list<selectoption> teamList {
		get {
			if (teamList==null) {
				list<selectoption> sol = new list<selectoption>();

				for (Moves_Mgmt_Team_Member__c m : [SELECT Team_Member__c, Team_Member__r.Name, Team_Member__r.User__c, Moves_Manager__c 
													FROM Moves_Mgmt_Team_Member__c WHERE (Donor_Contact__c=:donorId OR Donor_Org__c=:donorId)
													ORDER BY Moves_Manager__c DESC]) {
					sol.add(new SelectOption(m.Team_Member__c, m.Team_Member__r.Name));
				}	
				if (!sol.isEmpty()) teamlist=sol;
				else sol.add(new SelectOption('',''));
			}
			return teamlist;
		}
		set;
	}

	public list<Moves_Mgmt_Team_Member__c> movesTeam {
		get {
			if (movesTeam==null) {
				list<Moves_Mgmt_Team_Member__c> mmtm = [ SELECT Team_Member__c, Team_Member__r.Name, Team_Member__r.User__c  
														 FROM Moves_Mgmt_Team_Member__c WHERE (Donor_Contact__c=:donorId OR Donor_Org__c=:donorId) ];
				movesTeam = mmtm;
			}
			return movesTeam;
		}
		set;
	}

    public CTRL_NewMove() {
    	error=false;
        retURL = ApexPages.currentPage().getParameters().get('id');
        if (retURL!=null && retURL.startsWith('006')) {
        	thisopp = [SELECT Id, GWBase__ContactId__c, accountId FROM Opportunity WHERE Id=:retURL];
        	thisTask = new Task(whatid = thisopp.id);
        	if (thisopp.GWBase__ContactId__c != null) {
        		thisTask.WhoId = thisopp.GWBase__ContactId__c;
        		donorid = (string)thisopp.GWBase__ContactId__c;
        	} else {
        		donorId = (string)thisopp.AccountId;
			}
        } else {
        	error=true;
        }
	}

    public PageReference newTask() {
        PageReference ref;
		
		if (thisTask.Team_Member_Responsible_ID__c!=null && thisTask.Team_Member_Responsible_ID__c!='') {
			for (Moves_Mgmt_Team_Member__c mmtm : movesTeam) {
				if (mmtm.Team_Member__c == thisTask.Team_Member_Responsible_ID__c) {
					thisTask.Team_Member_Responsible_Name__c = mmtm.Team_Member__r.Name;
					// also see if the "team member responsible" is a user.  if so, assign task to that user
					if (mmtm.Team_Member__r.User__c != null) {
						thisTask.OwnerId = mmtm.Team_Member__r.User__c;
					}
				}
			}
		}
		//update the task
		insert thisTask;
        ref = new pageReference('/'+thisTask.id+'/e?retURL=/'+retURL);
    	ref.setRedirect(true);    
        return ref;
    }
    
    static testmethod void testContact() {
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
		
		ApexPages.currentPage().getParameters().put('id', opp.id);
		CTRL_NewMove nm = new CTRL_NewMove();
		
		system.debug(nm.teamList);
		system.assertEquals(2,nm.teamList.size());
		
		nm.newTask();
		
		system.assert(nm.thisTask.id!=null);
    }

    static testmethod void testAccount() {
    	MovesManagement.setSettingsForTests();
    	
		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			On_Moves_Management_Team__c=true
		);
		insert movesManager;

		Account donor = new Account(
			Name = 'Homer Inc',
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
			Donor_Org__c = donor.id,
			Team_Member__c = someOtherTeamMember.id,
			Moves_Manager__c = false
		);
		insert tm;
		
		Opportunity opp = new Opportunity(
			RecordTypeID = MovesManagement.oppRectypeIdForTests,
			Amount = 888888,
			CloseDate = system.today().addDays(8),
			StageName = GWBase.ONEN_Constants.OPP_DEFAULT_STAGE,
			AccountId = donor.id
		);
		insert opp;
    	
		PageReference pageRef = page.NewMove;
		test.setCurrentPageReference(pageRef);
		
		ApexPages.currentPage().getParameters().put('id', opp.id);
		CTRL_NewMove nm = new CTRL_NewMove();
		
		system.debug(nm.teamList);
		system.assertEquals(2,nm.teamList.size());
		
		nm.newTask();
		
		system.assert(nm.thisTask.id!=null);
    }
}