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

  let cachedSolcPath = '';
  const solcPath = async () => {
    if (cachedSolcPath !== '') return cachedSolcPath;
    const minSolc = '0.8.28';
    const findSolc = (dir) => {
      const semverScore = s => {
        let a = (s + '.0.0.0').match(/\d+/g);
        return ~~a[0] * 1000000 + ~~a[1] * 1000 + ~~a[2];
      };
      const dirForEach = (d, f) =>
        fs.existsSync(d) && fs.statSync(d).isDirectory() && fs.readdirSync(d).forEach(f);
      let best = '';
      dirForEach(dir, subDir => 
        dirForEach(path.join(dir, subDir), executable => {
          const p = path.join(dir, subDir, executable);
          if (
            semverScore(subDir) > semverScore(best) &&
            semverScore(subDir) >= semverScore(minSolc) &&
            fs.statSync(p).isFile()
          ) best = p;
        })
      );
      return best;
    };
    const homeDir = process.env.HOME || process.env.USERPROFILE;
    const latestSolc = () => [
      path.join(homeDir, '.svm'),
      path.join(process.env.XDG_DATA_HOME || path.join(homeDir, '.local', 'share'), 'svm')
    ].map(findSolc).find(solc => solc) || '';
    return cachedSolcPath = (latestSolc() || 
      await runCommand('forge', ['build', '--use=' + minSolc]).then(latestSolc));
  };
  if ((await solcPath()) === '') throw new Error("Cannot get Foundry's Solidity path");

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
