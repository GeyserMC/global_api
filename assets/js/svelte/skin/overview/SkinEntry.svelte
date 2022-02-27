<script>
  export let id;
  export let texture_id;
  export let loading;

  const SKIN_PREVIEW_BASE = 'https://mc-heads.net/player/';
  const SKIN_PAGE = '/skin/';

  function handleClick() {
    window.location = SKIN_PAGE + texture_id
  }
</script>

<div on:click={handleClick} class="flex flex-col items-center justify-center w-32 h-48 md:w-40 md:h-60 mx-auto {loading ? "animate-pulse" : ""}" id="skin-template">
  <div class="w-32 h-48 md:w-40 md:h-60 bg-gray-200 dark:bg-gray-700 rounded-lg flex justify-center items-center {loading ? "shadow-sm" : "shadow-md"}">
    {#if loading}
      <div class="w-auto h-4/5 pointer-events-none skin-image"></div>
    {:else}
      <img class="w-auto h-4/5 pointer-events-none render-pixelated skin-image" src="{SKIN_PREVIEW_BASE + texture_id}" loading="lazy" alt="skin of a player"/>
    {/if}
  </div>
  <div class="w-28 md:w-36 -mt-12 overflow-hidden bg-white rounded-lg dark:bg-gray-800 {!loading ? "shadow-lg" : ""}">
    <div class="py-2 font-semibold tracking-wide text-center text-xs md:text-sm text-gray-800 dark:text-gray-200 {loading ? "flex items-center justify-center": ""}" data-detail-page="">
      {#if loading}
        <span class="bg-gray-300 dark:bg-gray-700 w-3/4 rounded-sm h-2.5 my-1.5 text-transparent">.</span>
      {:else}
        #{id}
      {/if}
    </div>
  </div>
</div>