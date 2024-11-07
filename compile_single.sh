solc $1 --bin --optimize-runs=10000 --evm-version=istanbul --strict-assembly | grep -o "[0-9a-fA-F]\{32,\}" | sed "s/00$//" | sed "s/.*fe//"
