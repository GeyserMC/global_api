import { writable, get } from 'svelte/store';
import NewsItem from './svelte/news/NewsItem.svelte';

const NEWS_CHECK_URL = API_BASE_URL + '/v2/news/' + PROGRAM_NAME;
const NEWS_CHECK_INTERVAL = 30 * 60 * 1000; // every 30 mins
const COOKIE_DURATION = 365 * 24 * 60 * 60 * 1000; // a year

let item = writable(undefined);

function getIgnoredNews() {
  let Cookies = document.cookie.split(';');
  for (let i = 0; i < Cookies.length; i++) {
    let cookie = Cookies[i];
    while (cookie.charAt(0) === ' ') {
      cookie = cookie.substring(1);
    }
    if (cookie.startsWith('ignored-news')) {
      // ignored-news=
      return cookie.substring(13).split(':');
    }
  }
  return [];
}

export function ignoreNews(newsId) {
  let ignoredNews = getIgnoredNews();
  if (!ignoredNews.includes(newsId.toString())) {
    ignoredNews.push(newsId);
    const date = new Date();
    date.setTime(date.getTime() + COOKIE_DURATION);
    document.cookie = "ignored-news=" + ignoredNews.join(':') + "; expires=" + date.toUTCString() + "; path=/";
  }
}

function checkNews() {
  fetch(NEWS_CHECK_URL, {method: 'get'})
    .then(async function (response) {
      const json = await response.json();

      const ignoredNews = getIgnoredNews();
      let mostRecentId = -1;
      let mostRecentTimeItem = null;
      for (let i = 0; i < json.length; i++) {
        let current = json[i];
        if (current.active && current.id > mostRecentId && !ignoredNews.includes(current.id.toString())) {
          mostRecentId = current.id;
          mostRecentTimeItem = current;
        }
      }

      if (mostRecentId !== -1) {
        let [smallTitle, largeTitle] = newsMapping(mostRecentTimeItem.message);
        setNewsProperties(mostRecentTimeItem.id, smallTitle, largeTitle, mostRecentTimeItem.url);
        get(item).showItem()
      }
    }).catch(function (reason) {
      console.log("failed to check news: " + reason)
    })
}

function setNewsProperties(id, small_title, large_title, learn_more_url) {
  var news = get(item)
  if (!news) {
    news = new NewsItem({target: document.getElementById("news")})
    item.set(news)
  }
  news.setContent(id, small_title, large_title, learn_more_url);
}

function newsMapping(message) {
  let part;
  switch (message.id) {
    case 4: part = "soon"; break;
    case 5: part = "starting " + message.args[1]; break;
    case 6: part = "from " + message.args[1] + " till " + message.args[2]; break;
    default: return null;
  }
  return ["Website maintenance " + part, "The website is temporarily going down for maintenance " + part];
}

function checkNewsLoop() {
  checkNews();
  setTimeout(checkNewsLoop, NEWS_CHECK_INTERVAL);
}

window.addEventListener("load", checkNewsLoop);