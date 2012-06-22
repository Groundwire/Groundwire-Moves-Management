public with sharing class EXT_TeamMemberResponsible {

	public Task thisTask {get;set;}
	
	public list<selectoption> teamList {
		get {
			list<selectoption> sol = new list<selectoption>();
			//if we already have a responsible, add them to the list first
			if (thisTask.Team_Member_Responsible_ID__c!=null && thisTask.Team_Member_Responsible_Name__c!=null) {
				sol.add(new selectOption(thisTask.Team_Member_Responsible_ID__c, thisTask.Team_Member_Responsible_Name__c));
				id tmr = (id)thisTask.Team_Member_Responsible_ID__c;
				for (Moves_Mgmt_Team_Member__c m : [SELECT Team_Member__c, Team_Member__r.Name, Team_Member__r.User__c 
													FROM Moves_Mgmt_Team_Member__c WHERE Team_Member__c!=:tmr 
													AND Donor_Contact__c=:thisTask.WhoId]) {
					sol.add(new SelectOption(m.Team_Member__c, m.Team_Member__r.Name));
				}	
			} else {
			//if there is no responsible, add the record owner as the first option, make sure the list doesn't contain them.
				sol.add(new SelectOption('',thisTask.Owner.Name));
				for (Moves_Mgmt_Team_Member__c m : [SELECT Team_Member__c, Team_Member__r.Name, Team_Member__r.User__c 
													FROM Moves_Mgmt_Team_Member__c WHERE Donor_Contact__c=:thisTask.WhoId
													AND Team_Member__r.User__c!=:thisTask.OwnerId ]) {
					sol.add(new SelectOption(m.Team_Member__c, m.Team_Member__r.Name));
				}	
			}
			if (sol.isEmpty()) return null;
			return sol;
		}
		set;
	}

	public list<Moves_Mgmt_Team_Member__c> movesTeam {
		get {
			if (movesTeam==null) {
				list<Moves_Mgmt_Team_Member__c> mmtm = [ SELECT Team_Member__c, Team_Member__r.Name, Team_Member__r.User__c
														 FROM Moves_Mgmt_Team_Member__c WHERE Donor_Contact__c=:thisTask.WhoId ];
				return mmtm;
			}
			return null;
		}
		set;
	}

	public EXT_TeamMemberResponsible(ApexPages.StandardController controller) {
		string taskid = controller.getId();
		thisTask = [select Id, WhoId, WhatId, Subject, ActivityDate, Status, Priority, OwnerId, Owner.Name, Description, IsDeleted,
					AccountId, IsClosed,  Moves_Management_Stage__c, Team_Member_Responsible_ID__c, Team_Member_Responsible_Name__c
					from Task WHERE ID=:taskid];
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
}