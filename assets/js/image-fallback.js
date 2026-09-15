---
---
// Two-stage image fallback for every <img> rendered by
// _includes/contentful-image.html (Plan.md's Error Handling section):
// 1. If the resized (`?w=`) request fails, retry the original,
//    unresized asset (data-original).
// 2. If the original also fails, fall back to a generic placeholder.
//
// Compared via getAttribute, not the `src` property: the property
// always resolves to an absolute URL, while data-original/PLACEHOLDER
// may be root-relative (relative_url) -- comparing the resolved
// property against the literal attribute would never match, and a
// broken placeholder would retry itself forever. PLACEHOLDER is baked
// in here (this file has its own empty front matter, so Jekyll runs
// it through Liquid) rather than read from a data attribute, since
// it's one site-wide constant, not something that varies per <img>.
//
// `error` events don't bubble, but a capturing-phase listener on
// `document` still sees them for every current and future <img> on
// the page. Deliberately not `defer`red: the browser's preload
// scanner can start fetching (and failing) images while the rest of
// the page is still parsing, before a deferred script would run --
// this has to be registered before that can happen.
const PLACEHOLDER = "{{ "/assets/images/placeholder.svg" | relative_url }}";

document.addEventListener(
  "error",
  (event) => {
    const img = event.target;
    if (!(img instanceof HTMLImageElement) || !img.dataset.original) return;

    const src = img.getAttribute("src");
    if (src === PLACEHOLDER) return; // already at the last stage -- stop

    if (src === img.dataset.original) {
      img.src = PLACEHOLDER;
      img.alt = "Bilde utilgjengelig";
    } else {
      img.src = img.dataset.original;
    }
  },
  true
);
