import OverviewPage from '../svelte/skin/overview/OverviewPage.svelte';

const SKINS_PER_PAGE = 60;

function getPageOrDefault() {
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
        skins_per_page: SKINS_PER_PAGE
    }
}).switchPage(getPageOrDefault());