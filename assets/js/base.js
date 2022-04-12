import { writable } from 'svelte/store'
import Footer from './svelte/Footer.svelte';
import Notification from './svelte/Notification.svelte';
import NewsItem from './svelte/news/NewsItem.svelte';

export const urlChange = writable()

new Footer({
  target: document.getElementById("footer")
})

replaceTarget(Notification, document.getElementById("notification"))

new NewsItem({
  target: document.getElementById("news")
})

function replaceTarget(clazz, target) {
  new clazz({
    target: target.parentElement,
    anchor: target
  })
  target.remove()
}

export function pushState(url) {
  const fullUrl = new URL(url, location.origin)
  if (fullUrl != location.toString()) {
    history.pushState({}, "", fullUrl)
    window.dispatchEvent(new Event('popstate'))
  }
}

export function replaceState(url) {
  const fullUrl = new URL(url, location.origin)
  // technically we only need to place the event in the 'if'
  if (fullUrl != location.toString()) {
    history.replaceState({}, "", fullUrl)
    window.dispatchEvent(new Event('popstate'))
  }
}

window.addEventListener('popstate', () => {
  urlChange.set("pop:" + Date.now())
})