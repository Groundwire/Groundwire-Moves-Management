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
}