const loginBaseUrl = 'https://login.live.com/oauth20_authorize.srf?client_id=dad9257f-6b54-4509-8463-81286ee5860d&response_type=code&display=popup&scope=Xboxlive.signin&redirect_uri=';
const linkUrl = '%API_BASE_URL%/v2/link/online';

window.addEventListener('load', function () {
  const queryParams = new URLSearchParams(window.location.search);
  const cleanUrl = window.location.href.replace(window.location.search, '');

  // fixes the home screen button's text being black while making requests
  setHomeScreenColor(false);
  setStepActionContent('Loading web page...', 'text-gray-500 mt-8', true);

  // handle token -> id
  if (queryParams.has('code')) {
    const token = queryParams.get('code');
    const isJava = queryParams.has('bedrock');

    setStepActionContent('Verifying received data...', 'text-gray-500', true);

    if (isJava) {
      // should always be true at this point, but just for the people that like to tamper with the page
      const hasBInfo = queryParams.has('b_info') && queryParams.get('b_info').split(':').length >= 2;

      let body = {java: token};
      // otherwise our redirect_uri doesn't match
      if (hasBInfo) {
        body.query_info = {'bedrock': queryParams.get('bedrock'), 'b_info': queryParams.get('b_info')}
      } else {
        body.query_info = {'bedrock': queryParams.get('bedrock')}
      }

      makeLinkRequest(
          body,
          function (status, content) {
            const isExpectedStatus = status >= 200 && status < 300;
            if (!isExpectedStatus || content.success !== true) {
              const reason = isExpectedStatus ? content.message : content;
              if (reason === 2148916233) {
                setStepActionContent("You selected a Microsoft account that doesn't have a Xbox account. Are you sure that you selected the right account?", 'text-red-500', true);
              } else {
                setStepActionContent('Failed to validate Java token!<br>Reason: ' + reason + '.<br>Please try it again', 'text-red-500', true);
              }
              setButton(cleanUrl + '?bedrock=' + queryParams.get('bedrock'), 'Restart Java login');

              window.history.replaceState(null, '', cleanUrl + getCleanUrl(cleanUrl));
              return;
            }

            const data = content.data;
            window.history.replaceState(null, '', cleanUrl + '?bedrock=' + queryParams.get('bedrock') + '&java=' + data.id);

            window.document.getElementById('link-details-desc').innerText = "The information about the account you want to link that we have so far.";
            if (hasBInfo) {
              const [xuid, gamertag] = queryParams.get('b_info').split(':', 1)
              addFormElement('Xbox Id (xuid)', xuid)
              addFormElement('Gamertag', gamertag)
            }
            addFormElement('UUID', data.uuid);
            addFormElement('Username', data.username);
            // show link details
            window.document.getElementById('link-details').classList.remove('hidden');

            updatePage();
          }
      )
    } else {
      makeLinkRequest(
          {bedrock: token},
          function (status, content) {
            const isExpectedStatus = status >= 200 && status < 300;
            if (!isExpectedStatus || content.success !== true) {
              const reason = isExpectedStatus ? content.message : content;
              console.log(reason);
              if (reason === 2148916233) {
                setStepActionContent("You selected a Microsoft account that doesn't have a Xbox account. Are you sure that you selected the right account?", 'text-red-500', true);
              } else {
                setStepActionContent('Failed to validate Bedrock token!<br>Reason: ' + reason + '.<br>Please try it again', 'text-red-500', true);
              }
              setButton(cleanUrl, 'Restart linking');

              window.history.replaceState(null, '', cleanUrl);
              return;
            }

            const data = content.data;
            window.history.replaceState(null, '', cleanUrl + '?bedrock=' + data.id + "&b_info=" + data.xuid + ":" + data.gamertag);

            updatePage();
          }
      )
    }
  } else {
    updatePage();
  }
})

