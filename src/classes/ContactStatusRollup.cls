global class ContactStatusRollup extends DonorStatusRollup {

	global ContactStatusRollup (id parentRecId) {
		super (parentRecId);
	}
	
	global ContactStatusRollup (string SOQL) {
		super (SOQL);
	}

	global ContactStatusRollup (integer batchSz) {
		super (batchSz);
	}
	
	global ContactStatusRollup (set<id> parentRecIds) {
		super (parentRecIds);
	}
	
	global override string setParentObjName() {
		return 'Contact';
	}

	global virtual override list<RollupSpec> setRollupSpecs() {
		list<RollupSpec> mySpecs = new list<RollupSpec>();
		
		/*
		// getOrgDefaults was returning null here for tests even though we inserted a record at the start of the test
		// likely siloing bug, so use the static vars in the main class instead
		Moves_Management_Settings__c mmsettings = Moves_Management_Settings__c.getOrgDefaults();
		system.debug(LoggingLevel.WARN,mmsettings);
		*/
		
		set<string> movesRecordTypes = MovesManagement.movesRecordTypeNames;
		/*
		for (string s:mmsettings.Opportunity_Record_Types__c.split(';')) {
			movesRecordTypes.add(s);
		}
		*/
		
		// create a rollup spec, specifying the object that has the details to be rolled up, 
		// and the field in that table that relates it to the parent object
		RollupSpec rs = new RollupSpec('Opportunity', 'GWBase__ContactId__c');
		
		// where clause elements
		//rs.filter = '';
		
		// this maps aggregate functions to the rollup field names that summarize them
		rs.aggregateToParentFieldnameMap = new map<string, string> {
			//'MAX(Rollup_Fieldset__c)' => 'RollupRecentPresentation__c'
		};

		// these let you pass in sets of filter strings to include or leave out		
		rs.setFiltersIn = new map<string, set<string>> {
			'recordtype.name' => movesRecordTypes
		};
		
		rs.specialRollupAggregates = new set<string>{'MAX(CloseDate)'};
		rs.additionalQueryFields = new set<string>{'Moves_Management_Status__c'};
		rs.subgroupExpression = 'StageName';

		mySpecs.add(rs);
		
		return mySpecs; 
	}	
	
	static testmethod void testNew () {
		/*
		Moves_Management_Settings__c mmsettings = new Moves_Management_Settings__c(
			Opportunity_Record_Types__c = 'Major Gift'
		);
		insert mmsettings;
		*/
		MovesManagement.setSettingsForTests();

		contact con = new contact(
			lastname='testcontact',
			Moves_Management_Status__c = 'Prospect'
		);
		
		insert con;
		
		opportunity opp = new Opportunity(
			Name = 'Huge Gift',
			RecordTypeID = MovesManagement.oppRectypeIdForTests,
			Amount = 88888888,
			GWBase__ContactId__c = con.id,
			StageName = 'Prospecting',
			CloseDate = system.today()
		);
		insert opp;
		
		
		Contact querycon = [SELECT Moves_Management_Status__c FROM Contact WHERE Id = :con.id];
		system.assertEquals(querycon.Moves_Management_Status__c, 'Prospecting');
	}
	
	static testmethod void testDropped () {
		/*
		Moves_Management_Settings__c mmsettings = new Moves_Management_Settings__c(
			Opportunity_Record_Types__c = 'Major Gift'
		);
		insert mmsettings;
		*/
		MovesManagement.setSettingsForTests();

		contact con = new contact(
			lastname='testcontact',
			Moves_Management_Status__c = 'Dropped'
		);
		
		insert con;
		
		opportunity opp = new Opportunity(
			Name = 'Huge Gift',
			RecordTypeID = MovesManagement.oppRectypeIdForTests,
			Amount = 88888888,
			GWBase__ContactId__c = con.id,
			StageName = 'Prospecting',
			CloseDate = system.today()
		);
		insert opp;
		
		Contact querycon = [SELECT Moves_Management_Status__c FROM Contact WHERE Id = :con.id];
		system.assertEquals('Dropped', querycon.Moves_Management_Status__c);
	}
}