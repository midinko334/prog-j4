#include	<termio.h>
#include	<stdio.h>

char
getChar(void)
{
	struct termio old_term, new_term;

	char	c;

	/* 現在の設定を得る */
	ioctl(0, TCGETA, &old_term);

	/* 設定のコピーをつくる */
	new_term = old_term;

	/* 入力文字のエコーを抑止する場合 */
	new_term.c_lflag &= ~(ICANON | ECHO);

	/* エコーは止めない場合 */
	//new_term.c_lflag &= ~(ICANON);

	/* 新しい設定を反映する */
	ioctl(0, TCSETAW, &new_term);

	/* 1 文字入力 */
	c = getchar();

	/* 古い設定に戻す */
	ioctl(0, TCSETAW, &old_term);

	return (c);
}	
