#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

async function main() {
  const srcPaths = [
    'yul/Extcodesize.yul', 
    'yul/Extcodecopy.yul', 
    'yul/Extcodehash.yul', 
    'yul/Create.yul',
    'yul/Create2.yul',
    'yul/ForceSendEther.yul',
    'yul/GasLimitedCall.yul', 
    'yul/GasLimitedStaticcall.yul',
    'yul/Gas.yul',
    'yul/Gasprice.yul',
    'yul/Gaslimit.yul',
    'yul/Basefee.yul'
  ];

  const SECTION_SHIFT = 6;
  const SECTION_LENGTH = 1 << SECTION_SHIFT;
  
  const hexLen = s => s.length >> 1;

  const lastHex = s => {
    const m = s.match(/[0-9a-fA-F]+/g);
    return m && m.length > 0 ? m[m.length - 1] : '';
  };
  
  const rpadRuntime = runtime => {
    if (hexLen(runtime) > SECTION_LENGTH) {
      throw new Error("Runtime length is too long");
    }
    return runtime + '00'.repeat(SECTION_LENGTH - hexLen(runtime));
  };

  const hexNoPrefix = (x, n) => {
    let s = x.toString(16).replace(/^0[xX]/, '');
    if (s.length & 1 === 1) s = '0' + s;
    return n ? s : s + '00'.repeat(n - hexLen(s));
  };

  const randomHexNoPrefix = n => {
    const hexChars = '123456789abcdef';
    let s = '';
    for (let i = 0; i < 2 * n; ++i) {
      s += hexChars[Math.floor(Math.random() * hexChars.length)];
    }
    return s;
  };
  
  const runCommand = async (command, args) => {
    return new Promise((resolve, reject) => {
      const child = spawn(command, args);
      let output = '';
      child.stdout.on('data', data => output += data.toString());
      child.stderr.on('data', data => console.error(`Error: ${data}`));
      child.on('close', code => {
        if (code === 0) {
          resolve(output);
        } else {
          reject(`Process exited with code: ${code}`);
        }
      });
    });
  };

  const solcPath = async () => {
    const minSolc = '0.8.28';
    const findSolc = (dir) => {
      const semverScore = s => {
        let a = s.match(/\d+/g);
        if (!a) return 0;
        while (a.length < 3) a.push(0);
        return ~~a[0] * 1000000 + ~~a[1] * 1000 + ~~a[2];
      };
      let maxSemVerScore = 0;
      let bestPath = '';
      const thres = semverScore(minSolc);
      fs.readdirSync(dir).forEach(item => {
        if (!fs.statSync(path.join(dir, item)).isDirectory()) return;
        fs.readdirSync(path.join(dir, item)).forEach(executable => {
          const p = path.join(dir, item, executable);
          const score = semverScore(item);
          if (score > maxSemVerScore && fs.statSync(p).isFile() && score >= thres) {
            maxSemVerScore = score;
            bestPath = p;
          }
        });
      });
      return bestPath;
    };
    const latestSolc = () => {
      const homeDir = process.env.HOME || process.env.USERPROFILE;
      let dir = path.join(homeDir, '.svm');
      if (fs.existsSync(dir)) return findSolc(dir);
      const xdgDataHome = process.env.XDG_DATA_HOME || path.join(homeDir, '.local', 'share');
      dir = path.join(xdgDataHome, 'svm');
      if (fs.existsSync(dir)) return findSolc(dir);  
      return '';
    }
    let s = latestSolc();
    if (s !== '') return s;
    await runCommand('forge', ['build', '--use=' + minSolc]);
    if ((s = latestSolc()) !== '') return s;
    return 'solc';
  };
  
  const compileYul = async (srcPath, evmVersion) => {
    return lastHex(await runCommand(await solcPath(), [
      srcPath, 
      '--bin', 
      '--optimize-runs=1', 
      '--strict-assembly', 
      '--evm-version=' + evmVersion
    ]));
  };

  const stringAfter = (s, needle) => {
    const i = s.indexOf(needle);
    return i === -1 ? '' : s.slice(i + needle.length);
  };

  const compileAndGetRuntime = async (srcPath, section, usePush0, stats) => {
    let src = fs.readFileSync(srcPath, { encoding: 'utf8', flag: 'r' });
    let replacement = 'object "runtime" { code {';
    let sedFrom = '';
    for (let i = 0; i < section; ++i) {
      for (let j = 0; j < (SECTION_LENGTH >> 5); ++j) {
        const r = randomHexNoPrefix(28 + (i == 0 && j == 0 ? 1 : 0));
        replacement += ' mstore(0x' + hexNoPrefix(0xff - j) + ',0x' + r + ')';
        sedFrom = r + '60' + hexNoPrefix(0xff - j) + '52';
      }
    }
    const pattern = /object\s*?"runtime"\s*?{[\s\S]*?code[\s\S]*?{/;
    const tempSrcPath = 'tmp' + randomHexNoPrefix(16) + '.yul';
    fs.writeFileSync(tempSrcPath, src.replace(pattern, replacement));
    const evmVersion = usePush0 ? 'shanghai' : 'london';
    let runtime = '5b' + stringAfter(await compileYul(tempSrcPath, evmVersion), sedFrom);
    stats.push({
      'path': srcPath,
      'section': '0x' + hexNoPrefix(section, 1),
      'length': hexLen(runtime)
    });
    fs.unlinkSync(tempSrcPath, e => {});
    if (usePush0) runtime = runtime.replace('5f80', '5f5f');
    return rpadRuntime(runtime);
  };
  
  const toInitcode = runtime => 
    '61' + hexNoPrefix(hexLen(runtime), 2) + '80600a3d393df3' + runtime;

  const toConditionalInitcode = async (runtimeWithPush0, runtimeWithoutPush0) => {
    const xxxx = hexNoPrefix(hexLen(runtimeWithPush0), 2);
    if (hexLen(runtimeWithPush0) != hexLen(runtimeWithoutPush0)) {
      throw new Error('The lengths of the runtimes are different');
    }
    let pre = await compileYul('yul/ConditionalInitcode.yul', 'london');
    pre = pre.slice(pre.indexOf('f3fe') + 4);
    pre = pre.replace('6033', '60' + hexNoPrefix(hexLen(pre), 1));
    pre = pre.replace('61ffee', '61' + xxxx)
    return pre + runtimeWithPush0 + runtimeWithoutPush0;
  };

  const compileCombined = async (filePaths, usePush0, stats) => {
    let s = rpadRuntime('3d353d1a60' + hexNoPrefix(SECTION_SHIFT) + '1b56');
    for (let i = 0; i < filePaths.length; ++i) {
      s += await compileAndGetRuntime(filePaths[i], i + 1, usePush0, stats);
    }
    return s;
  };
  
  const keccak256OfHex = async (hexString) => {
    return '0x' + lastHex(await runCommand('cast', ['k', '0x' + hexString]));
  };

  const consoleLogHex = (name, s, countHexLen) => {
    if (countHexLen) {
      console.log(name + ' (' + hexLen(s) + ' bytes):');
    } else {
      console.log(name + ':');
    }
    console.log('\x1b[32m%s\x1b[0m', s);
  };
  
  const consoleLogStats = (name, stats) => {
    console.log(name + ':');
    console.table(stats);
  };

  let statsWithPush0 = [];
  let statsWithoutPush0 = [];
  const [runtimeWithPush0, runtimeWithoutPush0] = await Promise.all([
    compileCombined(srcPaths, true, statsWithPush0), 
    compileCombined(srcPaths, false, statsWithoutPush0)
  ]);
  let initcode = await toConditionalInitcode(runtimeWithPush0, runtimeWithoutPush0);
  const initcodehash = await keccak256OfHex(initcode);

  fs.mkdirSync('deployments', { recursive: true });
  fs.writeFileSync('deployments/runtime_with_push0.txt', runtimeWithPush0);
  fs.writeFileSync('deployments/runtime_without_push0.txt', runtimeWithoutPush0);
  fs.writeFileSync('deployments/initcode.txt', initcode);

  consoleLogStats('Stats with PUSH0', statsWithPush0);
  consoleLogStats('Stats without PUSH0', statsWithoutPush0);
  consoleLogHex('Runtime with PUSH0', runtimeWithPush0, true);
  consoleLogHex('Runtime without PUSH0', runtimeWithoutPush0, true);
  consoleLogHex('Initcode', initcode, true);
  consoleLogHex('Initcodehash', initcodehash);
};

main().catch(e => {
  console.error(e);
  process.exit(1);
});
