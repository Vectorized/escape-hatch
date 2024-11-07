import subprocess
import re
import random
import os

def rpad_hex256(s):
    return s + (256 - (len(s) >> 1)) * '00'

def hex_no_prefix(x):
    return hex(x).lower().replace('0x', '')

def random_byte_uint(n):
    while True:
        r = random.randint(1, 1 << (8 * n)) | 1
        if len(hex_no_prefix(r)) == n * 2:
            return r

def compile_and_get_runtime(file_path, jump_section):
    with open(file_path, 'r') as file:
        file_content = file.read()
    
    pattern = r'object\s*"runtime"\s*{\s*code\s*{'
    replacement = 'object "runtime" {\n        code {\n'
    mem_dest = 0xff
    sed_from = ''
    for i in range(jump_section):
        for j in range(8):
            r = random_byte_uint(28 + int(i == 0 and j == 0))
            replacement += '\nmstore(' + hex(mem_dest - j) + ',' + hex(r) + ')'
            sed_from = hex_no_prefix(r) + '60' + hex_no_prefix(mem_dest - j) + '52'
    
    modified_content = re.sub(pattern, replacement, file_content, flags=re.MULTILINE)

    temp_file_path = '__' + file_path
    with open(temp_file_path, 'w') as file:
        file.write(modified_content)

    result = subprocess.run(["solc", temp_file_path, "--bin", "--optimize-runs=1", "--evm-version=istanbul", "--strict-assembly"], capture_output=True, text=True)
    output = result.stdout.strip()
    output = output.split(sed_from)[-1]
    os.remove(temp_file_path)

    return rpad_hex256('5b' + output)

def to_initcode(runtime_code):
    return '61' + hex_no_prefix(len(runtime_code) | 0x10000)[-4:] + '80600a3d393df3' + runtime_code

def compile_combined(file_paths):
    s = [rpad_hex256('3d353d1a60081b56')]
    for i, file_path in enumerate(file_paths):
        s.append(compile_and_get_runtime(file_path, i + 1))
    return ''.join(s)

file_paths = [
    'Extcodesize.yul', 
    'Extcodecopy.yul', 
    'Create.yul',
    'Create2.yul',
    'ForceSendEther.yul',
    'GasLimitedCall.yul', 
    'GasLimitedStaticcall.yul'
]

print(
    to_initcode(compile_combined(file_paths))
)
