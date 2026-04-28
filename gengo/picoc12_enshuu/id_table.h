#ifndef ID_TABLE_H_INCLUDED

#define ID_TABLE_H_INCLUDED

#include    "id_info.h"

typedef struct{
    int n_ids;
    int max_n_ids;
    id_info_t *id;
} id_table_t;

extern id_table_t *
id_table_new(int table_size);

extern void
id_table_delete(id_table_t *id_table);

extern int
id_table_add(id_table_t *id_table,id_info_t info);

extern id_info_t *
id_table_search(id_table_t *id_table,char *name);

extern int
id_table_get_size(id_table_t *id_table);

extern id_info_t *
id_table_get_id_info(id_table_t *id_table,int n);

#endif
