const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  darkMode: 'class',
  content: [
    './js/**/*.js',
    './js/svelte/**/*.svelte',
    '../lib/**/*.html.heex',
    '../lib/**/*_view.ex'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', ...defaultTheme.fontFamily.sans]
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
