// Opens the Menu overlay (_includes/header.html). Closing, focus
// trapping, and Escape-to-close are all native <dialog> modal behavior
// -- nothing to do here for those.
document.getElementById("menu-open")?.addEventListener("click", () => {
  document.getElementById("menu-dialog")?.showModal();
});
