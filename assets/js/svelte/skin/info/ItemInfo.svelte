<script>
  import { onMount } from "svelte";
  import { itemInfoUrl, profileInfoUrl } from "../../../misc/endpoints"
  import { CustomModelViewer } from "../../../page/skin/info/modelViewer"
  import Wintersky from "wintersky"
  import { steve, alex, cape } from "../../../misc/model/models"

  export let id;
  export let category;

  let name;
  let geometry;
  let count;
  let sample = []

  let canvas;
  let viewer;

  function capitalize(string) {
    if (!string) return string
    return string.charAt(0).toUpperCase() + string.slice(1)
  }

  function getModel(name, geometry) {
    if (geometry) {
      return geometry
    }
    switch (name) {
      case "steve": return steve
      case "alex": return alex
      case "cape": return cape
      default: throw new Error("invalid model")
    }
  }

  async function retrieveData() {
    // let response = await fetch(itemInfoUrl + category + '/' + id)
    // let json = await response.json()

    let json = {
      model: "alex",
      count: 4,
      sample: [
        {
          id: "d34eb447-6e90-4c78-9281-600df88aef1d",
          name: "Tim203"
        }
      ]
    }

    if (json.error) {
      // most likely skin not found
      throw new Error("error while retrieving item")
    }

    name = json.name
    geometry = getModel(json.model, json.geometry)
    count = json.count
    sample = json.sample
  }

  async function loadPage() {
    try {
      await retrieveData()

      viewer = new CustomModelViewer(
        canvas,
        geometry,
        'https://test.cors.workers.dev/?https://textures.minecraft.net/texture/' + id,
        {
          maxWidth: 500,
          maxHeight: 500,
        }
      )

      await viewer.loadedModel
      viewer.positionCamera()

      const model = viewer.getModel()
      const winterskyScene = new Wintersky.Scene()
      winterskyScene.global_options.loop_mode = 'once'
      winterskyScene.global_options.scale = 16

      model.animator.setupWintersky(winterskyScene)

      setTimeout(() => {
        viewer.requestRendering()
        window.spinner.hide()
      }, 100)
    } catch (e) {
      console.log(e)
      //todo
    }
  }

  onMount(loadPage)

</script>
<div class="w-full flex justify-center items-center flex-col md:flex-row">
  <div id="left-side" class="w-1/2 flex justify-center items-center">
    <div>
      {#if name}
        <h1 class="text-3xl text-gray-200">{name}</h1>
        <h3 class="text-base text-gray-400">Minecraft {capitalize(category)}</h3>
      {:else}
        <h1 class="text-3xl text-gray-200">Minecraft {capitalize(category)}</h1>
      {/if}
      <h3 class="mt-4 text-gray-300">
        {#if count > 0}
        Users with this {category} ({count}):
        {:else}
        There are no users with this {category} :(
        {/if}
      </h3>
      {#each sample as profile}
        <a href={profileInfoUrl + profile.id}>{profile.name}</a>
      {/each}
      <!-- todo add sample -->
    </div>
  </div>
  <canvas bind:this={canvas} class="transparent order-first md:order-last"></canvas>
</div>