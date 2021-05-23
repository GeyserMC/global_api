const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  purge: {
    enabled: true,
    content: [
      './static/**/*.html',
      './static/**/*.js'
    ]
  },
  darkMode: 'media', // or 'media' or 'class' or 'false'
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans]
      }
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
