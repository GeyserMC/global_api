const RemoveFiles = require('remove-files-webpack-plugin');
const glob = require('glob');

module.exports = {
  mount: {
    js: '/js',
    css: '/css',
    html: '/',
    static: { url: "/", static: true, resolve: false }
  },
  buildOptions: {
    out: "../priv/static"
  },
  devOptions: {
    tailwindConfig: './tailwind.config.js'
  },
  plugins: [
    '@snowpack/plugin-postcss',
    [
      '@snowpack/plugin-webpack',
      {
        extendConfig: (config) => {
          config.optimization.runtimeChunk.name = 'runtime';

          // remove unoptimized js files.
          // all optimized js files have a contenthash in their name,
          // the unoptimized files have the same names as the source code variant.
          config.plugins.push(new RemoveFiles({
            after: {
              root: '../priv/static',
              test: [
                {
                  folder: './js',
                  method: (absoluteItemPath) => {
                    const item = absoluteItemPath.replaceAll('\\', '/');
                    const matches = glob.sync('./js/**/*.js').filter(el => {
                      const file = el.substring(1); // .
                      return item.endsWith(file);
                    });
                    return matches.length !== 0;
                  }
                }
              ]
            }
          }));
          return config;
        },
      }
    ]
  ]
}