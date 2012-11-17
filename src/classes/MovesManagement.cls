public class MovesManagement {
	
	static boolean updatingMovesManagementTeam = false;
	
	Moves_Mgmt_Settings__c mmSettings;
	set<id> movesRecordTypeIds;
	set<string> movesRecordTypeNames;
	boolean rectypesListEmpty = false;

	
	
	public void SetMovesManagerOnDonor(list<Moves_Mgmt_Team_Member__c> listTeamMemberNew, list<Moves_Mgmt_Team_Member__c> listTeamMemberOld, 
										boolean isInsertOrUpdate, boolean isDelete) {
		
		//only exercise this code if we haven't just fired a trigger to set the moves manager on contact from the team member object
		if (!updatingMovesManagementTeam) {
			
			if (!isDelete) {
				system.debug (LoggingLevel.WARN,'running SetMovesManagerOnDonor on list of TM recs of size: ' + listTeamMemberNew.size());
			}
			
			list<Contact> consToUpdate = new list<Contact>();
			list<Account> accsToUpdate = new list<Account>();
			
			map<id,sobject> consMap = new map<id,sobject>(); 
			map<id,sobject> acctMap = new map<id,sobject>(); 
			
			for (Moves_Mgmt_Team_Member__c tm : (isInsertOrUpdate ? listTeamMemberNew : listTeamMemberOld)) {
				//if this team member is listed as the moves manager, update the contact lookup
				
				if (tm.Moves_Manager__c && tm.Donor_Contact__c != null) {
					Contact c = new Contact(
						id = tm.Donor_Contact__c,
						Moves_Manager__c = isInsertOrUpdate ? tm.Team_Member__c : null //if it's not an insert, it's a delete and we want to null out the Moves Manager field on Contact
						);
					// consToUpdate.add(c);
					consMap.put (c.Id,c);
				} else if (tm.Moves_Manager__c && tm.Donor_Org__c != null) {
					Account a = new Account(
						id = tm.Donor_Org__c,
						Moves_Manager__c = isInsertOrUpdate ? tm.Team_Member__c : null //if it's not an insert, it's a delete and we want to null out the Moves Manager field on Contact
					);
					// accsToUpdate.add(a);
					acctMap.put(a.Id,a);
				}
			}
			
			if (!consMap.isEmpty()) {
				system.debug (LoggingLevel.WARN,'consmap before update: ' + consMap);
				// system.debug (LoggingLevel.WARN,'consmap size: ' + consMap.size());
				//in order to prevent recursion, set this variable so change to moves manager on contact doesn't trigger more code to run
				updatingMovesManagementTeam = true;
				update consMap.values();
				// also sync the team recs, because if we set this due to a checkbox in a team rec, there may be another one that needs to be unchecked
				// except don't do it for a delete, because we don't have that issue
				if (!isDelete) {
					system.debug (LoggingLevel.WARN,'about to sync team recs!');
					syncTeamRecs (consMap,true);
				} 
			}
			if (!acctMap.isEmpty()) {
				updatingMovesManagementTeam = true;
				update acctMap.values();
				if (!isDelete) {
					syncTeamRecs (consMap,false);
				}
			}
		}
	}

	public void updateOwnerToMovesManager(list<sObject> sObjectsWithNewMovesManager) {
		set<id> movesManagers = new set<id>();
		map<Id,Id> ownersToUpdate = new map<Id,Id>();
		
		//compile list of ContactIDs of Moves Managers
		for (sObject c:sObjectsWithNewMovesManager) {
			movesManagers.add((id)c.get('Moves_Manager__c'));
		}
		
		//Make map of ContactId to UserId of Moves Managers with associated users
		for (Contact c:[SELECT Id, User__c FROM Contact WHERE User__c!=null AND Id IN :movesManagers]) {
			ownersToUpdate.put(c.Id,c.User__c);
		}
		
		//Update OwnerID with Moves Manager User
		for (sObject c:sObjectsWithNewMovesManager) {
			if (ownersToUpdate.containsKey((id)c.get('Moves_Manager__c'))) {
				c.put('OwnerId', ownersToUpdate.get((id)c.get('Moves_Manager__c')));
			}
		}
	}
	

	public Id setOppOwnerToDonorMM (SObject oppObj) {

		// sets the owner of a single opp to donor's MM (if any, and valid user)
		
		id mmContact;
		id mmUser;
		id ownerId;
		Opportunity opp = (Opportunity) oppObj;
		// first find contact ID of MM
		if (isMMOppRectype (opp.RecordTypeId)) {
			if (opp.AccountId != null) {
				Account[] accts = [SELECT Id,Moves_Manager__c FROM Account WHERE Id=:opp.AccountID LIMIT 1];
				if (accts != null) mmContact = accts[0].Moves_Manager__c;
			} else if (opp.GWBase__ContactId__c != null){
				Contact[] cons = [SELECT Id,Moves_Manager__c FROM Contact WHERE Id=:opp.GWBase__ContactId__c LIMIT 1];
				if (cons != null) mmContact = cons[0].Moves_Manager__c; 
			}
		}
		
		// then look up user id
		if (mmContact != null) {
			Contact[] mmCon = [SELECT Id,User__c FROM Contact WHERE Id=:mmContact LIMIT 1];
			if (mmCon!=null && mmCon[0].User__c!=null) {
				Id userId = mmCon[0].User__c;
				List<User> usr = [SELECT Id,IsActive FROM User WHERE Id=:userId LIMIT 1];
				// if (usr!=null) opp.OwnerId = usr[0].Id;
				if (usr!=null) ownerId = usr[0].Id;
			}
			
		}

		// return opp;
		return ownerId;
	}
	
	public void SetMovesManagerOnTeamMember(map<id,sObject> conMap, map<id,sObject> oldMap, boolean isUpdate) {
		
		//only exercise this code if we haven't just fired a trigger to set the moves manager on contact from the team member object
		if (!updatingMovesManagementTeam) {
			
			//boolean to differentiate Account and Contact sObjects
			boolean sObjectIsContact = ((string)conMap.values()[0].get('id')).startswith('003');

			// map of contact id to all team members related to that contact
			// map<id,set<Moves_Mgmt_Team_Member__c>> conIdToTeamMap = new map<id,set<Moves_Mgmt_Team_Member__c>>();
			map <id,sObject> recMapToProcess = new map <id,sObject>();
			
			// first we need to find all of the related team members for each contact in the trigger set, so we know whether to update an 
			// existing team member record or create a new one
			for (sObject c : conMap.values()) {
				//only create or update team member records if Moves Manager lookup is populated or was just blanked out with an update
				if ((!isUpdate && c.get('Moves_Manager__c') != null) || (isUpdate && c.get('Moves_Manager__c') != oldMap.get((id)c.get('id')).get('Moves_Manager__c'))) {
					// conIdToTeamMap.put((id)c.get('id'),new set<Moves_Mgmt_Team_Member__c>());
					recMapToProcess.put ((id)c.get('id'),c);
				}
			}
			
			if (!recMapToProcess.isEmpty()) {
				syncTeamRecs (recMapToProcess,sObjectIsContact);
			}

		 }
		
	}

	
	private void syncTeamRecs (map<id,sObject> recMap, boolean sObjectIsContact) {

			//now go find all of the existing team member records for these contacts and build out our map
			if (!recMap.isEmpty()) {
				
				map<id,set<Moves_Mgmt_Team_Member__c>> recIdToTeamMap = new map<id,set<Moves_Mgmt_Team_Member__c>>();
				list<Moves_Mgmt_Team_Member__c> teamMembersToCreate = new list<Moves_Mgmt_Team_Member__c>();
				list<Moves_Mgmt_Team_Member__c> teamMembersToUpdate = new list<Moves_Mgmt_Team_Member__c>();
				
				// first fill the team map with empty sets of TM recs
				for (id recId : recMap.keyset() ) {
					recIdToTeamMap.put(recId , new set<Moves_Mgmt_Team_Member__c>());
				}
				
				//if the sObjects are contacts, use the contact lookup on MMTM, otherwise use the Account lookup
				if (sObjectIsContact) {
					for (Moves_Mgmt_Team_Member__c tm : [SELECT id, Moves_Manager__c, Team_Member__c, Donor_Contact__c FROM Moves_Mgmt_Team_Member__c
															WHERE Donor_Contact__c IN :recIdToTeamMap.keyset() ]) {
						
						recIdToTeamMap.get(tm.Donor_Contact__c).add(tm);
					}
				} else {
					for (Moves_Mgmt_Team_Member__c tm : [SELECT id, Moves_Manager__c, Team_Member__c, Donor_Org__c FROM Moves_Mgmt_Team_Member__c
															WHERE Donor_Org__c IN :recIdToTeamMap.keyset() ]) {
						recIdToTeamMap.get(tm.Donor_Org__c).add(tm);
					}					
				}
				
				system.debug (LoggingLevel.WARN,'recIdToTeamMap after queries: ' + recIdToTeamMap);
				
				// now loop back through the map and update or create team member records as needed to reflect
				// the moves manager indicated on the contact record
				for (id cid : recIdToTeamMap.keyset()) {
					// if we don't have any existing team member records, we need to create one
					boolean createTeamMemberRecord = true;
					for (Moves_Mgmt_Team_Member__c tm : recIdToTeamMap.get(cid)) {
						if (tm.Team_Member__c == recMap.get(cid).get('Moves_Manager__c') && tm.Moves_Manager__c) {
							//we already have the correct team manager
							createTeamMemberRecord = false;
							// bugfix: don't want to break here, order is unreliable, we may still need to chg other recs
							// break;
						} else if (tm.Team_Member__c != recMap.get(cid).get('Moves_Manager__c') && tm.Moves_Manager__c) {
							//there is a team member record with another Moves Manager marked, and we need to unmark and update that record	
							tm.Moves_Manager__c = false;
							teamMembersToUpdate.add(tm);
						} else if (tm.Team_Member__c == recMap.get(cid).get('Moves_Manager__c') && !tm.Moves_Manager__c) {
							//there is a team member record for this Moves Manager, but that record is marked as the Moves Manager yet, so mark it
							tm.Moves_Manager__c = true;
							teamMembersToUpdate.add(tm);
							createTeamMemberRecord = false;
						}
					}
					
					if (createTeamMemberRecord) {
						Moves_Mgmt_Team_Member__c tm = new Moves_Mgmt_Team_Member__c(
							Team_Member__c = (id)recMap.get(cid).get('Moves_Manager__c'),
							Moves_Manager__c = true
						);
						if (sObjectIsContact) tm.Donor_Contact__c = cid;
						else tm.Donor_Org__c = cid;
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
	
	public void addTeamToOppContactRoles(list<Opportunity> opps) {
		
		// automatically create conroles for the entire MM team, for MM-type opps only
		
		map<id,set<id>> idToTeamMap = new map<id,set<id>>();
		map<id,id> idToMovesManagerMap = new map<id,id>();
		list<OpportunityContactRole> ocrToCreate = new list<OpportunityContactRole>();
		
		for (Opportunity o : opps) {
			if (isMMOppRectype(o.RecordTypeId)) {
				if (o.get('GWBase__ContactId__c') != null) {
					idToTeamMap.put((id)o.get('GWBase__ContactId__c'),new set<id>());
				} else if (o.AccountId != null) {
					idToTeamMap.put(o.AccountId, new set<id>());
				}
			}
		}
		
		//query for all of the team members for each major donor and build out the map
		for (Moves_Mgmt_Team_Member__c tm : [SELECT id, Moves_Manager__c, Team_Member__c, Donor_Contact__c, Donor_Org__c FROM Moves_Mgmt_Team_Member__c
													WHERE Donor_Contact__c IN :idToTeamMap.keyset() OR Donor_Org__c IN :idToTeamMap.keyset()]) {
			id moved = tm.Donor_Org__c!=null?tm.Donor_Org__c:tm.Donor_Contact__c;
			
			if (!tm.Moves_Manager__c) {
				idToTeamMap.get(moved).add(tm.Team_Member__c);
			} else {
				idToMovesManagerMap.put(moved,tm.Team_Member__c);	
			}
		}
		
		system.debug (LoggingLevel.WARN,'idToTeamMap: ' + idToTeamMap);
		system.debug (LoggingLevel.WARN,'idToMovesManagerMap: ' + idToMovesManagerMap);
		
		//loop through opps and build contact roles
		for (Opportunity o : opps) {
			id moved = o.AccountId!=null?o.AccountId:o.GWBase__ContactId__c;
			if (idToTeamMap.containsKey(moved)) {
				for (id i : idToTeamMap.get(moved)) {
					OpportunityContactRole ocr = new OpportunityContactRole(
						OpportunityId = o.id,
						ContactId = i,
						Role = 'Moves Management Team Member'
					);
					ocrToCreate.add(ocr);
				}
			}
			
			if (idToMovesManagerMap.containsKey(moved)) {
				OpportunityContactRole ocr = new OpportunityContactRole(
					OpportunityId = o.id,
					ContactId = idToMovesManagerMap.get(moved),
					Role = 'Moves Manager'
					//isPrimary = true??
				);
				ocrToCreate.add(ocr);					
			}
			
		}
		system.debug (LoggingLevel.WARN,'ocrToCreate: ' + ocrToCreate);
		if (!ocrToCreate.isEmpty()) {
			insert ocrToCreate;
		}
	}
	
	public void movesOppRollup(set<id> oppsToRollup) {
		//use oppToRollup instead of oppsThatExist.
		map<id,Task> closedTaskMap = new map<id,Task>();
		map<id,Task> openTaskMap = new map<id,Task>();
		set<id> oppsThatExist = new set<id>();
		list<Opportunity> oppsToUpdate = new list<Opportunity>();
		
		//loop through Closed tasks for our Opportunity records to roll up
		for (Task t:[SELECT Id, WhatId, IsClosed, Subject FROM Task WHERE ActivityDate!=NULL AND IsClosed=true AND WhatId IN :oppsToRollup ORDER BY ActivityDate DESC]) {
			//take the most recently closed task by Activity date, add it to the closed task map
			if (!closedTaskMap.containsKey(t.WhatId)) {
				closedTaskMap.put(t.whatId,t);
				oppsThatExist.add(t.whatId);
			}
		}
		
		//loop through Open tasks for our Opportunity records to roll up
		for (Task t:[SELECT Id, WhatId, IsClosed, Subject FROM Task WHERE ActivityDate!=NULL AND IsClosed=false AND WhatId IN :oppsToRollup ORDER BY ActivityDate]) {
			//take the first open task by Activity date, add it to the open task map
			if (!openTaskMap.containsKey(t.WhatId)) {
				openTaskMap.put(t.whatId,t);
				oppsThatExist.add(t.whatId);
			}
		}
		
		for (id oppId:oppsThatExist) {
			Opportunity o = new Opportunity(
				id=oppId,
				Last_Move_Id__c=null,
				Last_Move_Subject__c=null,
				Next_Move_Id__c=null,
				Next_Move_Subject__c=null
			);
			if (openTaskMap.containsKey(oppId)) {
				o.Next_Move_Id__c = (string)openTaskMap.get(oppId).id;
				o.Next_Move_Subject__c = openTaskMap.get(oppId).Subject;
			}
			if (closedTaskMap.containsKey(oppId)) {
				o.Last_Move_Id__c = (string)closedTaskMap.get(oppId).id;
				o.Last_Move_Subject__c = closedTaskMap.get(oppId).Subject;
			}
			oppsToUpdate.add(o);
		}
		
		if (oppsToUpdate.size() > 0) {
			update oppsToUpdate;
		}
	}
	
	//stamps Opportunity Stage onto a Task's Moves Management Stage when the task is marked as closed, if the stage wasn't set manually.
	public void stampTaskOppStage(map<id,Task> oppsToStamp){
		for (Opportunity o:[SELECT id, StageName FROM Opportunity WHERE id in :oppsToStamp.keyset()]) {
			oppsToStamp.get(o.id).Moves_Management_Stage__c = o.StageName;
		}
	}
	
	
	public void getRectypeSettings () {
		// grab settings if we haven't already
		if (mmSettings == null) {
			mmSettings = Moves_Mgmt_Settings__c.getInstance();
			system.debug(LoggingLevel.WARN,'mmsettings in ismmopprectype' + mmsettings);

			if (mmSettings.Opportunity_Record_Types__c == null) {
				rectypesListEmpty = true;
			}
		}

		// build our list of rectype id's if we haven't already
		if (movesRecordTypeIds == null && !rectypesListEmpty) {
			movesRecordTypeNames = new set<string>();
			for (string s:mmsettings.Opportunity_Record_Types__c.split(';')) {
				movesRecordTypeNames.add(s);
			}
			if (movesRecordTypeNames.size() > 0) {
				movesRecordTypeIds = GWBase.GW_RecTypes.GetRecordTypeIdSet('Opportunity',movesRecordTypeNames);
			}
		}
	}
	
	
	public boolean isMMOppRectype (id oppRectypeID) {
		// determine if the opp rectypeid passed is a moves mgmt opp, according to settings
		getRectypeSettings(); 
		if (movesRecordTypeIds != null) {
			if (movesRecordTypeIds.contains(oppRectypeID)) {
				return true;
			} else {
				return false;
			}
		} else {
			return false;			
		}
	}

	/****************************************
	*				TESTS					*
	****************************************/

	public static string oppRectypeIdForTests;
	public static void setSettingsForTests () {
		// use Major Gift as the default opp rectype if we actually have a rectype with that name
		// otherwise, use a rectype at random that we do have
		Moves_Mgmt_Settings__c settings = Moves_Mgmt_Settings__c.getOrgDefaults();
		system.debug (Logginglevel.WARN, 'settings before update: ' + settings);
		settings.Opportunity_Record_Types__c = defaultOppRectype('Major Gift');
		upsert settings;
		Moves_Mgmt_Settings__c[] settingsRecs = [SELECT Opportunity_Record_Types__c, SystemModstamp, SetupOwnerId, Name, LastModifiedDate, LastModifiedById, IsDeleted, Id, CreatedDate, CreatedById From Moves_Mgmt_Settings__c];
		system.debug (Logginglevel.WARN, 'settings after update: ' + settingsRecs);
		Moves_Mgmt_Settings__c setting2 = Moves_Mgmt_Settings__c.getOrgDefaults();
		system.debug (Logginglevel.WARN, 'settings refetched via method: ' + setting2);
	}

	public static string defaultOppRectype (string tryFirst) {
		// first try to find the rectype given in the param
		// if not found, just take the first opp rectype we do find, at random
		string rectypeName;
		id tryID = GWBase.GW_RecTypes.GetRecordTypeId('Opportunity', tryFirst);
		if (tryID == null) {
			Map<String, Id> rectypeMap = GWBase.GW_RecTypes.GetRecordTypeIdMap('Opportunity');
			// can't take first element of a set, so cast to a list
			list<string> allRectypeNames = new list<string>();
			allRectypeNames.addAll(rectypeMap.keyset());
			rectypeName = allRectypeNames[0];
			oppRectypeIdForTests = rectypeMap.get(rectypeName);
		} else {
			rectypeName = tryFirst;
			oppRectypeIdForTests = tryID;
		}
		return rectypeName;
	}

	
	static testmethod void testMovesRollups() {
		
		setSettingsForTests();
		
		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson',
			Moves_Manager__c = null
		);
		insert donor;
		
		Opportunity opp = new Opportunity(
			RecordTypeID = oppRectypeIdForTests,
			Amount = 888888,
			CloseDate = system.today().addDays(8),
			StageName = GWBase.ONEN_Constants.OPP_DEFAULT_STAGE,
			GWBase__CR_Contact_Id__c = donor.id,
			GWBase__ContactId__c = donor.id
		);
		insert opp;
		
		list<Task> taskList = new list<Task>();
		for (integer i=0; i<5; i++) {
			Task t = new Task(
				WhoId = donor.id,
				WhatId = opp.id,
				Subject = 'subject'+i,
				ActivityDate = system.today().addDays(-i),
				Status = 'Completed'
			);
			taskList.add(t);
		}
		for (integer i=5; i<10; i++) {
			Task t = new Task(
				WhoId = donor.id,
				WhatId = opp.id,
				Subject = 'subject'+i,
				ActivityDate = system.today().addDays(i),
				Status = 'Not Started'
			);
			taskList.add(t);			
		}
		insert tasklist;
		
		list<Opportunity> queryOpp = [SELECT Id, Next_Move_ID__c, Last_Move_Id__c, Next_Move_Subject__c, Last_Move_Subject__c FROM Opportunity WHERE Id=:opp.id];
		system.debug('Results!'+queryOpp);
		system.assertEquals('subject5',queryOpp[0].Next_Move_Subject__c);
		system.assert(queryOpp[0].Next_Move_Id__c == taskList[5].Id);
		system.assertEquals('subject0',queryOpp[0].Last_Move_Subject__c);
		system.assert(queryOpp[0].Last_Move_ID__c == taskList[0].Id);
	}
	
	static testmethod void insertTeamMemberManager() {
		
		setSettingsForTests();
		
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
		
		setSettingsForTests();
		
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




	static testmethod void testBulkMgrFieldFromTeamMbr() {
		Contact[] donorCons =  GWBase.ONEN_UnitTestData.CreateMultipleTestContacts (25);
		insert donorCons;
		
		Contact[] teamMbrCons = GWBase.ONEN_UnitTestData.CreateMultipleTestContacts (2);
		for (Contact con: teamMbrCons) {
			con.On_Moves_Management_Team__c = true;
		}
		insert teamMbrCons;
		
		Moves_Mgmt_Team_Member__c[] teamMbrs = new Moves_Mgmt_Team_Member__c[0];
		for (Contact con:donorCons) {
			id donorId = con.Id;
			// integer teamMbrNbr = (i/40.0).round(RoundingMode.FLOOR).intvalue();
			// id teamMbrId = teamMbrCons[teamMbrNbr].Id;
			Moves_Mgmt_Team_Member__c tm = new Moves_Mgmt_Team_Member__c(
				Donor_Contact__c = donorId,
				Team_Member__c = teamMbrCons[0].Id,
				Moves_Manager__c = true
			);
			teamMbrs.add(tm);		
			Moves_Mgmt_Team_Member__c tm2 = new Moves_Mgmt_Team_Member__c(
				Donor_Contact__c = donorId,
				Team_Member__c = teamMbrCons[1].Id,
				Moves_Manager__c = false
			);
			teamMbrs.add(tm2);		
		}
		updatingMovesManagementTeam = false;
		
		test.startTest();
		system.debug (LoggingLevel.WARN,'about to insert TM recs..');
		insert teamMbrs;
		system.debug (LoggingLevel.WARN,'done inserting TM recs..');
		test.stopTest();
		
		// now make sure that all contacts have a move mgr in the field
		Contact[] donorCons2 = [SELECT Id,Moves_Manager__c FROM Contact WHERE id IN :donorCons];
		// system.assertEquals(200,donorCons2.size());
		for (Contact con : donorCons2) {
			system.assert(con.Moves_Manager__c != null);
		}
		
	}

	
	static testmethod void existingTeamManagerRecordConUpdate() {
		
		setSettingsForTests();
		
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
		
		setSettingsForTests();

		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			On_Moves_Management_Team__c=true
		);
		insert movesManager;
				
		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson',
			Moves_Manager__c = movesManager.Id
		);
		insert donor;
		
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
		updatingMovesManagementTeam = false;
		system.debug (LoggingLevel.WARN,'changing MM via team rec..' );
		insert tm;
		
		// at this point contact should have MM field updated, and initial mgr should have team rec but w/ mgr field unchecked
		donor = [SELECT Id,Moves_Manager__c FROM Contact WHERE Id = :donor.Id LIMIT 1];
		system.assertEquals (someOtherMovesManager.Id,donor.Moves_Manager__c);
		
		Moves_Mgmt_Team_Member__c[] FirstMMTeam = [SELECT Team_Member__c, Moves_Manager__c FROM Moves_Mgmt_Team_Member__c 
													WHERE Donor_Contact__c = :donor.id AND Team_Member__c = :movesManager.id];
		system.assertEquals(1,FirstMMTeam.size());											
		system.assertEquals(false,FirstMMTeam[0].Moves_Manager__c);
		
		
		// now switch it back on the contact to the original mgr
		Test.startTest();
		donor.Moves_Manager__c = movesManager.id;
		updatingMovesManagementTeam = false;
		update donor;
		Test.stopTest();
		
		Moves_Mgmt_Team_Member__c[] team = [SELECT Team_Member__c, Moves_Manager__c FROM Moves_Mgmt_Team_Member__c WHERE Donor_Contact__c = :donor.id AND Team_Member__c = :someOtherMovesManager.id];
		system.assertEquals(false,team[0].Moves_Manager__c);
		
		
	}
	
	static testmethod void updateContactOwnerToMovesManager(){
		
		setSettingsForTests();
		
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
	
	static testmethod void updateAccountOwnerToMovesManager(){
		User mmUser = [SELECT id FROM user WHERE IsActive=true AND Profile.Name='System Administrator' LIMIT 1];
		system.assert(mmUser.id!=null,'Sys Admin User Account should not be null');
		
		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			User__c = mmUser.id,
			On_Moves_Management_Team__c=true
		);
		insert movesManager;	
		
		Account donor = new Account(
			Name = 'Springfield Nuclear Power Plant'
		);
		insert donor;
		
		donor.Moves_Manager__c = movesManager.id;
		updatingMovesManagementTeam = false;
		update donor;
		
		list<Account> queryDonor = [SELECT OwnerId FROM Account WHERE ID=:donor.id];
		system.assertEquals(queryDonor[0].OwnerId,movesManager.User__c,'Assigning a Moves Manager with an associated user account should transfer the Donor\'s owner.');
		
		// now change it to a different value, for a new MM (non-user)
		Contact newMM = new Contact (
			FirstName = 'Dr',
			LastName = 'Strangelove',
			On_Moves_Management_Team__c=true
		);
		insert newMM;
		
		donor.Moves_Manager__c = newMM.Id;
		updatingMovesManagementTeam = false;
		update donor;

		// MM should change but owner should stay the same
		queryDonor = [SELECT OwnerId,Moves_Manager__c FROM Account WHERE ID=:donor.id];
		system.assertEquals(queryDonor[0].OwnerId,movesManager.User__c,'Owner shouldnt change if new MM is not a user.');
		system.assertEquals(newMM.Id,queryDonor[0].Moves_Manager__c,'Moves mgr field failed to be updated');
		
		// also make sure that the team records for both members are correct
		Moves_Mgmt_Team_Member__c[] team = [SELECT Team_Member__c, Moves_Manager__c FROM Moves_Mgmt_Team_Member__c WHERE Donor_Org__c = :donor.id];
		system.debug (LoggingLevel.WARN,'team after MM update:' + team);
		system.assertEquals (2,team.size());
		for (Moves_Mgmt_Team_Member__c TM : team) {
			if (TM.Team_Member__c == newMM.Id) {
				system.assert(TM.Moves_Manager__c == true,'new MM did not get MM checkbox checked in team rec');
			}
			if (TM.Team_Member__c == movesManager.Id) {
				system.assert(TM.Moves_Manager__c == false,'old MM did not get MM checkbox unchecked in team rec');
			}
		} 
		
		
		
	}
	
	static testmethod void testTaskOppStageStamp() {
		
		setSettingsForTests();
		
		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson',
			Moves_Manager__c = null
		);
		insert donor;
		
		Opportunity opp = new Opportunity(
			RecordTypeID = oppRectypeIdForTests,
			Amount = 888888,
			CloseDate = system.today().addDays(8),
			StageName = 'Cultivating',
			GWBase__CR_Contact_Id__c = donor.id,
			GWBase__ContactId__c = donor.id
		);
		insert opp;
		
		Task t = new Task(
			WhoId = donor.id,
			WhatId = opp.id,
			Subject = 'subject',
			ActivityDate = system.today()
		);
		insert t;
		
		Task querytask = [SELECT id, Moves_Management_Stage__c FROM Task WHERE Id=:t.id];
		system.assertEquals(querytask.Moves_Management_Stage__c,null,'Task should not be stamped with Opp Stage until it is closed');
		
		//set task to closed status
		TaskStatus closedtaskstatus = [SELECT MasterLabel, IsClosed from TaskStatus WHERE IsClosed=true LIMIT 1];
		t.Status = closedtaskstatus.MasterLabel;
		
		update t;
		
		querytask = [SELECT id, Moves_Management_Stage__c FROM Task WHERE Id=:t.id];
		system.assertEquals(querytask.Moves_Management_Stage__c, 'Cultivating');
		
		
		// also create a task w/ no whatID, to make sure that doesn't throw anything off
		Task t2 = new Task (
			WhoId = donor.id,
			Subject = 'foo',
			ActivityDate = system.today()
		);
		insert t2;
		// and complete it 
		t2.Status = closedtaskstatus.MasterLabel;
		update t2;
		// then add a whatid (this was throwing an err)
		t2.WhatId = opp.id;
		update t2;
	}
	

	static testmethod void testTeamOppConRoles() {
		
		setSettingsForTests();

		User mmUser = [SELECT id FROM user WHERE IsActive=true AND Profile.Name='System Administrator' LIMIT 1];
		system.assert(mmUser.id!=null,'Sys Admin User Account should not be null');

		Contact movesManager = new Contact(
			FirstName = 'Mr.',
			LastName = 'Burns',
			On_Moves_Management_Team__c=true,
			User__c = mmUser.Id
		);
		insert movesManager;

		Contact donor = new Contact(
			FirstName = 'Homer',
			LastName = 'Simpson',
			Moves_Manager__c = movesManager.id
		);
		insert donor;

		// reset recursion flag so trigger on acct will fire 
		updatingMovesManagementTeam=false;

		Account donorAcct = new Account (
			Name = 'foo corp',
			Moves_Manager__c = movesManager.id
		);
		insert donorAcct;
		
		Moves_Mgmt_Team_Member__c[] acctTM = [SELECT Id,Donor_Org__c,Team_Member__c,Moves_Manager__c FROM Moves_Mgmt_Team_Member__c WHERE Donor_Org__c = :donorAcct.Id];
		system.assertEquals (1,acctTM.size());
		system.assertEquals (movesManager.id,acctTM[0].Team_Member__c);
		system.assertEquals (true,acctTM[0].Moves_Manager__c);
		
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
		Moves_Mgmt_Team_Member__c tm2 = new Moves_Mgmt_Team_Member__c(
			Donor_Org__c = donorAcct.id,
			Team_Member__c = someOtherTeamMember.id,
			Moves_Manager__c = false
		);
		insert tm2;
		
		test.starttest();
		system.debug (LoggingLevel.WARN,'inserting opp for contact' );
		Opportunity opp = new Opportunity(
			RecordTypeID = oppRectypeIdForTests,
			Amount = 888888,
			CloseDate = system.today().addDays(8),
			StageName = GWBase.ONEN_Constants.OPP_DEFAULT_STAGE,
			GWBase__CR_Contact_Id__c = donor.id,
			GWBase__CR_Contact_Role__c = 'Major Donor',
			GWBase__ContactId__c = donor.id
		);
		insert opp;
		
		list<OpportunityContactRole> queryOCR = [SELECT Id, Contact.Name, Role, IsPrimary, Opportunity.OwnerId FROM OpportunityContactRole WHERE OpportunityId=:opp.id];
		system.assertEquals(3,queryOCR.size(),'OpportunityContactRoles should be created for all Moves Management Team Members');
		
		// should also have MM as the owner
		system.assertEquals(mmUser.Id,queryOCR[0].Opportunity.OwnerId,'Opp owner did not get set to moves manager of the donor');
		
		// now try the account
		system.debug (LoggingLevel.WARN,'inserting opp for acct' );
		Opportunity oppA = new Opportunity(
			RecordTypeID = oppRectypeIdForTests,
			Amount = 888888,
			CloseDate = system.today().addDays(8),
			StageName = GWBase.ONEN_Constants.OPP_DEFAULT_STAGE,
			AccountId = donorAcct.Id
		);
		insert oppA;

		list<OpportunityContactRole> queryOCRA = [SELECT Id, Contact.Name, Role, IsPrimary FROM OpportunityContactRole WHERE OpportunityId=:oppA.id];
		// only 2 here b/c no donor conrole
		system.assertEquals(2,queryOCRA.size(),'OpportunityContactRoles should be created for all Moves Management Team Members');
		
		
		// now remove the setting, and try it again.  This time shouldn't create the OCR's
		Moves_Mgmt_Settings__c settings = Moves_Mgmt_Settings__c.getOrgDefaults();
		system.debug (Logginglevel.WARN, 'settings before update: ' + settings);
		settings.Opportunity_Record_Types__c = '';
		upsert settings;
		
		/*
		// gotta reset our static vars too
		mmSettings = null;
		movesRecordTypeIds = null;
		*/
		
		system.debug (LoggingLevel.WARN,'inserting opp for contact w/ wrong rectype' );
		Opportunity opp2 = new Opportunity(
			RecordTypeID = oppRectypeIdForTests,
			Amount = 444,
			CloseDate = system.today().addDays(8),
			StageName = GWBase.ONEN_Constants.OPP_DEFAULT_STAGE,
			GWBase__CR_Contact_Id__c = donor.id,
			GWBase__CR_Contact_Role__c = 'Major Donor',
			GWBase__ContactId__c = donor.id
		);
		insert opp2;
		test.stoptest();

		list<OpportunityContactRole> queryOCR2 = [SELECT Id, Contact.Name, Role, IsPrimary FROM OpportunityContactRole WHERE OpportunityId=:opp2.id];
		system.assertEquals(1,queryOCR2.size(),'OCRs should be created for Moves Management Team since wrong rectype');
		

	}

}