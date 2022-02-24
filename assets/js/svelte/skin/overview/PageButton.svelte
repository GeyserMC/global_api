<script>
  export let page_number;
  export let page_ref;
  export let on_click;
</script>

<div
  on:click={page_number != page_ref ? () => on_click(page_number) : undefined}
  class="px-4 py-2 shadow-md rounded-md dark:text-gray-300 {page_number == page_ref
    ? 'bg-white dark:bg-gray-600 cursor-not-allowed'
    : 'bg-gray-200 dark:bg-gray-700 cursor-pointer'}">
  {page_number}
</div>
