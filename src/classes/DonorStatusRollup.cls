global abstract class DonorStatusRollup extends GW_ABS_Rollup  {

	map<id,string> oppStageMap = new map<id,string>();
	map<id,date> oppDateMap = new map<id,date>();

	global DonorStatusRollup (id parentRecId) {
		super (parentRecId);
	}
	
	global DonorStatusRollup (string SOQL) {
		super (SOQL);
	}

	global DonorStatusRollup (integer batchSz) {
		super (batchSz);
	}
	
	global DonorStatusRollup (set<id> parentRecIds) {
		super (parentRecIds);
	}
	
	public virtual override void customResultRowProcessing(SObject rollupRow,RollupSpec spec,SObject parentRec) {
		system.debug(LoggingLevel.WARN,'lookhere!' + rollupRow);
		if (rollupRow.get('AggregateField0')!=null) {
			id parentId;
			
			if (parentObjName=='Contact') parentId = (id)rollupRow.get('GWBase__ContactId__c');
			else parentId = (id)rollupRow.get('AccountId');
			
			//system.debug('!@# ' + rollupRow.get('AccountId'));
			Date closeDate = (date)rollupRow.get('AggregateField1');
			
			if (oppDateMap.containsKey(parentId)) {
				if (oppDateMap.get(parentId) < closeDate) {
					oppDateMap.put(parentId, closeDate);
					oppStageMap.put(parentId, (string)rollupRow.get('AggregateField0'));
				}
			} else {
				oppDateMap.put(parentId, closeDate);
				oppStageMap.put(parentId, (string)rollupRow.get('AggregateField0'));
			}
		}
	}

	public virtual override void customFinalProcessing (map<id, sobject> objMap) {
		map<string,Boolean> oppStages = new map<string,Boolean>(); 
		for (OpportunityStage os : [select masterLabel, isClosed FROM OpportunityStage]) {
			oppStages.put(os.masterLabel, os.isClosed);
		} 
		for (sObject s : objMap.values()) {
			if (s.get('Moves_Management_Status__c')!='Dropped' && oppStageMap.containsKey(s.id)) {
				if (oppStages.get(oppStageMap.get(s.id))) {
					s.put('Moves_Management_Status__c', 'Stewarding');		
				} else {
					s.put('Moves_Management_Status__c', oppStageMap.get(s.id));
				}
			}
		}
	}
}