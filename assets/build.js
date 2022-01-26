// this file has to be run in the assets dir (like: cd assets && node build.js)

// which top level variables/function names should be kept?
const reservedTopLevels = ['programName','switchMode','createNotification','closeNotification','closeNews'];
const apiBaseUrl = 'http://api.geysermc';
const finalRootPath = '../priv/static/';

const buildTemplates = false;
const templateDir = '../lib/global_api_web/templates';
const finalTemplateDir = process.env.NODE_ENV === "production" ? templateDir : "../priv/static/html";

console.log("building in " + process.env.NODE_ENV + " mode");

// start program
const glob = require('glob');
const fs = require('fs');
const { exec, execSync } = require('child_process');
const UglifyJS = require('uglify-js');

//region build JavaScript function
let nameCache = {};

function buildJavaScript(filePath) {
  const finalDir = finalRootPath + filePath.substring(0, filePath.lastIndexOf('/'));
  if (!fs.existsSync(finalDir)) {
    fs.mkdirSync(finalDir, { recursive: true });
  }

  console.log("building " + filePath);
  const finalPath = finalRootPath + filePath;
  //todo use a minifier instead of an uglifier

  let code = fs.readFileSync(filePath, "utf-8").replace(/%API_BASE_URL%/gm, apiBaseUrl);
  code = UglifyJS.minify(code, {mangle: { toplevel: true, reserved: reservedTopLevels }, nameCache: nameCache}).code;
  fs.writeFileSync(finalPath, code);
  console.log("finished writing js file " + filePath);
}
//endregion

//region watch and build changes argument
if (process.argv.includes('--watch')) {
  console.log("watch mode has been detected!");

  // ignore dotfiles, ignore css, ignore node_modules and ignore:
  // package.json,package-lock.json,build.js,postcss.config.js,tailwind.config.js
  const ignoredChanges = /(^|[\/\\])\..|^.+\.css$|^node_modules|package\.json|package-lock\.json|build\.js|postcss\.config\.js|tailwind\.config\.js/;

  require('chokidar')
      .watch('.', {ignored: ignoredChanges})
      .on('all', (event, path) => {
        if (["add", "change"].includes(event)) {
          if (path.endsWith('.js')) {
            buildJavaScript(path);
          } else {
            fs.copyFile(path, finalRootPath + path, err => {
              if (err != null) console.log("was unable to copy " + path + " to " + finalRootPath + ": " + err);
            });
          }
        } else if ("unlink" === event) {
          fs.unlink(finalRootPath + path, err => {
            if (err != null) console.log("was unable to delete " + path + ": " + err);
          });
        } else if ("addDir" === event) {
          fs.mkdir(finalRootPath + path, err => {
            if (err != null) console.log("was unable to create dir " + path);
          })
        } else if ("unlinkDir" === event) {
          fs.rmdir(finalRootPath + path, err => {
            if (err != null) console.log("was unable to remove dir " + path);
          })
        }
      });

  // our css also has to update (we're using JIT)
  let css = exec("npx tailwindcss --input=css/main.css --output=../priv/static/css/main.css --postcss --watch");
  css.stdout.on('data', function (data) { console.log(data.toString()) });
  css.stderr.on('data', function (data) { console.log(data.toString()) });
  return;
}
//endregion

//region build all JavaScript files
console.log("building javascript files...");
glob.sync("!(node_modules)/**/*.js").forEach(filePath => buildJavaScript(filePath));
console.log("done!");
//endregion

//region build all CSS files
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
//endregion

//region build all HTML files
if (!buildTemplates) {
  console.log("building html (templates) have been disabled");
} else {
  console.log("building html files...")
  execSync('html-minifier --input-dir ' + templateDir + ' --output-dir ' + finalTemplateDir + ' --file-ext eex --collapse-whitespace --remove-comments --remove-script-type-attributes --remove-tag-whitespace --use-short-doctype --minify-css true --minify-js true')
  console.log("done!");
}
//endregion

// create cache manifest
execSync('mix phx.digest', {cwd: '../'})