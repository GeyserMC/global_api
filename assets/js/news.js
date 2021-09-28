const NEWS_CHECK_URL = (window.location.origin.startsWith("http") ? "https://api.geysermc.org" : window.location.origin) + "/assets/news.json"; //todo
let programName = "global_api";
const NEWS_CHECK_INTERVAL = 30 * 60 * 1000; // every 30 mins

// without this function the element breaks with multiple JavaScript files
function news() {
  return document.getElementById("news");
}

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

function ignoreNews(newsId) {
  let ignoredNews = getIgnoredNews();
  if (!ignoredNews.includes(newsId.toString())) {
    ignoredNews.push(newsId);
    const date = new Date();
    date.setTime(date.getTime() + (365*24*60*60*1000));
    document.cookie = "ignored-news=" + ignoredNews.join(':') + "; expires=" + date.toUTCString() + "; path=/";
  }
}

function showNews(newsId, smallTitle, largeTitle, learnMoreUrl) {
  if (!news().classList.contains("hidden")) {
    hideNews(() => showNews(smallTitle, largeTitle, learnMoreUrl));
    return;
  }
  news().dataset.newsId = newsId;
  document.getElementById("news-title-small").innerText = smallTitle;
  document.getElementById("news-title-large").innerText = largeTitle;
  document.getElementById("news-learn-more").href = learnMoreUrl;
  news().classList.remove("hidden");
  setTimeout(() => news().style.transform = "translateY(0%)", 1);
}

news().style.transform = "translateY(150%)";

function checkNews() {
  fetch(NEWS_CHECK_URL, {method: 'get'}).then(async function (response) {
    const json = await response.json();

    const ignoredNews = getIgnoredNews();
    let mostRecentTime = -1;
    let mostRecentTimeItem = null;
    for (i = 0; i < json.length; i++) {
      let current = json[i];
      if (current.active && current.uploaded_at > mostRecentTime && !ignoredNews.includes(current.id.toString())) {
        mostRecentTime = current.uploaded_at;
        mostRecentTimeItem = current;
      }
    }

    if (mostRecentTime !== -1) {
      showNews(mostRecentTimeItem.id, mostRecentTimeItem.small_title, mostRecentTimeItem.large_title, mostRecentTimeItem.learn_more_url);
    }
  }).catch(function (reason) {
    console.log("failed to check news: " + reason)
  })
}

function closeNews() {
  ignoreNews(news().dataset.newsId)
  hideNews()
}

function hideNews(onHidden) {
  news().style.transform = "translateY(150%)";
  setTimeout(() => {
    news().classList.add("hidden");
    if (onHidden != null) onHidden()
  }, 500);
}

function checkNewsLoop() {
  checkNews();
  setTimeout(checkNewsLoop, NEWS_CHECK_INTERVAL);
}

window.addEventListener("load", () => {
  checkNewsLoop();
});