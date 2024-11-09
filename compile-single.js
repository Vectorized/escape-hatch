#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

async function main() {
  const srcPath = process.argv[process.argv.length - 1];
  if (!(/\.yul$/i.test(srcPath))) {
    console.error("Usage: node compile-single.js [INPUT_YUL_PATH]");
    return;
  }

  const lastHex = s => {
    const m = s.match(/[0-9a-fA-F]+/g);
    return m && m.length > 0 ? m[m.length - 1] : '';
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
  
  const compileYul = async (srcPath, evmVersion) => {
    return lastHex(await runCommand(await solcPath(), [
      srcPath, 
      '--bin', 
      '--optimize-runs=1', 
      '--strict-assembly', 
      '--evm-version=' + evmVersion
    ]));
  };

  const consoleLogHex = (name, s, countHexLen) => {
    if (countHexLen) {
      console.log(name + ' (' + hexLen(s) + ' bytes):');
    } else {
      console.log(name + ':');
    }
    console.log('\x1b[32m%s\x1b[0m', s);
  };

  const getRuntime = initcode => initcode.slice(initcode.indexOf('f3fe') + 4);

  const initcodeWithPush0 = await compileYul(srcPath, 'shanghai');
  const initcodeWithoutPush0 = await compileYul(srcPath, 'london');
  const runtimeWithPush0 = getRuntime(initcodeWithPush0);
  const runtimeWithoutPush0 = getRuntime(initcodeWithoutPush0);

  consoleLogHex('Initcode with PUSH0', initcodeWithPush0);
  consoleLogHex('Initcode without PUSH0', initcodeWithoutPush0);
  consoleLogHex('Runtime with PUSH0', runtimeWithPush0);
  consoleLogHex('Runtime without PUSH0', runtimeWithoutPush0);
};

main().catch(e => {
  console.error(e);
  process.exit(1);
});
