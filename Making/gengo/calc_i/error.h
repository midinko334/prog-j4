#ifndef ERROR_H_INCLUDED

#define ERROR_H_INCLUDED

extern void
error(char *str,char *file,char *func,int line);

/* エラーメッセージを表示するマクロ */
#define	ERROR(m)	error(\
						(m),\
						((char *)__FILE__),\
						((char *)__FUNCTION__),\
						(__LINE__)\
					)

#endif
