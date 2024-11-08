import subprocess
import re
import sys

def main():
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
        command = [
            "solc",
            file_path,
            "--bin",
            "--optimize-runs=1",
            "--evm-version=istanbul",
            "--strict-assembly"
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        a = re.findall(r'\b[0-9a-fA-F]+\b', result.stdout.strip())
        if len(a) > 0:
            initcode = a[-1]
            print('initcode:')
            print(a[-1])
            print('-' * 64)
            runtime = initcode[initcode.index('f3fe') + 4:]
            print('runtime (' + str(len(runtime) >> 1) + ' bytes):')
            print(runtime)
            print('-' * 64)
    else:
        print('Usage: python compile_single.py [input_yul_path]')

if __name__ == '__main__':
    main()