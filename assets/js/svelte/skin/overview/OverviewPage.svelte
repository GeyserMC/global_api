<script>
  import SkinEntry from './SkinEntry.svelte';
  import PageButton from './PageButton.svelte';
  import { pageFE, currentPage } from './page.js';
  import { createNotification } from '../../../notification.js';

  export let skinsPerPage;
  export let spinner;

  const RECENTLY_UPLOADED_SKINS = API_BASE_URL + '/v2/skin/recent_uploads/';

  let lastSwitch = 0;
  let totalPages = 0;

  function usePlaceholders() {
    $pageFE = Array(skinsPerPage).fill({loading: true})
  }

  export function switchPage(newPage, switchStart = undefined) {
    spinner.show()
    $currentPage = newPage;
    if (switchStart == undefined) {
      lastSwitch = switchStart = Date.now();
    }

    usePlaceholders()

    const url = new URL(window.location);
    url.searchParams.set("page", newPage);
    window.history.pushState({}, "", url);

    fetch(RECENTLY_UPLOADED_SKINS + "?page=" + newPage)
      .then(res => res.json())
      .then(json => {
        if (json.message) {
          console.log(json.message)
        }

        let data = json.data;
        if (!data || data.length === 0) {
          throw new Error("Empty response?? " + json)
        }

        // make sure that we won't override when there has been a more recent page switch
        if (lastSwitch == switchStart) {
          $pageFE = data;
          totalPages = json.total_pages;
          spinner.hide()
        }
      })
      .catch(err => {
        console.log(err)
        scheduleRetry()
      })
  }

  function scheduleRetry() {
    createNotification("Failed to get skins", "We'll try it again in 30 seconds!", false, null, null, 10_000)
    let start = Date.now();
    let page = $currentPage;
    setTimeout(async () => {
      switchPage(page, start)
    }, 30_000)
  }

  function clickButton(nextPage, element) {
    if ((nextPage && $currentPage + 1 > totalPages) || (!nextPage && $currentPage - 1 < 1)) {
      return;
    }
    console.log(element);
    switchPage($currentPage + (nextPage ? 1 : -1))
  }

  usePlaceholders()
</script>


<div class="flex justify-center mt-10">
  <div class="grid 2xl:grid-cols-7 xl:grid-cols-6 lg:grid-cols-5 md:grid-cols-4 sm:grid-cols-4 grid-cols-2 gap-4 justify-between">
    {#each $pageFE as item}
      <svelte:component this={SkinEntry} {...item} />
    {/each}
  </div>
</div>

<div class="flex w-full justify-center items-center text-gray-800">
  <div class="flex h-10 mt-8 justify-center items-center w-2/4 gap-1.5">
    <button on:click={(element) => clickButton(false, element)} class="px-4 py-1.5 shadow-md cursor-pointer rounded-md bg-gray-200 dark:bg-gray-700 dark:text-gray-300">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
      </svg>
    </button>
    <svelte:component this={PageButton} page_number={1} page_ref={$currentPage} on_click={switchPage} />
    <svelte:component this={PageButton} page_number={totalPages / 2} page_ref={$currentPage} on_click={switchPage} />
    <svelte:component this={PageButton} page_number={totalPages} page_ref={$currentPage} on_click={switchPage} />
    <button on:click={(element) => clickButton(true, element)} class="px-4 py-1.5 shadow-md cursor-pointer rounded-md bg-gray-200 dark:bg-gray-700 dark:text-gray-300">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"/>
      </svg>
    </button>
  </div>
</div>
