module.exports = {
  plugins: {
    'postcss-import': {},
    'postcss-url': { url: 'copy' },
    tailwindcss: {},
    autoprefixer: {},
    ...(process.env.NODE_ENV === 'production' ? { cssnano: {} } : {})
  }
}