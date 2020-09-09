// Helper script that inserts the Authorization header into
// the graphiql interface when the user is logged in.
// TODO: Figure out how to run this when graphiql loads.
{
  function hasAuthHeader() {
    const headers = document.querySelector(".headers .table tbody");
    if (!headers) return false;

    let hasAuth = false;
    for (let i = 0; i < headers.children.length; i++) {
      const title = headers.children[i].children[0].innerText;
      if (title === "Authorization") {
        hasAuth = true;
      }
    }
    return hasAuth;
  }

  function setValue(element, value) {
    let lastValue = element.value;
    element.value = value;
    let event = new Event("input", { target: element, bubbles: true });
    // React 15
    event.simulated = true;
    // React 16
    let tracker = element._valueTracker;
    if (tracker) {
      tracker.setValue(lastValue);
    }
    element.dispatchEvent(event);
  }

  async function setAuthHeader() {
    const store =
      localStorage &&
      localStorage.___hubs_store &&
      JSON.parse(localStorage.___hubs_store);
    const token = store && store.credentials && store.credentials.token;
    if (!token) {
      console.log("Not signed in. Cannot auto-fill Authorization header.");
      return;
    }

    const addButton = document.querySelector(".header-add.btn");
    addButton.click();

    await new Promise((resolve) => setTimeout(resolve, 100));
    const nameField = document.querySelector(
      ".modal-body > form:nth-child(1) > div:nth-child(1) > div:nth-child(2) > input:nth-child(1)"
    );
    setValue(nameField, "Authorization");
    const valueField = document.querySelector("#value-input");
    setValue(valueField, `bearer: ${token}`);
    const okButton = document.querySelector(".btn-primary");
    await new Promise((resolve) => setTimeout(resolve, 100));
    okButton.click();
  }

  setAuthHeader();
}
