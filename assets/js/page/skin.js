const SKINS_PER_PAGE = 60;
let currentPage = -1;

const BASE_URL = (window.location.origin.startsWith("https") ? "https://api.geysermc.org" : window.location.origin);
const RECENTLY_UPLOADED_SKINS = BASE_URL + "/v2/skin/recent_uploads/";
const RECENTLY_UPDATED_PLAYERS = BASE_URL + "/v2/skin/recent_uploads/";

// allows us to maintain the user's scroll position
window.addEventListener('DOMContentLoaded', preInit);

function preInit() {
    let template = document.querySelector('#skin-base-template');
    let skinGrid = document.querySelector('#skin-grid');

    // we need to replace the elements if the user decides to switch pages
    let replace = skinGrid.childElementCount > 0;

    for (let i = 0; i < SKINS_PER_PAGE; i++) {
        let clone = template.cloneNode(true);
        clone.removeAttribute('id');
        clone.classList.remove('hidden');

        if (replace) {
            skinGrid.replaceChild(clone, skinGrid.childNodes[i])
        } else {
            skinGrid.appendChild(clone);
        }
    }
}

function init() {
    const queryParams = new URLSearchParams(window.location.search);
    let page = parseInt(queryParams.get("page"));
    if (isNaN(page)) {
        switchPage(1);
        return;
    }

    requestAndSetAccounts(page, function (pageCount) {
        setPageButtons(page, pageCount)
    });
}

function setPageButtons(page, pageCount) {
    setActionButton('#action-previous-page', page > 1 ? page - 1 : -1);
    setActionButton('#action-next-page', page < pageCount ? page + 1 : -1);

    setPageButton('#skin-page-min', 1, page === 1);
    setPageButton('#skin-page-half', pageCount / 2, page === (pageCount / 2));
    setPageButton('#skin-page-max', pageCount, page === pageCount);
}

function setPageButton(queryName, value, active) {
    let button = document.querySelector(queryName);
    button.innerText = value;
    let classList = button.classList;
    const activeClasses = ['bg-white', 'dark:bg-gray-600', 'cursor-not-allowed'];
    const inactiveClasses = ['bg-gray-200', 'dark:bg-gray-700', 'cursor-pointer'];
    if (active) {
        classList.add(...activeClasses);
        classList.remove(...inactiveClasses.concat('cursor-wait'));
    } else {
        classList.add(...inactiveClasses);
        classList.remove(...activeClasses.concat('cursor-wait'));
    }
    button.onclick = () => switchPage(value);
}

function setActionButton(queryName, nextPage) {
    let current = document.querySelector(queryName);

    current.classList.forEach(function (value) {
        if (value.startsWith("cursor")) {
            current.classList.remove(value)
        }
    });

    if (nextPage !== -1) {
        current.onclick = function() {
            switchPage(nextPage)
        }
        current.classList.add("cursor-pointer")
    } else {
        current.onclick = function() {}
        current.classList.add("cursor-not-allowed")
    }
}

function switchPage(newPage) {
    currentPage = newPage;

    const url = new URL(window.location);
    url.searchParams.set('page', newPage);
    window.history.pushState({}, '', url);

    // replace the current skins with the skeleton loaders
    preInit();
    // try to load the new skins
    init();
}

function requestAndSetAccounts(page, onComplete) {
    fetch(RECENTLY_UPLOADED_SKINS + "?page=" + page)
        .then(response => response.json())
        .then(json => {
            if (json.message) {
                console.log("got a message while requesting gamertags: " + json.message)
            }

            if (!json.data || json.data.length === 0) {
                return;
            }

            const template = document.getElementById('skin-template');
            const skinGrid = document.getElementById('skin-grid');

            // slow response, user is at the next page already
            if (currentPage !== -1 && currentPage !== page) {
                return;
            }

            let i = 0;
            json.data.forEach(entry => {
                const clone = template.cloneNode(true);
                clone.removeAttribute('id');
                clone.classList.remove('hidden');

                clone.getElementsByClassName('skin-image')[0].setAttribute('src', 'https://mc-heads.net/player/' + entry.texture_id);
                const nameAndDetail = clone.querySelectorAll('[data-detail-page]')[0];
                nameAndDetail.dataset.detailPage = entry.texture_id;
                nameAndDetail.innerText = "#" + entry.id;

                // replace the skeleton loader with the actual skin
                skinGrid.replaceChild(clone, skinGrid.childNodes[i++]);
            });

            if (onComplete != null) {
                onComplete(json.total_pages);
            }

        }).catch(function (reason) {
        console.error("Failed to get most recent skins!")
        console.error(reason);

        createNotification("Failed to get skins", "We'll try it again in 30 seconds!", false, null, null, 10_000)
        setTimeout(() => {
            if (page === currentPage || currentPage === -1) {
                init();
            }
        }, 30_000)
    })
}

init();