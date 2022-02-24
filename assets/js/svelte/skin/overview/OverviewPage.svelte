<script>
  import { RECENTLY_UPLOADED_SKINS } from '../../../constants.js';

  import SkinEntry from './SkinEntry.svelte';
  import PageButton from './PageButton.svelte';
  import { pageFE, current_page } from './page.js';
  import { createNotification } from '../../../notification.js';

  export let skins_per_page;

  let last_switch = 0;
  let total_pages = 0;

  function usePlaceholders() {
    $pageFE = Array(skins_per_page).fill({loading: true})
  }

  export function switchPage(newPage, switch_start = undefined) {
    $current_page = newPage;
    if (switch_start == undefined) {
      last_switch = switch_start = Date.now();
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
        if (last_switch == switch_start) {
          $pageFE = data;
          total_pages = json.total_pages;
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
    let page = $current_page;
    setTimeout(async () => {
      switchPage(page, start)
    }, 30_000)
  }

  function clickButton(next_page, element) {
    if ((next_page && $current_page + 1 > total_pages) || (!next_page && $current_page - 1 < 1)) {
      return;
    }
    console.log(element);
    switchPage($current_page + (next_page ? 1 : -1))
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
    <svelte:component this={PageButton} page_number={1} page_ref={$current_page} on_click={switchPage} />
    <svelte:component this={PageButton} page_number={total_pages / 2} page_ref={$current_page} on_click={switchPage} />
    <svelte:component this={PageButton} page_number={total_pages} page_ref={$current_page} on_click={switchPage} />
    <button on:click={(element) => clickButton(true, element)} class="px-4 py-1.5 shadow-md cursor-pointer rounded-md bg-gray-200 dark:bg-gray-700 dark:text-gray-300">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"/>
      </svg>
    </button>
  </div>
</div>
