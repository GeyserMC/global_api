<script context="module">
  import { fly } from 'svelte/transition';

  let latestNotificationId = -1;
  let notificationQueue = [];

  let title;
  let description;
  let leftButtonName;
  let leftButtonLink;
  let success;

  let shown = false;
  let callback;

  export function createNotification(title, description, success, leftButtonName, leftButtonLink, duration) {
    if (notificationQueue.length === 0 && !shown) {
      showNotification(title, description, success, leftButtonName, leftButtonLink, duration)
    } else {
      notificationQueue.push([title, description, success, leftButtonName, leftButtonLink, duration])
    }
  }

  export function closeNotification(finishCallback) {
    shown = false;
    callback = finishCallback;
  }

  function showNext() {
    if (callback) {
      let finishCallback = callback
      callback = null
      finishCallback()
      return;
    }

    const nextNotification = notificationQueue.shift()
    if (nextNotification) {
      showNotification.apply(null, nextNotification)
    }
  }

  function showNotification(newTitle, newDescription, newSuccess, newLeftButtonName, newLeftButtonLink, duration) {
    if (shown) {
      closeNotification(() => showNotification.apply(null, arguments))
      return;
    }

    title = newTitle
    description = newDescription
    success = newSuccess
    leftButtonName = newLeftButtonName
    leftButtonLink = newLeftButtonLink

    shown = true
    latestNotificationId++

    if (duration) {
      const notificationId = latestNotificationId
      setTimeout(() => {
        // it's possible that the notification has been closed already by the time the duration is over
        if (latestNotificationId === notificationId) {
          closeNotification()
        }
      }, duration)
    }
  }
</script>


{#if shown}
  <div
    class="xl:w-4/12 mx-auto sm:mx-0 sm:w-6/12 md:w-2/5 w-11/12 bg-white dark:bg-gray-900 shadow-lg rounded flex sm:flex-row flex-col pr-4 fixed left-0 sm:left-auto right-0 sm:top-0 sm:mt-6 top-4 sm:mr-6 z-30"
    role="alert"
    transition:fly={{x: 500, duration: 150}}
    on:outroend={showNext}
  >
    <div tabindex="0" role="img" class="focus:outline-none sm:px-6 px-4 mt-4 sm:mt-0 flex items-center sm:justify-center dark:border-gray-700 border-gray-300">
      {#if success}
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="40" height="40" fill="currentColor" class="text-green-700" aria-label="success icon">
        <path d="M12 22a10 10 0 1 1 0-20 10 10 0 0 1 0 20zm0-2a8 8 0 1 0 0-16 8 8 0 0 0 0 16zm-2.3-8.7l1.3 1.29 3.3-3.3a1 1 0 0 1 1.4 1.42l-4 4a1 1 0 0 1-1.4 0l-2-2a1 1 0 0 1 1.4-1.42z" />
      </svg>
      {:else}
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" class="text-red-700" aria-label="failed icon">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      {/if}
    </div>
    <div class="flex flex-col justify-center pl-4 md:pl-0 sm:w-9/12 py-3">
      <p tabindex="0" class="focus:outline-none text-lg text-gray-800 dark:text-gray-100 font-semibold pb-1">{title}</p>
      <p tabindex="0" class="focus:outline-none text-sm text-gray-600 dark:text-gray-400 font-normal pb-2">{description}</p>
      <div class="flex gap-3">
        <span on:click={leftButtonLink} tabindex="0" class="{success ? "text-green-700 dark:text-green-600" : "text-gray-600"} focus:outline-none text-sm hover:underline font-bold cursor-pointer">{leftButtonName}</span>
        <span on:click={() => closeNotification()} tabindex="0" class="focus:outline-none focus:text-gray-400 text-sm text-gray-600 hover:underline dark:text-gray-400 cursor-pointer">Dismiss</span>
      </div>
    </div>
  </div>
{/if}