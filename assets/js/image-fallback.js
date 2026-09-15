// Two-stage image fallback for every <img> rendered by
// _includes/contentful-image.html (Plan.md's Error Handling section):
// 1. If the resized (`?w=`) request fails, retry the original,
//    unresized asset (data-original).
// 2. If the original also fails, fall back to a generic placeholder
//    (data-placeholder), since the asset itself is missing/broken.
//
// Tracked via a data-fallback-stage counter rather than comparing
// img.src against data-original/data-placeholder: img.src is always the
// browser-resolved absolute URL, while data-placeholder is root-relative
// (relative_url), so that comparison would never be equal and a broken
// placeholder would retry itself forever.
//
// `error` events don't bubble, but a capturing-phase listener on
// `document` still sees them for every current and future <img> on the
// page -- one listener here instead of an inline `onerror` per <img>.
document.addEventListener(
  "error",
  (event) => {
    const img = event.target;
    if (!(img instanceof HTMLImageElement)) return;

    const stage = Number(img.dataset.fallbackStage) || 0;

    if (stage === 0 && img.dataset.original) {
      img.dataset.fallbackStage = "1";
      img.src = img.dataset.original;
    } else if (stage <= 1 && img.dataset.placeholder) {
      img.dataset.fallbackStage = "2";
      // The placeholder's own aspect ratio has nothing to do with the
      // original image's -- drop the reserved layout dimensions rather
      // than stretch it to fit.
      img.removeAttribute("width");
      img.removeAttribute("height");
      img.src = img.dataset.placeholder;
    }
  },
  true
);
