public with sharing class MovesManagement {
	
	static boolean updatingMovesManagementTeam = false;
	
	public void SetMovesManagerOnContact(list<Moves_Mgmt_Team_Member__c> listTeamMemberNew, list<Moves_Mgmt_Team_Member__c> listTeamMemberOld, 
										boolean isInsertOrUpdate, boolean isDelete) {
		
		//only exercise this code if we haven't just fired a trigger to set the moves manager on contact from the team member object
		if (!updatingMovesManagementTeam) {
			list<Contact> consToUpdate = new list<Contact>();
			
			for (Moves_Mgmt_Team_Member__c tm : (isInsertOrUpdate ? listTeamMemberNew : listTeamMemberOld)) {
				//if this team member is listed as the moves manager, update the contact lookup
				
				if (tm.Moves_Manager__c && tm.Donor_Contact__c != null) {
					Contact c = new Contact(
						id = tm.Donor_Contact__c,
						Moves_Manager__c = isInsertOrUpdate ? tm.Team_Member__c : null //if it's not an insert, it's a delete and we want to null out the Moves Manager field on Contact
						);
					consToUpdate.add(c);
				}
			}
			
			if (!consToUpdate.isEmpty()) {
				//in order to prevent recursion, set this variable so change to moves manager on contact doesn't trigger more code to run
				updatingMovesManagementTeam = true;
				update consToUpdate;
			}
		}
		
	}

	
	public void updateContactOwnerToMovesManager(list<Contact> consWithNewMovesManager) {
		set<id> movesManagers = new set<id>();
		map<Id,Id> ownersToUpdate = new map<Id,Id>();
		
		//compile list of ContactIDs of Moves Managers
		for (Contact c:consWithNewMovesManager) {
			movesManagers.add(c.Moves_Manager__c);
		}
		
		//Make map of ContactId to UserId of Moves Managers with associated users
		for (Contact c:[SELECT Id, User__c FROM Contact WHERE User__c!=null AND Id IN :movesManagers]) {
			ownersToUpdate.put(c.Id,c.User__c);
		}
		
		//Update OwnerID with Moves Manager User
		for (Contact c:consWithNewMovesManager) {
			if (ownersToUpdate.containsKey(c.Moves_Manager__c)) {
				c.OwnerId = ownersToUpdate.get(c.Moves_Manager__c);
				system.debug('Worked! '+c.OwnerId);
			}
		}
	}
	
	public void SetMovesManagerOnTeamMember(map<id,Contact> conMap, map<id,contact> oldMap, boolean isUpdate) {
		
		//only exercise this code if we haven't just fired a trigger to set the moves manager on contact from the team member object
		if (!updatingMovesManagementTeam) {
			
			// map of contact id to all team members related to that contact
			map<id,set<Moves_Mgmt_Team_Member__c>> conIdToTeamMap = new map<id,set<Moves_Mgmt_Team_Member__c>>();
			
			// first we need to find all of the related team members for each contact in the trigger set, so we know whether to update an 
			// existing team member record or create a new one
			for (Contact c : conMap.values()) {
				//only create or update team member records if Moves Manager lookup is populated or was just blanked out with an update
				if ((!isUpdate && c.Moves_Manager__c != null) || (isUpdate && c.Moves_Manager__c != oldMap.get(c.id).Moves_Manager__c)) {
					conIdToTeamMap.put(c.id,new set<Moves_Mgmt_Team_Member__c>());
				}
			}
			
			//now go find all of the existing team member records for these contacts and build out our map
			if (!conIdToTeamMap.isEmpty()) {
				
				list<Moves_Mgmt_Team_Member__c> teamMembersToCreate = new list<Moves_Mgmt_Team_Member__c>();
				list<Moves_Mgmt_Team_Member__c> teamMembersToUpdate = new list<Moves_Mgmt_Team_Member__c>();
				
				for (Moves_Mgmt_Team_Member__c tm : [SELECT id, Moves_Manager__c, Team_Member__c, Donor_Contact__c FROM Moves_Mgmt_Team_Member__c
														WHERE Donor_Contact__c IN :conIdToTeamMap.keyset() ]) {
					conIdToTeamMap.get(tm.Donor_Contact__c).add(tm);
				}
				
				// now loop back through the map and update or create team member records as needed to reflect
				// the moves manager indicated on the contact record
				for (id cid : conIdToTeamMap.keyset()) {
					// if we don't have any existing team member records, we need to create one
					boolean createTeamMemberRecord = true;
					for (Moves_Mgmt_Team_Member__c tm : conIdToTeamMap.get(cid)) {
						if (tm.Team_Member__c == conMap.get(cid).Moves_Manager__c && tm.Moves_Manager__c) {
							//we already have the correct team manager
							createTeamMemberRecord = false;
							break;
						} else if (tm.Team_Member__c != conMap.get(cid).Moves_Manager__c && tm.Moves_Manager__c) {
							//there is a team member record with another Moves Manager marked, and we need to unmark and update that record	
							tm.Moves_Manager__c = false;
							teamMembersToUpdate.add(tm);
						} else if (tm.Team_Member__c == conMap.get(cid).Moves_Manager__c && !tm.Moves_Manager__c) {
							//there is a team member record for this Moves Manager, but that record is marked as the Moves Manager yet, so mark it
							tm.Moves_Manager__c = true;
							teamMembersToUpdate.add(tm);
							createTeamMemberRecord = false;
						}
					}
					
					if (createTeamMemberRecord) {
						Moves_Mgmt_Team_Member__c tm = new Moves_Mgmt_Team_Member__c(
							Donor_Contact__c = cid,
							Team_Member__c = conMap.get(cid).Moves_Manager__c,
							Moves_Manager__c = true
						);
						teamMembersToCreate.add(tm);
					}
				}
				
				if (!teamMembersToCreate.isEmpty()) {
					updatingMovesManagementTeam = true;
					insert teamMembersToCreate;
				}
				if (!teamMembersToUpdate.isEmpty()) {
					updatingMovesManagementTeam = true;
					update teamMembersToUpdate;
				}
				
			}

		}
		
	}
	
	public void addTeamToOppContactRoles(list<Opportunity> opps) {
		
		//first check to see if we're in GWBase, because GWBase has a lookup to Contact on Opp, otherwise we can't do this logic
		Schema.SObjectType token = Schema.getGlobalDescribe().get('GWBase__ONEN_Household__c');
		if (token != null) {				
			
			map<id,set<id>> conIdToTeamMap = new map<id,set<id>>();
			map<id,id> conIdToMovesManagerMap = new map<id,id>();
			list<Opportunity> oppsToProcess = new list<Opportunity>();
			
			for (Opportunity o : opps) {
				if (o.get('GWBase__ContactId__c') != null) {
					conIdToTeamMap.put((id)o.get('GWBase__ContactId__c'),new set<id>());
					oppsToProcess.add(o);
				}
			}
			
			//now go query for all of the team members for each major donor and build out the map
			for (Moves_Mgmt_Team_Member__c tm : [SELECT id, Moves_Manager__c, Team_Member__c, Donor_Contact__c FROM Moves_Mgmt_Team_Member__c
														WHERE Donor_Contact__c IN :conIdToTeamMap.keyset() ]) {
											
				if (!tm.Moves_Manager__c) {
					conIdToTeamMap.get(tm.Donor_Contact__c).add(tm.Team_Member__c);
				} else {
					conIdToMovesManagerMap.put(tm.Donor_Contact__c,tm.Team_Member__c);
				}
			}
			
		}
		
	}
	
	/****************************************
	*				TESTS					*
	****************************************/
	
	static testmethod void insertTeamMemberManager() {
		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson',
			Moves_Manager__c = null
		);
		insert donor;
		
		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			On_Moves_Management_Team__c=true
		);
		insert movesManager;
		
		Contact someTeamMemberContact = new Contact(
			FirstName = 'Ned',
			LastName = 'Flanders',
			On_Moves_Management_Team__c=true
		);	
		insert someTeamMemberContact;
		
		Moves_Mgmt_Team_Member__c someTeamMember = new Moves_Mgmt_Team_Member__c(
			Team_Member__c = someTeamMemberContact.id,
			Donor_Contact__c = donor.id,
			Moves_Manager__c = false
		);
		insert someTeamMember;
		
		Moves_Mgmt_Team_Member__c tm = new Moves_Mgmt_Team_Member__c(
			Donor_Contact__c = donor.id,
			Team_Member__c = movesManager.id,
			Moves_Manager__c = true
		);
		
		//insert team member record and we should get contact marked with Moves Manager
		Test.startTest();
		insert tm;
		
		Contact[] updatedCons = [SELECT Moves_Manager__c FROM Contact WHERE id = :donor.id];
		system.assertEquals(movesManager.id,updatedCons[0].Moves_Manager__c);
		
		Test.stopTest();
		
		//now delete the team member record and make sure it gets nulled out on contact
		updatingMovesManagementTeam = false;
		delete tm;
		
		Contact[] updatedCons2 = [SELECT Moves_Manager__c FROM Contact WHERE id = :donor.id];
		system.assertEquals(null,updatedCons2[0].Moves_Manager__c);
		
		
	}
	
	static testmethod void insertConWithManagerThatDoesNotExist() {
		
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
		
		//insert team member record and we should get contact marked with Moves Manager
		Test.startTest();
		insert donor;
		
		Moves_Mgmt_Team_Member__c[] team = [SELECT Team_Member__c, Moves_Manager__c FROM Moves_Mgmt_Team_Member__c WHERE Donor_Contact__c = :donor.id];
		system.assertEquals(movesManager.id,team[0].Team_Member__c);
		system.assertEquals(true,team[0].Moves_Manager__c);		
		
		Test.stopTest();
		
	}
	
	static testmethod void updateConWithManagerThatDoesExist() {
		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson',
			Moves_Manager__c = null
		);
		insert donor;
		
		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			On_Moves_Management_Team__c=true
		);
		insert movesManager;
		
		Moves_Mgmt_Team_Member__c tm = new Moves_Mgmt_Team_Member__c(
			Donor_Contact__c = donor.id,
			Team_Member__c = movesManager.id,
			Moves_Manager__c = false
		);
		insert tm;
		
		//insert team member record and we should get contact marked with Moves Manager
		Test.startTest();
		donor.Moves_Manager__c = movesManager.id;
		update donor;
		
		Moves_Mgmt_Team_Member__c[] team = [SELECT Team_Member__c, Moves_Manager__c FROM Moves_Mgmt_Team_Member__c WHERE Donor_Contact__c = :donor.id];
		system.assertEquals(movesManager.id,team[0].Team_Member__c);
		system.assertEquals(true,team[0].Moves_Manager__c);
	}
	
	static testmethod void existingTeamManagerRecordConUpdate() {
		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson',
			Moves_Manager__c = null
		);
		insert donor;
		
		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			On_Moves_Management_Team__c=true
		);
		insert movesManager;
		
		Moves_Mgmt_Team_Member__c tm = new Moves_Mgmt_Team_Member__c(
			Donor_Contact__c = donor.id,
			Team_Member__c = movesManager.id,
			Moves_Manager__c = true
		);
		insert tm;
		
		//insert team member record and we should get contact marked with Moves Manager
		Test.startTest();
		donor.Moves_Manager__c = movesManager.id;
		updatingMovesManagementTeam = false;
		update donor;
		
		Moves_Mgmt_Team_Member__c[] team = [SELECT Team_Member__c, Moves_Manager__c FROM Moves_Mgmt_Team_Member__c WHERE Donor_Contact__c = :donor.id];
		system.assertEquals(movesManager.id,team[0].Team_Member__c);
		system.assertEquals(true,team[0].Moves_Manager__c);
		
		Test.stopTest();
	}
	
	static testmethod void replaceCurrentTeamManager() {
		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson',
			Moves_Manager__c = null
		);
		insert donor;
		
		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			On_Moves_Management_Team__c=true
		);
		insert movesManager;
		
		Contact someOtherMovesManager = new Contact(
			FirstName = 'Ned',
			LastName = 'Flander',
			On_Moves_Management_Team__c=true
		);
		insert someOtherMovesManager;
		
		Moves_Mgmt_Team_Member__c tm = new Moves_Mgmt_Team_Member__c(
			Donor_Contact__c = donor.id,
			Team_Member__c = someOtherMovesManager.id,
			Moves_Manager__c = true
		);
		insert tm;
		
		//insert team member record and we should get contact marked with Moves Manager
		Test.startTest();
		donor.Moves_Manager__c = movesManager.id;
		updatingMovesManagementTeam = false;
		update donor;
		
		Moves_Mgmt_Team_Member__c[] team = [SELECT Team_Member__c, Moves_Manager__c FROM Moves_Mgmt_Team_Member__c WHERE Donor_Contact__c = :donor.id AND Team_Member__c = :someOtherMovesManager.id];
		system.assertEquals(false,team[0].Moves_Manager__c);
		
		Test.stopTest();
	}
	
	static testmethod void insertMMTeamConRolesOnOppInsert() {
		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson',
			Moves_Manager__c = null
		);
		insert donor;
		
		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			On_Moves_Management_Team__c=true
		);
		insert movesManager;
		
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
	}
	
	static testmethod void updateContactOwnerToMovesManager(){
		User mmUser = [SELECT id FROM user WHERE IsActive=true AND Profile.Name='System Administrator' LIMIT 1];
		system.assert(mmUser.id!=null,'Sys Admin User Account should not be null');
		
		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			User__c = mmUser.id,
			On_Moves_Management_Team__c=true
		);
		insert movesManager;	
		
		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson'
		);
		insert donor;
		
		donor.Moves_Manager__c = movesManager.id;
		update donor;
		
		list<Contact> queryDonor = [SELECT OwnerId FROM Contact WHERE ID=:donor.id];
		system.assertEquals(queryDonor[0].OwnerId,movesManager.User__c,'Assigning a Moves Manager with an associated user account should transfer the Donor\'s owner.');
	}
}