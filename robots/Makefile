NASM      := nasm
CC        := gcc
NASMFLAGS := -f elf64 -Wall -Werror
CFLAGS    := -Wall -Wextra -Werror

TARGET := robots
OBJS   := robots.o getchar.o

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) -nostartfiles -no-pie -o $@ $^

robots.o: robots.asm
	$(NASM) $(NASMFLAGS) -o $@ $<

getchar.o: getchar.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(TARGET) $(OBJS)
