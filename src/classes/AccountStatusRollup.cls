global with sharing class AccountStatusRollup extends DonorStatusRollup {

	global AccountStatusRollup (id parentRecId) {
		super (parentRecId);
	}
	
	global AccountStatusRollup (string SOQL) {
		super (SOQL);
	}

	global AccountStatusRollup (integer batchSz) {
		super (batchSz);
	}
	
	global AccountStatusRollup (set<id> parentRecIds) {
		super (parentRecIds);
	}
	
	global override string setParentObjName() {
		return 'Account';
	}

	global virtual override list<RollupSpec> setRollupSpecs() {
		list<RollupSpec> mySpecs = new list<RollupSpec>();
		
		Moves_Management_Settings__c mmsettings = Moves_Management_Settings__c.getInstance();
		
		set<string> movesRecordTypes = new set<string>();
		for (string s:mmsettings.Opportunity_Record_Types__c.split(';')) {
			movesRecordTypes.add(s);
		}
		
		// create a rollup spec, specifying the object that has the details to be rolled up, 
		// and the field in that table that relates it to the parent object
		RollupSpec rs = new RollupSpec('Opportunity', 'AccountId');
		
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
		Moves_Management_Settings__c mmsettings = new Moves_Management_Settings__c(
			Opportunity_Record_Types__c = 'Gift'
		);
		insert mmsettings;

		Account acc = new Account(
			Name='Test co.',
			Moves_Management_Status__c = 'Prospect'
		);
		
		insert acc;
		
		opportunity opp = new Opportunity(
			Name = 'Huge Gift',
			RecordTypeID = GWBase.GW_RecTypes.GetRecordTypeId('Opportunity','Gift'),
			Amount = 88888888,
			AccountId = acc.id,
			StageName = 'Prospecting',
			CloseDate = system.today()
		);
		insert opp;
		
		Test.StartTest();
		AccountStatusRollup rollup = new AccountStatusRollup(acc.id);
		rollup.runRollups();
		Test.StopTest();
		
		Account queryacc = [SELECT Moves_Management_Status__c FROM Account WHERE Id = :acc.id];
		system.assertEquals(queryacc.Moves_Management_Status__c, 'Prospecting');
	}
	
	static testmethod void testDropped () {
		Moves_Management_Settings__c mmsettings = new Moves_Management_Settings__c(
			Opportunity_Record_Types__c = 'Gift'
		);
		insert mmsettings;

		Account acc = new Account(
			Name='Test co.',
			Moves_Management_Status__c = 'Dropped'
		);
		
		insert acc;
		
		opportunity opp = new Opportunity(
			Name = 'Huge Gift',
			RecordTypeID = GWBase.GW_RecTypes.GetRecordTypeId('Opportunity','Gift'),
			Amount = 88888888,
			AccountId = acc.id,
			StageName = 'Prospecting',
			CloseDate = system.today()
		);
		insert opp;
		
		Test.StartTest();
		AccountStatusRollup rollup = new AccountStatusRollup(acc.id);
		rollup.runRollups();
		Test.StopTest();
		
		Account queryacc = [SELECT Moves_Management_Status__c FROM Account WHERE Id = :acc.id];
		system.assertEquals('Dropped', queryacc.Moves_Management_Status__c);
	}
}