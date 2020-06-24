public with sharing class WorkingDataTableCtrl {

    @TestVisible
    private static Map<String, Boolean> fieldToEditableSetting = new Map<String, Boolean>{
            'Name' => true,
            'Employees' => true,
            'Type' => false
    };


    //init method to fetch initial records
    @AuraEnabled(cacheable=true)
    public static DataTableWrapper initRecords(String ObjectName, String fieldNamesStr, String recordId, String Orderby, String OrderDir, Boolean inlineEdit, Boolean enableColAction, Integer numPerPage) {

        DataTableWrapper dtw = new DataTableWrapper();
        List<LabelDescriptionWrapper> labelList = new List<LabelDescriptionWrapper>();
        List<String> fieldSet = new List<String>();
        System.debug(fieldNamesStr);
        Set<String> fieldNameSet = new Set<String>(fieldNamesStr.split(','));

        if (Schema.getGlobalDescribe().containsKey(ObjectName)) {

            SObject sObj = Schema.getGlobalDescribe().get(ObjectName).newSObject() ;

            //get all the labels for fields and put them in a map, keyed to the field api name
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(ObjectName).getDescribe().fields.getMap();
            Map<Schema.SObjectField, String> fieldToAPIName = new Map<Schema.SObjectField, String>();
            Map<String, String> apiNameToLabel = new Map<String, String>();
            for (String fieldName : fieldNameSet) {
                if (fieldMap.containsKey(fieldName)) {
                    fieldSet.add(fieldName);
                    labelList.add(new LabelDescriptionWrapper(fieldMap.get(fieldName).getDescribe().getLabel(), fieldName, fieldMap.get(fieldName).getDescribe().getType().name().toLowerCase(), fieldToEditableSetting.get(fieldName), null));
                }
            }

            System.debug('FieldSet has: ' + fieldSet);

            System.debug('Provide the table column headers');
            dtw.ldwList = labelList;
            dtw.fieldsList = fieldSet;

            //call method to query for data records
            List<SObject> sObjectRecords = getsObjectRecords(ObjectName, fieldSet, numPerPage, recordId, Orderby, OrderDir);
            dtw.sobList = sObjectRecords;

            dtw.totalCount = Database.countQuery('SELECT count() FROM ' + ObjectName);
            System.debug('sObjectList size: ' + dtw.sobList.size());
            System.debug('Total Count is: ' + dtw.totalCount);
        }

        return dtw;
    }

    @AuraEnabled(cacheable=true)
    public static List<SObject> getsObjectRecords(String ObjectName, List<String> fieldNameSet, Integer LimitSize, String recId, String Orderby, String OrderDir) {

        OrderDir = String.isBlank(OrderDir) ? 'asc' : OrderDir;

        String query = 'SELECT ' + String.join(fieldNameSet, ',') + '  FROM ' + ObjectName;
        if (String.isNotBlank(recId)) {
            recId = String.valueOf(recId);
            query += ' WHERE ID > \'' + recId + '\'';
        }

        query += ' ORDER BY ' + Orderby + ' ' + OrderDir + ' NULLS LAST';

        if (LimitSize != null && Integer.valueOf(LimitSize) > 0) {
            LimitSize = Integer.valueOf(LimitSize);
            query += ' Limit ' + LimitSize;
        }

        System.debug('Query String: ' + query);
        return Database.query(query);
    }

    //metho if we want to delete records

    @AuraEnabled
    public static SObject deleteSObject(SObject sob) {
        delete sob;
        return sob;
    }

    //Method to save records in inline edit
    @AuraEnabled
    public static void updateRecords(List<SObject> sobList, String updateObjStr, String objectName) {

        schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objectName);

        Map<String, Schema.SObjectField> sObjectFields = sobjType.getDescribe().fields.getMap();

        List<Object> obList = (List<Object>) JSON.deserializeUntyped(updateObjStr);

        List<SObject> updateList = new List<SObject>();

        for (Object ob : obList) {

            Map<String, Object> obmap = (Map<String, Object>) ob;

            System.debug('This is what the ob has: ' + ob);

            String rowKey = (String) obmap.get('id');
            Integer rowKeyInt = Integer.valueOf(rowKey.removeStart('row-'));

            SObject sObj = sobList[rowKeyInt];

            for (String fieldName : obmap.keySet()) {

                if (fieldName != 'id') {
                    Object value = obmap.get(fieldName);

                    Schema.DisplayType valueType = sObjectFields.get(fieldName).getDescribe().getType();

                    if (value instanceof String && valueType != Schema.DisplayType.STRING) {

                        String svalue = (String) value;
                        if (valueType == Schema.DisplayType.DATE) {
                            sObj.put(fieldName, Date.valueOf(svalue));
                        } else if (valueType == Schema.DisplayType.DATETIME) {

                            try {
                                System.debug((DateTime) value);
                            } catch (Exception ex) {
                                System.debug(ex.getMessage());
                            }
                            String d1 = svalue;
                            List<String> d2 = d1.split('-');
                            List<Integer> timeComponent = new List<Integer>();
                            timeComponent.add(Integer.valueOf(d2[0]));
                            timeComponent.add(Integer.valueOf(d2[1]));
                            timeComponent.add(Integer.valueOf(d2[2].left(2)));

                            String t = d2[2].substringBetween('T', '.');

                            List<String> time1 = t.split(':');
                            timeComponent.add(Integer.valueOf(time1[0]));
                            timeComponent.add(Integer.valueOf(time1[1]));
                            timeComponent.add(Integer.valueOf(time1[2]));

                            Datetime dt = Datetime.newInstance(timeComponent[0], timeComponent[1], timeComponent[2], timeComponent[3], timeComponent[4], timeComponent[5]);
                            sObj.put(fieldName, dt);

                        } else if (valueType == Schema.DisplayType.PERCENT || valueType == Schema.DisplayType.CURRENCY) {
                            sObj.put(fieldName, svalue == '' ? null : Decimal.valueOf(svalue));
                        } else if (valueType == Schema.DisplayType.DOUBLE) {
                            sObj.put(fieldName, svalue == '' ? null : Double.valueOf(svalue));
                        } else if (valueType == Schema.DisplayType.INTEGER) {
                            sObj.put(fieldName, Integer.valueOf(svalue));
                        } else if (valueType == Schema.DisplayType.BASE64) {
                            sObj.put(fieldName, Blob.valueOf(svalue));
                        } else {
                            sObj.put(fieldName, svalue);
                        }
                    } else {
                        sObj.put(fieldName, value);
                    }
                }
            }

            updateList.add(sObj);
        }

        update updateList;
    }

    //wrapper class for data table
    public class DataTableWrapper {
        @AuraEnabled
        public List<LabelDescriptionWrapper> ldwList;
        @AuraEnabled
        public List<SObject> sobList;
        @AuraEnabled
        public List<String> fieldsList;
        @AuraEnabled
        public Integer totalCount;
    }

    //Wrapper class to store Field details
    public class LabelDescriptionWrapper {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String fieldName;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public Boolean sortable;
        @AuraEnabled
        public Boolean editable;
        @AuraEnabled
        public TypeAttributes typeAttributes;

        public LabelDescriptionWrapper(String labelTemp, String fieldNameTemp, String typeTemp, Boolean editableTemp, TypeAttributes typeAttributesTemp) {
            label = labelTemp;
            fieldName = fieldNameTemp;
            type = typeTemp;
            sortable = true;
            editable = editableTemp;
            typeAttributes = typeAttributesTemp;
        }
    }

    //Wrapper class to bind dropdown action with data row
    public class TypeAttributes {
        @AuraEnabled
        public List<Actions> rowActions;

        public typeAttributes(List<Actions> rowActionsTemp) {
            rowActions = rowActionsTemp;
        }
    }

    //Wrapper class  to store dropdown action
    public class Actions {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String name;

        public Actions(String labelTemp, String nameTemp) {
            label = labelTemp;
            name = nameTemp;
        }
    }

}