function updatePage() {
  const queryParams = new URLSearchParams(window.location.search);
  const cleanUrl = window.location.href.replace(window.location.search, '');

  if (queryParams.has('java') && queryParams.has('bedrock')) {
    updateSteps(3);
    // the user logged in with their Bedrock and Java account, let's start the linking

    setStepActionContent('Making link request...', 'text-gray-500 mt-8', true);

    const errorHandler = function (reason) {
      setStepActionContent(
          "Failed to get a valid response from the global api!<br>We'll try it again in 20 seconds.<br>Error: " + reason,
          'text-red-500',
          true
      );
      setTimeout(function () {
        setStepActionContent('Making link request...', 'text-gray-500 mt-8', true);
        makeLinkRequest({
          java: queryParams.get('java'),
          bedrock: queryParams.get('bedrock')
        }, responseHandler, errorHandler);
      }, 20000)
    };

    const responseHandler = function (status, content) {
      if (status < 200 || status >= 300) {
        errorHandler(status + ', ' + content);
        return;
      }

      if (content.success !== true) {
        setStepActionContent('Failed to link your account!<br>Reason: ' + content.message, 'text-red-500', true);
        setButton(cleanUrl, 'Restart linking');
        return;
      }

      updateSteps(4);
      const data = content.data;

      clearStepActionContent();
      setStepActionHeader('You have successfully linked your account!', 'text-green-500 mt-8');

      window.history.replaceState(null, '', cleanUrl);

      window.document.getElementById('link-details-desc').innerText = "Information about the account you just linked.";
      clearFormElements();
      addFormElement('Xbox Id (xuid)', data.xuid)
      addFormElement('Gamertag', data.gamertag)
      addFormElement('UUID', data.uuid);
      addFormElement('Username', data.username);
      // show link details
      window.document.getElementById('link-details').classList.remove('hidden');
    };

    makeLinkRequest({java: queryParams.get('java'), bedrock: queryParams.get('bedrock')}, responseHandler, errorHandler);
  } else if (queryParams.has('bedrock')) {
    clearStepActionContent();
    updateSteps(2);
    const loginUrl = loginBaseUrl + getCleanUrl(cleanUrl, queryParams, 'b_info bedrock');
    setLoginButton('Java', loginUrl, true);

    if (queryParams.has('b_info')) {
      const bInfo = queryParams.get('b_info').split(':');

      window.document.getElementById('link-details-desc').innerText = "The information about the account you want to link that we have so far.";
      clearFormElements();
      addFormElement('Xbox Id (xuid)', bInfo[0]);
      addFormElement('Gamertag', bInfo[1]);
      // show link details
      window.document.getElementById('link-details').classList.remove('hidden');
    }
  } else {
    clearStepActionContent();
    updateSteps(1);
    setLoginButton('Bedrock', loginBaseUrl + cleanUrl, true);
  }
}

function getCleanUrl(baseUrl, queryParams, only = null) {
  let bedrock = queryParams.get('bedrock');
  let bInfo = queryParams.get('b_info');
  let java = queryParams.get('java');
  if (only != null) {
    const list = only.split(' ');
    if (!list.includes('bedrock')) {
      bedrock = null;
    }
    if (!list.includes('b_info')) {
      bInfo = null;
    }
    if (!list.includes('java')) {
      java = null;
    }
  }
  let cleanUrl = "?";
  if (bedrock != null) {
    cleanUrl += "bedrock=" + bedrock + "&";
  }
  if (bInfo != null) {
    cleanUrl += "b_info=" + bInfo + "&";
  }
  if (java != null) {
    cleanUrl += "java=" + java + "&";
  }
  return baseUrl + cleanUrl.substring(0, cleanUrl.length - 1);
}

function makeLinkRequest(body, onResponse, onError = null) {
  if (body == null || onResponse == null) {
    return;
  }

  fetch(linkUrl, {
    method: 'post',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(body)
  }).then(async function (response) {
    if (response.status < 200 || response.status >= 300) {
      console.log(response.status + ' ' + (await response.clone().text()));
      onResponse(response.status, (await response.json()).message);
      return;
    }
    onResponse(response.status, await response.json());
  }).catch(function (reason) {
    if (onError != null) {
      onError(reason)
    } else {
      onResponse(-1, reason)
    }
  })
}

function setStepActionHeader(content, additionalClasses = 'text-gray-500 dark:text-gray-400') {
  const header = window.document.getElementById('step-action-header');
  for (let classToAdd of additionalClasses.split(' ')) {
    header.classList.add(classToAdd);
  }
  header.innerText = content;
}

function clearStepActionContent(err = null) {
  const clearErr = err == null || err === true;
  const clearInner = err == null || err === false;
  if (clearErr) {
    const errElement = window.document.getElementById('step-action-err');
    if (errElement != null) {
      errElement.remove();
    }
  }
  if (clearInner) {
    const innerElement = window.document.getElementById('step-action-inner');
    if (innerElement != null) {
      innerElement.remove();
    }
  }
}

function setStepActionContent(content, additionalClasses = 'text-gray-500', err = false) {
  if (err) {
    const errElement = window.document.getElementById('step-action-err')
    if (errElement != null) {
      errElement.remove();
    }
    if (content != null) {
      const stepAction = window.document.getElementById('step-action');
      stepAction.innerHTML +=
          '<p class="mt-4 max-w-2xl text-xl ' + additionalClasses + ' lg:mx-auto" id="step-action-err">' + content + '</p>'
          + stepAction.innerHTML;
    }
    return;
  }

  let innerElement = window.document.getElementById('step-action-inner');
  if (innerElement != null) {
    innerElement.remove();
    innerElement = null;
  }
  if (content != null) {
    window.document.getElementById('step-action').innerHTML +=
        '<p class="mt-4 max-w-2xl text-xl ' + additionalClasses + ' lg:mx-auto" id="step-action-inner">' + content + '</p>';
  }
}

