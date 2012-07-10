public with sharing class EXT_TeamMemberResponsible {

	public Task thisTask {get;set;}
	private string donorId = '';
	//donor_org__c
	
	public list<selectoption> teamList {
		get {
			if (teamList==null) {
				list<selectoption> sol = new list<selectoption>();
				//if we already have a responsible, add them to the list first
				if (thisTask.Team_Member_Responsible_ID__c!=null && thisTask.Team_Member_Responsible_Name__c!=null) {
					sol.add(new selectOption(thisTask.Team_Member_Responsible_ID__c, thisTask.Team_Member_Responsible_Name__c));
					id tmr = (id)thisTask.Team_Member_Responsible_ID__c;
					for (Moves_Mgmt_Team_Member__c m : [SELECT Team_Member__c, Team_Member__r.Name, Team_Member__r.User__c, Moves_Manager__c
														FROM Moves_Mgmt_Team_Member__c WHERE Team_Member__c!=:tmr 
														AND (Donor_Contact__c=:donorId OR Donor_Org__c=:donorId) ORDER BY Moves_Manager__c DESC]) {
						sol.add(new SelectOption(m.Team_Member__c, m.Team_Member__r.Name));
					}	
				} else {
				//if there is no responsible, add the record owner as the first option, make sure the list doesn't contain them.
					sol.add(new SelectOption('',''));
					for (Moves_Mgmt_Team_Member__c m : [SELECT Team_Member__c, Team_Member__r.Name, Team_Member__r.User__c 
														FROM Moves_Mgmt_Team_Member__c WHERE (Donor_Contact__c=:donorId OR Donor_Org__c=:donorId)
														AND Team_Member__r.User__c!=:thisTask.OwnerId ORDER BY Moves_Manager__c DESC]) {
						sol.add(new SelectOption(m.Team_Member__c, m.Team_Member__r.Name));
					}	
				}
				teamlist=sol;
			}
			
			return teamlist;
		}
		set;
	}

	public list<Moves_Mgmt_Team_Member__c> movesTeam {
		get {
			if (movesTeam==null) {
				list<Moves_Mgmt_Team_Member__c> mmtm = [ SELECT Team_Member__c, Team_Member__r.Name, Team_Member__r.User__c
														 FROM Moves_Mgmt_Team_Member__c WHERE Donor_Contact__c=:thisTask.WhoId ];
				movesTeam = mmtm;
			}
			return movesTeam;
		}
		set;
	}

	public EXT_TeamMemberResponsible(ApexPages.StandardController controller) {
		string taskid = controller.getId();
		thisTask = [select Id, WhoId, WhatId, Subject, ActivityDate, Status, Priority, OwnerId, Owner.Name, Description, IsDeleted,
					AccountId, IsClosed,  Moves_Management_Stage__c, Team_Member_Responsible_ID__c, Team_Member_Responsible_Name__c
					from Task WHERE ID=:taskid];
		//Donor Id can be a Contact or an Account
		if (thisTask.WhoId!=null) {
			donorid = thisTask.whoId;
		} else if (((string)thisTask.whatId).startsWith('006')) {
			Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE Id=:thisTask.whatId];
			if (opp.AccountId!=null) donorId = (string)opp.AccountId;
		}
	}
	
	public pageReference updTeamMember(){
		//write the contact Name that corresponds to the id from the page
		if (thisTask.Team_Member_Responsible_ID__c!=null) {
			for (Moves_Mgmt_Team_Member__c mmtm : movesTeam) {
				if (mmtm.Team_Member__c == thisTask.Team_Member_Responsible_ID__c) {
					thisTask.Team_Member_Responsible_Name__c = mmtm.Team_Member__r.Name;
				}
			}
		}
		//update the task
		update thisTask;

		return null;
	}
	
	static testmethod void testContactDonor() {
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
		
		Task t = new Task(
			WhoId = donor.id,
			WhatId = opp.id,
			Subject = 'subject',
			ActivityDate = system.today().addDays(5)
		);
		
		insert t;
		
		PageReference pageRef = page.TeamMemberResponsible;
		test.setCurrentPageReference(pageRef);
		
		ApexPages.StandardController sc = new ApexPages.standardController(t);
		EXT_TeamMemberResponsible tmr = new EXT_TeamMemberResponsible(sc);
		
		system.assert(tmr.teamList.size() > 1);
		system.assert(tmr.movesTeam.size() > 1);
		tmr.updTeamMember();
	}
	
	static testmethod void testAccountDonor() {
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
		
		Task t = new Task(
			WhatId = opp.id,
			Subject = 'subject',
			ActivityDate = system.today().addDays(5),
			Team_Member_Responsible_ID__c = someOtherTeamMember.id,
			Team_Member_Responsible_Name__c = someOtherTeamMember.Name
		);
		
		insert t;
		
		PageReference pageRef = page.TeamMemberResponsible;
		test.setCurrentPageReference(pageRef);
		
		ApexPages.StandardController sc = new ApexPages.standardController(t);
		EXT_TeamMemberResponsible tmr = new EXT_TeamMemberResponsible(sc);
		
		system.assert(tmr.teamList.size() > 1);
		system.assert(tmr.movesTeam.size() > 1);
		tmr.updTeamMember();
	}
}