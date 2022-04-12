import ItemInfo from "../../svelte/skin/info/ItemInfo.svelte"
import Navbar from "../../svelte/Navbar.svelte"

function getRequiredInfo() {
  let path = location.pathname
  if (path.endsWith("/")) path = path.slice(0, -1)
  let sections = path.split("/").slice(-2)

  return {
    id: sections[1],
    category: sections[0]
  }
}

new ItemInfo({
  target: document.getElementById('content'),
  props: getRequiredInfo()
})