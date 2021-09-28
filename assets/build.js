// which top level variables/function names should be kept?
const reservedTopLevels = ['programName','switchMode','openNotification','closeNotification'];
const finalRootPath = '../priv/static/';

const buildTemplates = false;
const templateDir = '../lib/global_api_web/templates';
const finalTemplateDir = templateDir;

console.log("building in " + process.env.NODE_ENV + " mode")

// cd assets && node build.js

// start program
const glob = require('glob');
const fs = require('fs');
const { execSync } = require('child_process');

// start javascript
console.log("building javascript files...")
try {
  fs.unlinkSync('./tmp/file-cache.json')
} catch (e) {}

try {
  fs.mkdirSync('./tmp')
} catch (e) {}

glob.sync("!(node_modules)/**/*.js").forEach(filePath => {
  const finalDir = finalRootPath + filePath.substring(0, filePath.lastIndexOf('/'));
  if (!fs.existsSync(finalDir)) {
    fs.mkdirSync(finalDir, { recursive: true });
  }

  console.log("building " + filePath);
  const finalPath = finalRootPath + filePath;
  //todo use a minifier instead of an uglifier
  execSync('uglifyjs ' + filePath + ' -c -m toplevel,reserved=[' + reservedTopLevels + '] --mangle-props --name-cache ./tmp/file-cache.json -o ' + finalPath)
});

fs.rmSync('./tmp', { recursive: true })
console.log("done!")
// end javascript


// start css
console.log("building css files...")

glob.sync("!(node_modules)/**/*.css").forEach(filePath => {
  const finalDir = finalRootPath + filePath.substring(0, filePath.lastIndexOf('/'));
  if (!fs.existsSync(finalDir)) {
    fs.mkdirSync(finalDir, { recursive: true });
  }

  console.log("building " + filePath);
  const finalPath = finalRootPath + filePath;
  execSync('postcss ' + filePath + ' -o ' + finalPath + ' --env ' + process.env.NODE_ENV)
})

console.log("done!");
// end css

// start html
if (!buildTemplates) {
  console.log("building html (templates) have been disabled");
} else {
  console.log("building html files...")
  execSync('html-minifier --input-dir ' + templateDir + ' --output-dir ' + finalTemplateDir + ' --file-ext eex --collapse-whitespace --remove-comments --remove-script-type-attributes --remove-tag-whitespace --use-short-doctype --minify-css true --minify-js true')
  console.log("done!");
}
// end html