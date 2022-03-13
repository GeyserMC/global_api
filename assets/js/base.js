import { writable } from 'svelte/store'
import Footer from './svelte/Footer.svelte';

import './news.js'
import './notification.js'

export const urlChange = writable("")

new Footer({
  target: document.getElementById("footer")
})