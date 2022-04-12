<script>
  import { urlChange } from "../../base.js";

  export let url;
  export let title;
  export let clickAction;

  let active = calcActive();

  function calcActive() {
    return window.location.pathname === url;
  }

  urlChange.subscribe(() => {
    active = calcActive();
  });
</script>

<span
  on:click={() => {
    if (!active) clickAction();
  }}
  class="block px-3 py-2 rounded-md text-sm font-medium {active
    ? 'text-gray-900 dark:text-white bg-gray-200 dark:bg-gray-700 cursor-default'
    : 'text-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-800 cursor-pointer transition-colors duration-200 transform dark:hover:text-white'}"
  >
  {title}
</span>
