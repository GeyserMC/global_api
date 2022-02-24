let LatestNotificationId = -1;
const NotificationQueue = [];

notification().style.transform = "translateX(150%)";

function notification() {
  return document.getElementById("notification");
}

function setNotificationContent(title, description, success, leftButtonName, leftButtonLink, duration) {
  document.getElementById("notification-title").innerText = title;
  document.getElementById("notification-description").innerText = description;

  const LeftButton = document.getElementById("notification-left-button");
  const LBClassess = LeftButton.classList;

  if (success) {
    document.getElementById("notification-icon-success").classList.remove("hidden");
    document.getElementById("notification-icon-failed").classList.add("hidden");
    LBClassess.remove("text-gray-600");
    LBClassess.add("text-green-700");
  } else {
    document.getElementById("notification-icon-success").classList.add("hidden");
    document.getElementById("notification-icon-failed").classList.remove("hidden");
    LBClassess.add("text-gray-600");
    LBClassess.remove("text-green-700");
  }

  if (leftButtonName == null) {
    LeftButton.innerText = "hidden";
    LBClassess.add("hidden");
  } else {
    LBClassess.remove("hidden");
    LeftButton.innerText = leftButtonName;
    LeftButton.onclick = () => document.location.href = leftButtonLink;
  }
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

export function createNotification(title, description, success, leftButtonName, leftButtonLink, duration) {
  if (NotificationQueue.length === 0 && notification().classList.contains("hidden")) {
    setNotificationContent(title, description, success, leftButtonName, leftButtonLink, duration);
  } else {
    NotificationQueue.push([title, description, success, leftButtonName, leftButtonLink, duration]);
  }
}

export function closeNotification() {
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