function setButton(link, content) {
  const buttonElement = window.document.getElementById('step-action-button');
  if (buttonElement == null) {
    window.document.getElementById('step-action').innerHTML +=
        '<div class="max-w-7xl mx-auto py-4 px-4 sm:px-6 lg:px-8" id="step-action-button">' +
        '  <div class="inline-flex rounded-md shadow">' +
        '    <a href="' + link + '"' +
        '       class="inline-flex items-center justify-center px-5 py-3 border border-transparent text-base font-medium rounded-md text-white dark:text-gray-100 bg-indigo-600 dark:bg-indigo-700 hover:bg-indigo-700 dark:hover:bg-indigo-600">' +
        content +
        '    </a>' +
        '  </div>' +
        '</div>';
  }
}

function setLoginButton(loginTo, link, addLogoutButton = false) {
  const stepAction = window.document.getElementById('step-action');
  stepAction.innerHTML +=
      '<div class="max-w-7xl mx-auto py-4 px-4 sm:px-6 lg:px-8">' +
      '  <div class="inline-flex rounded-md shadow">' +
      '    <a href="' + link + '"' +
      '       class="inline-flex items-center justify-center px-5 py-3 border border-transparent text-base font-medium rounded-md text-white dark:text-gray-100 bg-indigo-600 dark:bg-indigo-700 hover:bg-indigo-700 dark:hover:bg-indigo-600">' +
      '      Login to ' + loginTo +
      '    </a>' +
      '  </div>' +
      '</div>';

  if (addLogoutButton) {
    stepAction.innerHTML +=
        '<p class="mt-4 max-w-2xl text-xl text-gray-500 dark:text-gray-400 lg:mx-auto" id="step-2">' +
        '  Click the logout button below to logout from your current Microsoft account.' +
        '  Microsoft remembers if you gave approval before, so if you have ever used this linking tool before or if you are currently in step 2 Microsoft will automatically approve the request without giving you an option to logout or switch accounts.' +
        '  The logout page will open in a new tab and you\'ll be redirected to the msn page once you\'re logged out successfully. After that you can come back to this page and click the login button.' +
        '</p>' +
        '<div class="max-w-7xl mx-auto py-4 px-4 sm:px-6 lg:px-8">' +
        '  <div class="inline-flex rounded-md shadow">' +
        '    <a href="https://login.live.com/logout.srf" target="_blank" class="inline-flex items-center justify-center px-5 py-3 border border-transparent text-base font-medium rounded-md text-white dark:text-gray-100 bg-indigo-600 dark:bg-indigo-700 hover:bg-indigo-700 dark:hover:bg-indigo-600">' +
        '      Logout' +
        '    </a>' +
        '  </div>' +
        '</div>';
  }
}

function updateSteps(currentStep) {
  updateStep(currentStep, 1, window.document.getElementById('step-1'));
  updateStep(currentStep, 2, window.document.getElementById('step-2'));
  updateStep(currentStep, 3, window.document.getElementById('step-3'));
  setHomeScreenColor(currentStep > 3);
}

function updateStep(currentStep, stepNum, element) {
  if (currentStep >= stepNum) {
    element.classList.remove('hidden')
    if (currentStep > stepNum) {
      element.classList.add('text-green-500')
    } else {
      element.classList.add('text-gray-500','dark:text-gray-200')
    }
  }
}

function clearFormElements() {
  window.document.getElementById('link-details-inner').innerHTML = '';
}

function addFormElement(key, value) {
  window.document.getElementById('link-details-inner').innerHTML +=
      '<div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">' +
      '  <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">' +
      key +
      '  </dt>' +
      '  <dd class="mt-1 text-sm text-gray-900 dark:text-gray-300 sm:mt-0 sm:col-span-2">' +
      value +
      '  </dd>' +
      '</div>';
}

function setHomeScreenColor(isPrimary) {
  let toAdd;
  let toRemove;
  if (isPrimary) {
    toAdd = "text-white dark:text-gray-200 bg-indigo-600 dark:bg-indigo-700 hover:bg-indigo-700 dark:bg-indigo-600";
    toRemove = "text-indigo-600 dark:text-indigo-700 bg-white dark:bg-gray-400 hover:bg-indigo-50 dark:hover:bg-gray-500";
  } else {
    toAdd = "text-indigo-600 dark:text-indigo-700 bg-white dark:bg-gray-400 hover:bg-indigo-50 dark:hover:bg-gray-500";
    toRemove = "text-white dark:text-gray-200 bg-indigo-600 dark:bg-indigo-700 hover:bg-indigo-700 dark:bg-indigo-600";
  }
  const classList = window.document.getElementById('home-screen-btn').classList;
  for (let classToAdd of toAdd.split(' ')) {
    classList.add(classToAdd);
  }
  for (let classToRemove of toRemove.split(' ')) {
    classList.remove(classToRemove);
  }
}
