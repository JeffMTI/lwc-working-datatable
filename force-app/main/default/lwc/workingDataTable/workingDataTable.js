import { LightningElement, wire, api, track } from 'lwc';
import initRecords from '@salesforce/apex/WorkingDataTableCtrl.initRecords';
import updateRecords from '@salesforce/apex/WorkingDataTableCtrl.updateRecords';
import deleteSObject from '@salesforce/apex/WorkingDataTableCtrl.deleteSObject';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/*
  this component can be used in another lwc like this:

  <c-working-data-table></c-working-data-table>

*/


export default class WorkingDataTable  extends NavigationMixin(LightningElement) {
    @api objectApiName;
    @api fieldNamesStr;
    @api inlineEdit = false; // this has to stay TRUE since that's how users tell us what they want
    @api colAction = false; // this has to stay FALSE since we do not need to support row actions
    @api hiderowcheckboxes = false;
    @track data;
    @track columns;
    @track loadMoreStatus;
    @api totalNumberOfRows;

    defaultSortDirection = 'asc';
    sortDirection = 'asc';
    sortedBy;
    pageSize = 50;
    wiredsObjectData;

    inlineEdit = true;
    hiderowcheckboxes = true;
    objectApiName = 'Account';
    fieldNamesStr = 'Name,Employees,Type';


    @wire(initRecords, { ObjectName: '$objectApiName', fieldNamesStr: '$fieldNamesStr', recordId: '' , Orderby: 'Name', OrderDir: 'ASC',inlineEdit:'$inlineEdit' , enableColAction:'$colAction', numPerPage: '$pageSize' })
    wiredSobjects(result) {
        this.wiredsObjectData = result;
        if (result.data) {
            this.data = result.data.sobList;
            this.columns = result.data.ldwList;
            this.totalNumberOfRows = result.data.totalCount;
            this.sortDirection = 'ASC';
            this.sortedBy = 'Name';
        }
    }

    getSelectedName(event) {
        var selectedRows = event.detail.selectedRows;
        var recordIds=[];
        if(selectedRows.length > 0) {
            for(var i =0 ; i< selectedRows.length; i++) {
                recordIds.push(selectedRows[i].Id);
            }

            const selectedEvent = new CustomEvent('selected', { detail: {recordIds}, });
            // Dispatches the event.
            this.dispatchEvent(selectedEvent);
        }

    }

    loadMoreData(event) {
        //Display a spinner to signal that data is being loaded
        //Display "Loading" when more data is being loaded

        if (this.totalNumberOfRows > this.pageSize){
            this.loadMoreStatus = 'Loading';
            const currentRecord = this.data;
            const lastRecId = currentRecord[currentRecord.length - 1].Id;
            initRecords({
                ObjectName: this.objectApiName,
                fieldNamesStr: this.fieldNamesStr,
                recordId: lastRecId,
                Orderby: 'Id',
                OrderDir: 'ASC',
                inlineEdit: this.inlineEdit,
                enableColAction: this.colAction
            })
                .then(result => {
                    const currentData = result.sobList;
                    //Appends new data to the end of the table
                    const newData = currentRecord.concat(currentData);
                    this.data = newData;
                    if (this.data.length >= this.totalNumberOfRows) {
                        this.loadMoreStatus = 'No more data to load';
                    } else {
                        this.loadMoreStatus = '';
                    }
                })
                .catch(error => {
                    console.log('-------error-------------' + error);
                    console.log(error);
                });
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'edit':
                this.editRecord(row);
                break;
            case 'view':
                this.viewRecord(row);
                break;
            case 'delete':
                this.deleteRecord(row);
                break;
            default:
                this.viewRecord(row);
                break;
        }
    }

    //currently we are doing client side delete, we can call apex tp delete server side
    deleteRecord(row) {
        const { id } = row;
        const index = this.findRowIndexById(id);
        if (index !== -1) {
            this.data = this.data
                .slice(0, index)
                .concat(this.data.slice(index + 1));
        }
    }

    findRowIndexById(id) {
        let ret = -1;
        this.data.some((row, index) => {
            if (row.id === id) {
                ret = index;
                return true;
            }
            return false;
        });
        return ret;
    }


    editRecord(row) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: row.Id,
                actionName: 'edit',
            },
        });
    }

    viewRecord(row) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: row.Id,
                actionName: 'view',
            },
        });
    }


    //When save method get called from inlineEdit
    handleSave(event) {

        var draftValuesStr = JSON.stringify(event.detail.draftValues);
        updateRecords({ sobList: this.data, updateObjStr: draftValuesStr, objectName: this.objectApiName })
            .then(result => {

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Records updated',
                        variant: 'success'
                    })
                );
                // Clear all draft values
                this.draftValues = [];
                return refreshApex(this.wiredsObjectData);
            })
            .catch(error => {
                console.log('-------error-------------'+error);
                console.log(error);
            });
    }

    sortBy(field, reverse, primer) {
        const key = primer
            ? function(x) {
                return primer(x[field]);
            }
            : function(x) {
                return x[field];
            };

        return function(a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }


    updateColumnSorting(event) {

        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.data];

        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        this.data = cloneData;
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;
    }
}