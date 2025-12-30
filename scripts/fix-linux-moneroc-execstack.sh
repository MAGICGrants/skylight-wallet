#!/bin/bash
# Script to fix executable stack flag in monero_libwallet2_api_c.so
# This should be run whenever monero_libwallet2_api_c.so file is updated.

LIB_PATH="$(dirname "$0")/../linux/monero_libwallet2_api_c.so"

if [ ! -f "$LIB_PATH" ]; then
    echo "Error: $LIB_PATH not found"
    exit 1
fi

python3 << PYTHON_SCRIPT
import struct
import sys

lib_path = "$LIB_PATH"

# Read the ELF file
with open(lib_path, 'rb') as f:
    data = bytearray(f.read())

# Check ELF magic
if data[:4] != b'\x7fELF':
    print('Error: Not an ELF file')
    sys.exit(1)

# Get ELF class (32 or 64 bit)
elf_class = data[4]
if elf_class == 1:  # 32-bit
    phoff = struct.unpack('<I', data[28:32])[0]
    phentsize = struct.unpack('<H', data[42:44])[0]
    phnum = struct.unpack('<H', data[44:46])[0]
else:  # 64-bit
    phoff = struct.unpack('<Q', data[32:40])[0]
    phentsize = struct.unpack('<H', data[54:56])[0]
    phnum = struct.unpack('<H', data[56:58])[0]

# Find GNU_STACK segment and clear executable flag
found = False
for i in range(phnum):
    offset = phoff + i * phentsize
    if elf_class == 1:  # 32-bit
        p_type = struct.unpack('<I', data[offset:offset+4])[0]
    else:  # 64-bit
        p_type = struct.unpack('<I', data[offset:offset+4])[0]
    
    # Check if it's PT_GNU_STACK (0x6474e551)
    if p_type == 0x6474e551:
        found = True
        if elf_class == 1:  # 32-bit
            p_flags_offset = offset + 24
        else:  # 64-bit
            p_flags_offset = offset + 4
        
        # Read current flags
        p_flags = struct.unpack('<I', data[p_flags_offset:p_flags_offset+4])[0]
        # Clear executable bit (remove PF_X = 0x1)
        p_flags = p_flags & ~0x1
        # Write back
        data[p_flags_offset:p_flags_offset+4] = struct.pack('<I', p_flags)
        print(f'Cleared executable flag. New flags: 0x{p_flags:x}')
        break

if found:
    # Write back the modified file
    with open(lib_path, 'wb') as f:
        f.write(data)
    print('File updated successfully')
else:
    print('Warning: GNU_STACK segment not found')
    sys.exit(1)
PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    echo "Successfully fixed executable stack flag in $LIB_PATH"
else
    echo "Failed to fix executable stack flag"
    exit 1
fi

