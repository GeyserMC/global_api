const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  mode: 'jit',
  purge: {
    enabled: process.env.NODE_ENV === 'production',
    content: [
      './html/**/*.html',
      './js/**/*.js',
      '../lib/**/*.html.eex',
      '../lib/**/*_view.ex'
    ]
  },
  darkMode: 'class',
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans]
      }
    },
  },
  variants: {
    extend: {
      borderWidth: ['dark'],
      boxShadow: ['dark']
    },
  },
  plugins: [],
}
