#include    <stdlib.h>
#include    "define.h"
#include    "id_table_stack.h"

id_table_stack_t *
id_table_stack_new(int size)
{
    id_table_stack_t    *stack;

    if ((stack = malloc(sizeof(*stack))) == NULL){
        return (NULL);
    }
    if ((stack->stack = malloc(sizeof(*stack->stack) * size)) == NULL){
        return (FALSE);
    }
    stack->max_size = size;
    stack->sp = 0;
    return (stack);
}

void
id_table_stack_delete(id_table_stack_t *stack)
{
    free(stack->stack);
    free(stack);
}

int
id_table_stack_push(id_table_stack_t *stack, id_table_t *table)
{
    if (stack->sp >= stack->max_size){
        return (FALSE);
    }
    stack->stack[stack->sp] = table;
    stack->sp++;
    return (TRUE);
}

id_table_t *
id_table_stack_pop(id_table_stack_t *stack)
{
    id_table_t  *t;

    if (stack->sp <= 0){
        t = NULL;
    }else{
        t = stack->stack[stack->sp - 1];
        stack->sp--;
    }
    return (t); 
}

id_table_t *
id_table_stack_peek(id_table_stack_t *stack,int offset)
{
    id_table_t  *t;

    if (stack->sp <= offset){
        t = NULL;
    }else{
        t = stack->stack[stack->sp - offset - 1];
    }
    return (t);
}

id_table_t *
id_table_stack_peek_bottom(id_table_stack_t *stack)
{
    id_table_t  *t;

    if (stack->sp <= 0){
        t = NULL;
    }else{
        t = stack->stack[0];
    }
    return (t);
}

int
id_table_stack_get_size(id_table_stack_t *stack)
{
    return (stack->sp);
}
