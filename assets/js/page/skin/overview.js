import OverviewPage from '../../svelte/skin/overview/OverviewPage.svelte';
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

new OverviewPage({
  target: document.getElementById("overview"),
  props: {
    spinner: window.spinner,
    ...getPage()
  }
}).switchPage(getPageNumber());