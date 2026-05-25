# extract_dtb.py
import struct, sys, os

def page_align(size, page):
    return ((size + page - 1) // page) * page

with open('boot.img', 'rb') as f:
    data = f.read()

assert data[:8] == b'ANDROID!', "Não é boot.img Android"

kernel_size  = struct.unpack('<I', data[8:12])[0]
ramdisk_size = struct.unpack('<I', data[16:20])[0]
second_size  = struct.unpack('<I', data[24:28])[0]
page_size    = struct.unpack('<I', data[36:40])[0]

print(f"page_size    = {page_size}")
print(f"kernel_size  = {kernel_size}")
print(f"ramdisk_size = {ramdisk_size}")
print(f"second_size  = {second_size}  (DTB esperado)")

# Offsets (cada secção começa em múltiplo de page_size)
kernel_off  = page_size
ramdisk_off = kernel_off  + page_align(kernel_size,  page_size)
second_off  = ramdisk_off + page_align(ramdisk_size, page_size)

print(f"\nDTB offset:  0x{second_off:x}")
print(f"DTB tamanho: {second_size} bytes")

# Extrair kernel (útil pra ter)
with open('kernel.bin', 'wb') as f:
    f.write(data[kernel_off:kernel_off+kernel_size])

# Extrair "second" (deveria ser o DTB)
second = data[second_off:second_off+second_size]
with open('second.bin', 'wb') as f:
    f.write(second)

# Validar magic
magic = second[:4]
print(f"\nPrimeiros 4 bytes do second: {magic.hex()}")
if magic == b'\xd0\x0d\xfe\xed':
    print("✅ É um DTB único! Salvo como second.bin (renomeie para android.dtb)")
    os.rename('second.bin', 'android.dtb')
elif second[:4] == b'\x03\x00\x00\x00' or second[:4] == b'\x02\x00\x00\x00':
    print("ℹ️ Pode ser Amlogic multidtb (vários DTBs num blob). Vamos investigar.")
else:
    print(f"⚠️ Magic desconhecido — primeiros 32 bytes: {second[:32].hex()}")