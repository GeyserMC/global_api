import OverviewPage from '../../svelte/skin/overview/OverviewPage.svelte';
import Spinner from '../../svelte/Spinner.svelte';
import Navbar from '../../svelte/Navbar.svelte';
import { getPageByPath } from './page';

function getPage() {
  return getPageByPath(window.location.pathname)
}

function getPageNumber() {
  const params = new URLSearchParams(window.location.search);
  let page = parseInt(params.get("page"))
  if (isNaN(page) || page < 1) {
    return 1;
  }
  return page;
}

let spinner = new Spinner({
  target: document.getElementById("spinner")
})
spinner.show()

new Navbar({
  target: document.getElementById("navbar")
})

new OverviewPage({
  target: document.getElementById("overview"),
  props: {
    spinner,
    ...getPage()
  }
}).switchPage(getPageNumber());