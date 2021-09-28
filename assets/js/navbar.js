let NavMenuClicked = false;

mobileMenu().style.transform = "translateY(-150%)";
userMenu().style.transform = "scale(0.95)";

function mobileMenu() {
  return document.getElementById("mobile-menu");
}

document.getElementById("mobile-menu-button").onclick = () => {
  let shouldOpen = NavMenuClicked = !NavMenuClicked;
  if (shouldOpen) {
    mobileMenu().classList.remove("hidden");
    setTimeout(() => {
      mobileMenu().style.transform = "translateY(0%)";
    }, 1);
  } else {
    mobileMenu().style.transform = "translateY(-150%) scale(0.5)";
    setTimeout(() => {
      mobileMenu().classList.add("hidden");
    }, 200);
  }
};

function userMenu() {
  return document.getElementById("user-menu-dropdown");
}

document.getElementById("user-menu-button").onclick = () => {
  let shouldOpen = NavMenuClicked = !NavMenuClicked;
  if (shouldOpen) {
    userMenu().classList.add("opacity-100");
    userMenu().classList.remove("opacity-0");
    userMenu().classList.remove("hidden");
    setTimeout(() => {
      userMenu().style.transform = "scale(1)";
    }, 1);
  } else {
    userMenu().classList.add("opacity-0");
    userMenu().classList.remove("opacity-100");
    userMenu().style.transform = "scale(0.95)";
    setTimeout(() => {
      userMenu().classList.add("hidden");
    }, 150);
  }
};