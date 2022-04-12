<script>
  import { onMount } from 'svelte';
  import { fly } from 'svelte/transition';

  const NEWS_CHECK_URL = API_BASE_URL + '/news/' + PROGRAM_NAME;
  const NEWS_CHECK_INTERVAL = 30 * 60 * 1000; // every 30 mins

  let id;
  let smallTitle;
  let largeTitle;
  let learnMoreUrl;

  let shown = false;
  let storedCallback;

  function showItem() {
    if (shown) {
      hideItem(showItem);
      return;
    }
    shown = true;
  }

  function hideItem(callback) {
    if (!shown) {
      if (callback != null) callback()
    }

    storedCallback = callback;
    shown = false;
  }

  function closeItem() {
    ignoreNews(id)
    hideItem()
  }

  function callCallback() {
    if (storedCallback != null) {
      let call = storedCallback
      storedCallback = null;
      call()
    }
  }

  function getIgnoredNews() {
    let ignored = localStorage.getItem('ignored-news')
    return ignored ? JSON.parse(ignored) : []
  }

  function ignoreNews(newsId) {
    let ignoredNews = getIgnoredNews();
    if (!ignoredNews.includes(newsId)) {
      ignoredNews.push(newsId);
      localStorage.setItem('ignored-news', JSON.stringify(ignoredNews))
    }
  }

  //todo remove this in the future
  function newsMapping(message) {
    let part;
    switch (message.id) {
      case 4: part = "soon"; break;
      case 5: part = "starting " + message.args[1]; break;
      case 6: part = "from " + message.args[1] + " till " + message.args[2]; break;
      default: return null;
    }
    return ["Website maintenance " + part, "The website is temporarily going down for maintenance " + part]
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
          if (current.active && current.id > mostRecentId && !ignoredNews.includes(current.id)) {
            mostRecentId = current.id;
            mostRecentTimeItem = current;
          }
        }

        if (mostRecentId !== -1) {
          let [sTitle, lTitle] = newsMapping(mostRecentTimeItem.message);

          id = mostRecentTimeItem.id;
          smallTitle = sTitle;
          largeTitle = lTitle;
          learnMoreUrl = mostRecentTimeItem.url;

          showItem()
        }
      }).catch(function (reason) {
        console.log("failed to check news: " + reason)
      })
  }

  onMount(() => {
    checkNews()
    setInterval(checkNews, NEWS_CHECK_INTERVAL)
  })
</script>

{#if shown}
  <div 
    class="bg-indigo-600 fixed bottom-0 right-0 w-full"
    transition:fly={{y: 200, duration: 250}} 
    on:outroend={callCallback}
  >
    <div class="max-w-7xl mx-auto py-3 px-3 sm:px-6 lg:px-8">
      <div class="flex items-center justify-between flex-wrap">
        <div class="w-0 flex-1 flex items-center">
        <span class="flex p-2 rounded-lg bg-indigo-800">
          <!-- Heroicon name: outline/speakerphone -->
          <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z" />
          </svg>
        </span>
          <p class="ml-3 font-medium text-white truncate">
            <span class="md:hidden">{smallTitle}</span>
            <span class="hidden md:inline">{largeTitle}</span>
          </p>
        </div>
        <div class="order-3 mt-2 flex-shrink-0 w-full sm:order-2 sm:mt-0 sm:w-auto">
          <a href={learnMoreUrl} class="flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-indigo-600 bg-white hover:bg-indigo-50">
            Learn more
          </a>
        </div>
        <div class="order-2 flex-shrink-0 sm:order-3 sm:ml-3">
          <button on:click={closeItem} type="button" class="-mr-1 flex p-2 rounded-md hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-white sm:-mr-2">
            <span class="sr-only">Dismiss</span>
            <!-- Heroicon name: outline/x -->
            <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}