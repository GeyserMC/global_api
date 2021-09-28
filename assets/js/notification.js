let LatestNotificationId = -1;
const NotificationQueue = [];

notification().style.transform = "translateX(150%)";

function notification() {
  return document.getElementById("notification");
}

function setNotificationContent(title, description, leftButtonName, leftButtonLink, duration) {
  document.getElementById("notification-title").innerText = title;
  document.getElementById("notification-description").innerText = description;
  const LeftButton = document.getElementById("notification-left-button");
  LeftButton.innerText = leftButtonName;
  LeftButton.onclick = () => document.location.href = leftButtonLink;
  showNotification();

  LatestNotificationId++;

  if (duration != null) {
    const notificationId = LatestNotificationId;
    setTimeout(() => {
      if (LatestNotificationId === notificationId) {
        closeNotification()
      }
    }, duration);
  }
}

function createNotification(title, description, leftButtonName, leftButtonLink, duration) {
  if (NotificationQueue.length === 0 && notification().classList.contains("hidden")) {
    setNotificationContent(title, description, leftButtonName, leftButtonLink, duration);
  } else {
    NotificationQueue.push([title, description, leftButtonName, leftButtonLink, duration]);
  }
}

function closeNotification() {
  hideNotification(() => {
    // play next notification if it has any
    const NextNotification = NotificationQueue.shift();
    if (NextNotification !== undefined) {
      setNotificationContent.apply(null, NextNotification);
    }
  });
}

function showNotification() {
  notification().classList.remove("hidden");
  setTimeout(() => notification().style.transform = "translateX(0%)", 10);
}

function hideNotification(onHidden) {
  notification().style.transform = "translateX(150%)";
  setTimeout(() => {
    notification().classList.add("hidden");
    if (onHidden != null) {
      setTimeout(onHidden, 1)
    }
  }, 1000);
}