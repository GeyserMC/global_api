<script>
  import { currentPage } from './page.js';

  export let pageNumber;
  export let onClick;

  function handleClick() {
    if (pageNumber != $currentPage) {
      onClick(pageNumber)
    }
  }
</script>

<div
  on:click={handleClick}
  class="px-4 py-2 shadow-md rounded-md dark:text-gray-300 {pageNumber == $currentPage
    ? 'bg-white dark:bg-gray-600 cursor-not-allowed'
    : 'bg-gray-200 dark:bg-gray-700 cursor-pointer'}">
  {pageNumber}
</div>
