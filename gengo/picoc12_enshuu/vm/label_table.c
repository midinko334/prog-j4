#include    <stdlib.h>
#include    <string.h>
#include    "define.h"
#include    "label_table.h"

#define LABEL_TABLE_SIZE    10000

label_table_t *
label_table_new(void)
{
    label_table_t   *label_table;

    if ((label_table = malloc(sizeof(*label_table))) != NULL){
        label_table->n_labels = 0;
    }
    return (label_table);
}
    
void
label_table_delete(label_table_t *label_table)
{
    free(label_table);
}

int
label_table_add(label_table_t *label_table,char *label,int address)
{
    int a;

    if (label_table_search(label_table,label,&a)){
        return (FALSE);
    }
    strcpy(label_table->label[label_table->n_labels].label,label);
    label_table->label[label_table->n_labels].address = address;
    label_table->n_labels++;
    return (TRUE);
}

int
label_table_search(label_table_t *label_table,char *label,int *address)
{
    int     i;

    for (i = 0;i < label_table->n_labels;i++){
        if (strcmp(label_table->label[i].label,label) == 0){
            *address = label_table->label[i].address;
            return (TRUE);
        }
    }
    return (FALSE);
}
