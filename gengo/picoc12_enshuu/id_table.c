#include    <stdlib.h>
#include    <string.h>
#include    "define.h"
#include    "id_table.h"

id_table_t *
id_table_new(int table_size)
{
    id_table_t  *id_table;

    if ((id_table = malloc(sizeof(id_table_t))) == NULL){
        return NULL;
    }
    if ((id_table->id = malloc(sizeof(id_info_t) * table_size)) == NULL){
        free(id_table);
        return (NULL);
    }
    id_table->n_ids = 0;
    id_table->max_n_ids = table_size;
    return (id_table);
}

void
id_table_delete(id_table_t *id_table)
{
    free(id_table->id);
    free(id_table);
}

int
id_table_add(id_table_t *id_table,id_info_t info)
{
    if (id_table_search(id_table,info.name) != NULL){
        return (FALSE);
    }
    if (id_table->n_ids >= id_table->max_n_ids){
        return (FALSE);
    }
    id_table->id[id_table->n_ids] = info;
    id_table->n_ids++;
    return (TRUE);
}

id_info_t *
id_table_search(id_table_t *id_table,char *name)
{
    int i;

    i = 0;
    while (i < id_table->n_ids){
        if (strcmp(id_table->id[i].name,name) == 0){
            return (&id_table->id[i]);
        }
        i++;
    }
    return (NULL);
}

int
id_table_get_size(id_table_t *id_table)
{
    return (id_table->n_ids);
}

id_info_t *
id_table_get_id_info(id_table_t *id_table,int n)
{
    if (n < 0 || n >= id_table->n_ids){
        return (NULL);
    }else{
        return (&id_table->id[n]);
    }
}

