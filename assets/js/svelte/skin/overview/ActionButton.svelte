<script>
  import { currentPage, totalPages } from './page.js';

  export let clickAction;
  export let switchPage;
  export let svgPathData;

  let hasNext;

  [currentPage, totalPages].forEach(sub => {
    sub.subscribe(_ => {
      hasNext = calcNext()
    })
  })

  function calcNext() {
    const nextPage = clickAction > 0;
    return !((nextPage && ($currentPage + clickAction) > $totalPages) || (!nextPage && ($currentPage + clickAction) < 1))
  }

  function handleClick() {
    if (hasNext) {
      switchPage($currentPage + clickAction)
    }
  }
</script>

<button on:click={handleClick} class="px-4 py-1.5 shadow-md rounded-md dark:text-gray-300 bg-gray-200 dark:bg-gray-700 {hasNext ? "cursor-pointer" : "cursor-not-allowed"}">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="{svgPathData}"/>
  </svg>
</button>