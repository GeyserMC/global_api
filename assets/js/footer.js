const Auto = document.getElementById("auto");
const Light = document.getElementById("light");
const Dark = document.getElementById("dark");

const switchMode = (event) => {
  setTheme(event.target.value)
};

function setTheme(mode) {
  switch (mode) {
    case "auto":
      Auto.classList.remove("hidden");
      Light.classList.add("hidden");
      Dark.classList.add("hidden");
      chooseTheme();
      localStorage.removeItem('theme');
      break;
    case "light":
      Auto.classList.add("hidden");
      Light.classList.remove("hidden");
      Dark.classList.add("hidden");
      useTheme(false)
      localStorage.setItem('theme', 'light');
      break;
    case "dark":
      Auto.classList.add("hidden");
      Light.classList.add("hidden");
      Dark.classList.remove("hidden");
      useTheme(true)
      localStorage.setItem('theme', 'dark');
      break;
    default:
      return;
  }
  document.querySelector('[aria-label="select box"]').value = mode;
}

function chooseTheme() {
  useTheme(!(window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches))
}

function useTheme(dark) {
  if (dark) {
    document.documentElement.classList.remove('light');
    document.documentElement.classList.add('dark');
  } else {
    document.documentElement.classList.remove('dark');
    document.documentElement.classList.add('light');
  }
}

window.addEventListener('load', () => {
  setTheme(localStorage.getItem('theme') || "auto")
});