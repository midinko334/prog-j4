#ifndef ID_TABLE_STACK_INCLUDED

#define ID_TABLE_STACK_INCLUDED

#include    "id_table.h"

typedef struct{
    int sp;
    int max_size;
    id_table_t  **stack;
} id_table_stack_t;

extern id_table_stack_t *
id_table_stack_new(int size);

extern void
id_table_stack_delete(id_table_stack_t *stack);

extern int
id_table_stack_push(id_table_stack_t *stack, id_table_t *table);

extern id_table_t *
id_table_stack_pop(id_table_stack_t *stack);

extern id_table_t *
id_table_stack_peek(id_table_stack_t *stack,int offset);

extern id_table_t *
id_table_stack_peek_bottom(id_table_stack_t *stack);

extern int
id_table_stack_get_size(id_table_stack_t *stack);

#endif
