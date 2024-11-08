import subprocess
import re
import random
import os

SECTION_SHIFT = 6
SECTION_LENGTH = 1 << SECTION_SHIFT

def rpad_hex(s):
    global SECTION_LENGTH
    n = (len(s) >> 1)
    assert(n <= SECTION_LENGTH)
    return s + (SECTION_LENGTH - n) * '00'

def hex_no_prefix(x, n=None):
    s = hex(x).lower().replace('0x', '')
    s = '0' + s if (len(s) & 1) == 1 else s
    if n is not None:
        while (len(s) >> 1) < n:
            s = '00' + s
    return s

def random_hex_no_prefix(n):
    while True:
        s = hex_no_prefix(random.randint(1, 1 << (8 * n)) | 1)
        if len(s) == n * 2:
            return s

def compile_and_get_runtime(file_path, jump_section, stats):
    with open(file_path, 'r') as file:
        code = file.read()
    
    pattern = r'object\s*"runtime"\s*{\s*code\s*{'
    replacement = 'object "runtime" { code {'
    sed_from = ''
    for i in range(jump_section):
        for j in range(SECTION_LENGTH >> 5):
            r = random_hex_no_prefix(28 + int(i == 0 and j == 0))
            replacement += ' mstore(' + hex(0xff - j) + ',0x' + r + ')'
            sed_from = r + '60' + hex_no_prefix(0xff - j) + '52'
    
    code = re.sub(pattern, replacement, code, flags=re.MULTILINE)

    temp_file_path = 'tmp_' + random_hex_no_prefix(8) + '.yul'
    with open(temp_file_path, 'w') as file:
        file.write(code)

    command = [
        "solc",
        temp_file_path,
        "--bin",
        "--optimize-runs=1",
        "--evm-version=london",
        "--strict-assembly"
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    runtime = '5b' + result.stdout.strip().split(sed_from)[-1]
    stats.append([file_path, str(jump_section), str(len(runtime) >> 1)])
    os.remove(temp_file_path)

    return rpad_hex(runtime)

def to_initcode(runtime):
    xxxx = hex_no_prefix(len(runtime) >> 1, 2)
    return '61' + xxxx + '80600a3d393df3' + runtime

def compile_combined(file_paths, stats):
    global SECTION_SHIFT
    s = [rpad_hex('3d353d1a60' + hex_no_prefix(SECTION_SHIFT) + '1b56')]
    for i, file_path in enumerate(file_paths):
        s.append(compile_and_get_runtime(file_path, i + 1, stats))
    return ''.join(s)

def print_table(stats):
    col_widths = [max(len(str(c)) for c in column) for column in zip(*stats)]
    for row in stats:
        print("  ".join(str(c).ljust(w) for c, w in zip(row, col_widths)))

file_paths = [
    'yul/Extcodesize.yul', 
    'yul/Extcodecopy.yul', 
    'yul/Create.yul',
    'yul/Create2.yul',
    'yul/ForceSendEther.yul',
    'yul/GasLimitedCall.yul', 
    'yul/GasLimitedStaticcall.yul',
    'yul/Gas.yul',
    'yul/Gasprice.yul',
    'yul/Gaslimit.yul',
    'yul/Basefee.yul'
]

stats = [['file path', 'jump section', 'runtime bytes']]
runtime = compile_combined(file_paths, stats)
with open('test/data/runtime.txt', 'w') as file:
    file.write(runtime)

initcode = to_initcode(runtime)
with open('test/data/initcode.txt', 'w') as file:
    file.write(initcode)

print_table(stats)
print('-' * 64)
print('initcode:')
print(initcode)
print('-' * 64)

print('runtime (' + str(len(runtime) >> 1) + ' bytes):')
print(runtime)
print('-' * 64)
