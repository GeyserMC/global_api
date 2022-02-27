import OverviewPage from '../../svelte/skin/overview/OverviewPage.svelte';
import Spinner from '../../svelte/Spinner.svelte';

const SKINS_PER_PAGE = 60;

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

new OverviewPage({
  target: document.getElementById("overview"),
  props: {
    skinsPerPage: SKINS_PER_PAGE,
    spinner
  }
}).switchPage(getPageNumber());
