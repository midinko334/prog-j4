#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

/* .bss (未初期化データ) 用に多めに余白を確保しておく。
   nasm -f bin はファイルにbss分のバイトを書き出さないため、
   ファイルサイズ通りにmmapするとbssアクセスでSEGVする。 */
#define BSS_PADDING (64 * 1024)

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <bin>\n", argv[0]); return 1; }
    FILE *fp = fopen(argv[1], "rb");
    if (!fp) { perror("fopen"); return 1; }
    fseek(fp, 0, SEEK_END);
    long size = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    size_t total = (size_t)size + BSS_PADDING;
    void *mem = mmap(NULL, total, PROT_READ | PROT_WRITE,
                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) { perror("mmap"); return 1; }
    fread(mem, 1, size, fp);
    fclose(fp);

    /* コード+bss領域全体をRWXにする(テスト用ローダーとして簡略化)。
       本格的にW^Xを守るなら .bss サイズを事前計算して
       ページ境界でRXとRWを分けるべきだが、ここでは省略。 */
    if (mprotect(mem, total, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
        perror("mprotect");
        return 1;
    }

    fprintf(stderr, "[*] loaded at %p (code=%ld bytes, +%d bss padding)\n",
            mem, size, BSS_PADDING);
    fprintf(stderr, "[*] clearing registers and jumping in...\n");

    asm volatile(
        "push %0\n\t"
        "xor %%eax, %%eax\n\t"
        "xor %%ebx, %%ebx\n\t"
        "xor %%ecx, %%ecx\n\t"
        "xor %%edx, %%edx\n\t"
        "xor %%esi, %%esi\n\t"
        "xor %%edi, %%edi\n\t"
        "xor %%ebp, %%ebp\n\t"
        "xor %%r8, %%r8\n\t"
        "xor %%r9, %%r9\n\t"
        "xor %%r10, %%r10\n\t"
        "xor %%r11, %%r11\n\t"
        "xor %%r12, %%r12\n\t"
        "xor %%r13, %%r13\n\t"
        "xor %%r14, %%r14\n\t"
        "xor %%r15, %%r15\n\t"
        "ret\n\t"
        :
        : "r"(mem)
        : "memory"
    );

    return 0;
}
