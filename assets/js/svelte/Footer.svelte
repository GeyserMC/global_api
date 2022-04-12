<script>
  import { onMount } from "svelte";

  const geyserBaseUrl = GEYSER_BASE_URL

  export let content = {
    cols: [
      [
        {
          name: "Placeholder #1",
          link: "javascript:void(0)"
        },
        {
          name: "Placeholder #2",
          link: "javascript:void(0)"
        },
        {
          name: "Placeholder #3",
          link: "javascript:void(0)"
        },
        {
          name: "Placeholder #4",
          link: "javascript:void(0)"
        },
        {
          name: "Placeholder #5",
          link: "javascript:void(0)"
        },
      ],
      [
        {
          name: "Skins",
          url: "https://skin.geysermc.org/"
        },
        {
          name: "Global Linking",
          url: "https://link.geysermc.org/"
        },
        {
          name: "GeyserMC home page",
          url: "https://geysermc.org/"
        },
      ],
      [
        {
          name: "Placeholder #9",
          url: "javascript:void(0)"
        },
        {
          name: "Placeholder #10",
          url: "javascript:void(0)"
        },
      ]
    ]
  }
  let selectedTheme;

  function switchMode() {
    setTheme(selectedTheme)
  }

  function setTheme(mode) {
    if (mode == "light" || mode == "dark") {
      useTheme(mode == "dark")
      localStorage.setItem("theme", mode)
    } else {
      chooseTheme()
      localStorage.removeItem("theme")
    }
    // without this, the value shown in the theme selecter wouldn't be equal to the
    // actual selected theme (when reloading the page/switching to a different page).
    selectedTheme = mode
  }

  function chooseTheme() {
    useTheme(!(matchMedia && matchMedia("(prefers-color-scheme: light)").matches))
  }

  function useTheme(dark) {
    if (dark) {
      document.documentElement.classList.remove("light")
      document.documentElement.classList.add("dark")
    } else {
      document.documentElement.classList.remove("dark")
      document.documentElement.classList.add("light")
    }
  }

  onMount(() => {
    setTheme(localStorage.getItem("theme") || "auto")

    matchMedia("(prefers-color-scheme: light)").addEventListener("change", () => {
      if (selectedTheme == "auto")
        setTheme("auto")
    })
  })
</script>

