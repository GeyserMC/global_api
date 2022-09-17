let plugin = require('tailwindcss/plugin')
const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  darkMode: 'class',
  content: [
    './js/**/*.js',
    './js/svelte/**/*.svelte',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex'
  ],
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
  plugins: [
    require('@tailwindcss/forms'),
    plugin(({addVariant}) => {
      addVariant('phx-no-feedback', ['&.phx-no-feedback', '.phx-no-feedback &'])
      addVariant('phx-click-loading', ['&.phx-click-loading', '.phx-click-loading &'])
      addVariant('phx-click-loading-any', '*:has(.phx-click-loading) &')
      addVariant('phx-submit-loading', ['&.phx-submit-loading', '.phx-submit-loading &'])
      addVariant('phx-change-loading', ['&.phx-change-loading', '.phx-change-loading &'])
    }),
  ],
}
