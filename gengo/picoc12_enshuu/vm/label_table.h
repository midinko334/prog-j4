#ifndef LABEL_TABLE_H_INCLUDED
#define LABEL_TABLE_H_INCLUDED

#define LABEL_LEN   50
#define LABEL_TABLE_SIZE    10000

typedef struct{
    char    label[LABEL_LEN];
    int     address;
} label_t;

typedef struct{
    label_t label[LABEL_TABLE_SIZE];
    int     n_labels;
} label_table_t;

extern label_table_t *
label_table_new(void);

extern void
label_table_delete(label_table_t *label_table);

extern int
label_table_add(label_table_t *label_table,char *label,int address);

extern int
label_table_search(label_table_t *label_table,char *label,int *address);

#endif
