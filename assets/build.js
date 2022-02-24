const { build } = require('esbuild')
const sveltePlugin = require('esbuild-svelte')

const args = process.argv.slice(2)
const watch = args.includes('--watch')
const deploy = args.includes('--deploy')
const apiBase = args.find(element => element.startsWith("--api-base-url="))?.split("=", 2)[1] ?? "http://api.geysermc"

const loader = {
  // Add loaders for images/fonts/etc, e.g. { '.svg': 'file' }
}

const plugins = [
    sveltePlugin()
]

let opts = {
  entryPoints: ['js/base.js', 'js/page/skin.js', 'js/page/online.js'],
  bundle: true,
  target: 'es2017',
  format: 'esm',
  splitting: true,
  outdir: '../priv/static/js',
  define: {
    'CLIENT_ID': '"dad9257f-6b54-4509-8463-81286ee5860d"',
    'API_BASE_URL': '"'+ apiBase + '"'
  },
  logLevel: 'info',
  loader,
  plugins
}

if (watch) {
  opts = {
    ...opts,
    watch,
    sourcemap: 'inline'
  }
}

if (deploy) {
  opts = {
    ...opts,
    minify: true
  }
}

const promise = build(opts)

if (watch) {
  promise.then(_result => {
    process.stdin.on('close', () => {
      process.exit(0)
    })

    process.stdin.resume()
  })
}
