import { writable } from 'svelte/store';
export let pageFE = writable([]);
export let current_page = writable(1);