import struct, sys

path = sys.argv[1]
out = sys.argv[2]
with open(path, 'rb') as f:
    data = bytearray(f.read())

# ELF64 header offsets
e_shoff_off = 0x28
e_shstrndx_off = 0x3E
e_shnum_off = 0x3C
e_shentsize_off = 0x3A

e_phoff = struct.unpack_from('<Q', data, 0x20)[0]
e_phentsize = struct.unpack_from('<H', data, 0x36)[0]
e_phnum = struct.unpack_from('<H', data, 0x38)[0]

# find furthest extent needed by PT_LOAD segments (offset+filesz)
max_end = 0
for i in range(e_phnum):
    off = e_phoff + i * e_phentsize
    p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack_from('<IIQQQQQQ', data, off)
    if p_type == 1:  # PT_LOAD
        max_end = max(max_end, p_offset + p_filesz)

# zero out section header info (not needed for execution)
struct.pack_into('<Q', data, e_shoff_off, 0)
struct.pack_into('<H', data, e_shnum_off, 0)
struct.pack_into('<H', data, e_shstrndx_off, 0)

# truncate to end of last needed PT_LOAD content
data = data[:max_end]

with open(out, 'wb') as f:
    f.write(data)
print(f"Truncated to {len(data)} bytes (from {path})")
