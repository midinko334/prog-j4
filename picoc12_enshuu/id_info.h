#ifndef ID_INFO_H_INCLUDED

#define ID_INFO_H_INCLUDED

#include "scanner.h"

typedef enum{
    ID_VARIABLE,
    ID_FUNCTION
} id_kind_t;

typedef struct{
    char name[MAX_IDENTIFIER_LEN];
    id_kind_t   id_type;
    union{
        struct{
            int is_array;   /* array であるとき TRUE                */
            int offset;
            int size;       /* array であるときだけ有効．配列要素数 */
        } variable;
        struct{
            /* 現在未使用 */
            int n_params;
        } function;
    };
} id_info_t;

#endif
