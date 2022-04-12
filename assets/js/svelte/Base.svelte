<script>
  import Spinner from "./Spinner.svelte";
  import Navbar from "./Navbar.svelte";
  import { onMount } from "svelte";

  export let spinner;
  export let navbar;

  onMount(() => {
    spinner?.show()
  })
</script>
<Spinner bind:this={spinner}/>
<Navbar bind:this={navbar}/>