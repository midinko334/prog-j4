import struct, sys

src = sys.argv[1]
out = sys.argv[2]

data = bytearray(open(src, 'rb').read())
header = data[0:64]
phdr   = data[64:120]
text   = bytearray(data[120:])

instr1 = text[0:6]   # mov r15d, gameflag
instr2 = text[6:8]   # mov bl, 10
instr3 = text[8:10]  # mov ecx, esp
assert instr1[0:2] == bytes.fromhex('41bf')   # mov r15d, imm32 (address varies with .text size)
assert bytes(instr2 + instr3) == bytes.fromhex('b30a89e1')

# NEW: also relocate the first 9 bytes of the placement loop prologue
#   lea ecx,[rcx+rcx*4+1] (4B) ; mov eax,ecx (2B) ; shr eax,26 (3B)
extra = text[10:19]
assert bytes(extra) == bytes.fromhex('8d4c890189c8c1e81a'), extra.hex()

tail = bytearray(text[19:])   # starts at "bts r14,rax"
assert bytes(tail[0:4]) == bytes.fromhex('490fabc6')   # bts r14,rax
assert tail[4] == 0x72                                  # jc  .place_loop
assert bytes(tail[6:8]) == bytes.fromhex('ffcb')        # dec ebx
assert tail[8] == 0x75                                  # jnz .place_loop

BASE = 0x400000
NEW_HDR_LEN = 114
total_len = NEW_HDR_LEN + len(tail)

p_flags = struct.unpack_from('<I', phdr, 4)[0]
bss_extra = struct.unpack_from('<Q', phdr, 40)[0] - struct.unpack_from('<Q', phdr, 32)[0]

buf = bytearray(total_len)

buf[0:4] = b'\x7fELF'
buf[4] = 2
buf[5] = 1
buf[6] = 1

# --- W1: e_ident free bytes (7-15) : instr1 + jmp -> offset 40 (w2) ---
w1 = bytearray(instr1)
jmp1_pos = 7 + len(w1)
rel1 = 40 - (jmp1_pos + 2)
assert -128 <= rel1 <= 127
w1 += bytes([0xEB, rel1 & 0xFF])
buf[7:7+len(w1)] = w1

struct.pack_into('<H', buf, 16, 2)
struct.pack_into('<H', buf, 18, 0x3E)
struct.pack_into('<I', buf, 20, 1)
struct.pack_into('<Q', buf, 24, BASE + 7)
struct.pack_into('<Q', buf, 32, 58)

# --- offset 40-51 (e_shoff + e_flags, 12 bytes, fully free) ---
# instr2 + instr3 (4B) + extra[0:6] (lea+mov, 6B) + jmp -> pocket2 @82  (2B) = 12B exactly
POCKET1 = 40 + 4          # = 44, where the relocated "lea" begins (also new loop-restart target)
POCKET2 = 82               # start of p_paddr, also fully free
w2 = bytearray(instr2 + instr3) + bytearray(extra[0:6])
jmp2_pos = 40 + len(w2)     # = 50
rel2 = POCKET2 - (jmp2_pos + 2)
assert -128 <= rel2 <= 127
w2 += bytes([0xEB, rel2 & 0xFF])
assert len(w2) == 12
buf[40:40+len(w2)] = w2

struct.pack_into('<H', buf, 52, 64)
struct.pack_into('<H', buf, 54, 56)
struct.pack_into('<H', buf, 56, 1)

# --- Phdr (overlapping last 6 bytes of Ehdr) ---
struct.pack_into('<I', buf, 58, 1)
struct.pack_into('<I', buf, 62, p_flags)
struct.pack_into('<Q', buf, 66, 0)
struct.pack_into('<Q', buf, 74, BASE)

# --- p_paddr (82-89, 8 bytes, ignored by Linux loader): extra[6:9] (shr) + jmp -> new tail start
NEW_TAIL_OFF = NEW_HDR_LEN   # = 114, tail now begins with "bts r14,rax"
pocket2_code = bytearray(extra[6:9])
jmp3_pos = POCKET2 + len(pocket2_code)   # 82+3 = 85
rel3 = NEW_TAIL_OFF - (jmp3_pos + 2)
assert -128 <= rel3 <= 127
pocket2_code += bytes([0xEB, rel3 & 0xFF])
assert len(pocket2_code) <= 8
buf[82:82+len(pocket2_code)] = pocket2_code    # trailing byte(s) of p_paddr stay 0, harmless

struct.pack_into('<Q', buf, 90, total_len)
struct.pack_into('<Q', buf, 98, total_len + bss_extra)
struct.pack_into('<Q', buf, 106, 1)

# --- patch the two backward jumps inside `tail` that used to target the old .place_loop ---
# they must now target POCKET1 (44), where the relocated "lea" instruction lives.
jc_pos_file = NEW_TAIL_OFF + 4     # position of the jc opcode byte in final file
rel_jc = POCKET1 - (jc_pos_file + 2)
assert -128 <= rel_jc <= 127
tail[5] = rel_jc & 0xFF

jnz_pos_file = NEW_TAIL_OFF + 8
rel_jnz = POCKET1 - (jnz_pos_file + 2)
assert -128 <= rel_jnz <= 127
tail[9] = rel_jnz & 0xFF

buf[114:] = tail

open(out, 'wb').write(buf)
print(f"{src} -> {out}: {len(buf)} bytes (header+phdr region: {NEW_HDR_LEN} bytes, tail: {len(tail)} bytes)")
