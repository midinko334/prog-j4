#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <shellcode.bin>\n", argv[0]);
        return 1;
    }

    FILE *fp = fopen(argv[1], "rb");
    if (!fp) { perror("fopen"); return 1; }
    fseek(fp, 0, SEEK_END);
    long size = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    if (size <= 0) {
        fprintf(stderr, "empty or invalid file\n");
        fclose(fp);
        return 1;
    }

    void *mem = mmap(NULL, size, PROT_READ | PROT_WRITE,
                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) { perror("mmap"); fclose(fp); return 1; }

    if (fread(mem, 1, size, fp) != (size_t)size) {
        perror("fread");
        fclose(fp);
        return 1;
    }
    fclose(fp);

    if (mprotect(mem, size, PROT_READ | PROT_EXEC) != 0) {
        perror("mprotect");
        return 1;
    }

    printf("[*] shellcode loaded at %p (%ld bytes)\n", mem, size);
    printf("[*] jumping in...\n");
    fflush(stdout);

    void (*entry)(void) = (void (*)(void))mem;
    entry();

    printf("[*] returned from shellcode\n");
    return 0;
}
