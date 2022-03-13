import { writable } from 'svelte/store';
export let pageFE = writable([]);
export let currentPage = writable(1);
export let totalPages = writable(0);