<!-- thanks to Tailwind UI kit -->
<footer id="footer" class="relative bg-white dark:bg-gray-900 mt-12">
  <div tabindex="0" aria-label="footer" class="focus:outline-none border-t border-b border-gray-200 dark:border-gray-700 py-16">
    <div class="mx-auto container px-4 xl:px-12 2xl:px-4">
      <div class="lg:flex">
        <div class="w-full lg:w-1/2 mb-16 lg:mb-0 flex">
          <div class="w-full lg:w-1/2 px-6">
            <ul class="flex flex-col gap-6">
              {#each content.cols[0] as item}
                <li><a href={item.link} class="focus:outline-none focus:underline text-xs lg:text-sm leading-none hover:text-brand dark:hover:text-brand text-gray-800 dark:text-gray-50">{item.name}</a></li>
              {/each}
            </ul>
          </div>
          <div class="w-full lg:w-1/2 px-6">
            <ul class="flex flex-col gap-6">
              {#each content.cols[1] as item}
                <li><a href={item.link} class="focus:outline-none focus:underline text-xs lg:text-sm leading-none hover:text-brand dark:hover:text-brand text-gray-800 dark:text-gray-50">{item.name}</a></li>
              {/each}
            </ul>
          </div>
        </div>
        <div class="w-full lg:w-1/2 flex">
          <div class="w-full lg:w-1/2 px-6">
            <ul class="flex flex-col gap-6">
              {#each content.cols[2] as item}
                <li><a href={item.link} class="focus:outline-none focus:underline text-xs lg:text-sm leading-none hover:text-brand dark:hover:text-brand text-gray-800 dark:text-gray-50">{item.name}</a></li>
              {/each}
            </ul>
          </div>
          <div class="w-full lg:w-1/2 px-6 flex flex-col justify-between">
            <div class="flex items-center mb-6">
              <a aria-label="Github" href="https://github.com/GeyserMC">
                <div class="text-gray-800 dark:text-gray-50 cursor-pointer hover:text-brand dark:hover:text-brand">
                  <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"></path>
                  </svg>
                </div>
              </a>
              <a aria-label="Twitter" href="https://twitter.com/geyser_mc" class="ml-4">
                <div class="text-gray-800 dark:text-gray-50 cursor-pointer hover:text-brand dark:hover:text-brand">
                  <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M23 3a10.9 10.9 0 0 1-3.14 1.53 4.48 4.48 0 0 0-7.86 3v1A10.66 10.66 0 0 1 3 4s-4 9 5 13a11.64 11.64 0 0 1-7 2c9 5 20 0 20-11.5a4.5 4.5 0 0 0-.08-.83A7.72 7.72 0 0 0 23 3z"></path>
                  </svg>
                </div>
              </a>
              <!--todo add discord icon-->
            </div>
            <div class="relative w-36">
              {#if selectedTheme == "light"}
                <svg xmlns="http://www.w3.org/2000/svg" class="absolute inset-0 m-auto ml-3 text-gray-700 dark:text-gray-50 icon icon-tabler icon-tabler-brightness-up" width="20" height="20" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" fill="none" stroke-linecap="round" stroke-linejoin="round">
                  <path stroke="none" d="M0 0h24v24H0z" fill="none"></path>
                  <circle cx="12" cy="12" r="3"></circle>
                  <line x1="12" y1="5" x2="12" y2="3"></line>
                  <line x1="17" y1="7" x2="18.4" y2="5.6"></line>
                  <line x1="19" y1="12" x2="21" y2="12"></line>
                  <line x1="17" y1="17" x2="18.4" y2="18.4"></line>
                  <line x1="12" y1="19" x2="12" y2="21"></line>
                  <line x1="7" y1="17" x2="5.6" y2="18.4"></line>
                  <line x1="6" y1="12" x2="4" y2="12"></line>
                  <line x1="7" y1="7" x2="5.6" y2="5.6"></line>
                </svg>
              {:else if selectedTheme == "dark"}
                <svg xmlns="http://www.w3.org/2000/svg" class="absolute inset-0 m-auto ml-3 text-gray-700 dark:text-gray-50 icon icon-tabler icon-tabler-moon" width="20" height="20" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" fill="none" stroke-linecap="round" stroke-linejoin="round">
                  <path stroke="none" d="M0 0h24v24H0z" fill="none"></path>
                  <path d="M12 3c.132 0 .263 0 .393 0a7.5 7.5 0 0 0 7.92 12.446a9 9 0 1 1 -8.313 -12.454z"></path>
                </svg>
              {:else}
                <svg xmlns="http://www.w3.org/2000/svg" class="absolute inset-0 m-auto ml-3 text-gray-700 dark:text-gray-50 icon icon-tabler icon-tabler-device-laptop" width="20" height="20" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" fill="none" stroke-linecap="round" stroke-linejoin="round">
                  <path stroke="none" d="M0 0h24v24H0z" fill="none"></path>
                  <line x1="3" y1="19" x2="21" y2="19"></line>
                  <rect x="5" y="6" width="14" height="10" rx="1"></rect>
                </svg>
              {/if}

              <svg xmlns="http://www.w3.org/2000/svg" class="pointer-events-none absolute inset-0 m-auto mr-3 text-gray-700 dark:text-gray-50 icon icon-tabler icon-tabler-chevron-down" width="16" height="16" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" fill="none" stroke-linecap="round" stroke-linejoin="round">
                <path stroke="none" d="M0 0h24v24H0z" fill="none"></path>
                <polyline points="6 9 12 15 18 9"></polyline>
              </svg>
              <select bind:value={selectedTheme} on:change={switchMode} class="w-full focus:ring-2 focus:ring-offset-2 focus:ring-gray-500 focus:outline-none pl-10 py-2 appearance-none flex items-center h-12 border rounded border-gray-700 dark:border-gray-50 text-sm leading-5 dark:bg-gray-900 dark:text-gray-50">
                <option selected="" value="auto">Auto</option>
                <option value="light">Light</option>
                <option value="dark">Dark</option>
              </select>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
  <div class="py-16 flex flex-col justify-center items-center">
    <a class="focus:outline-none" tabindex="0" aria-label="home link" href="{geyserBaseUrl}">
      <img src="https://geysermc.org/img/geyser.png" width="344" height="232" alt="GeyserMC logo (wide)">
    </a>
    <p tabindex="0" class="focus:outline-none mt-6 text-xs lg:text-sm leading-none text-gray-900 dark:text-gray-50">2021 - 2022 GeyserMC. All Rights Reserved.</p>
  </div>
</footer>