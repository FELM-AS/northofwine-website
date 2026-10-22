---
---
// Two-stage fallback for images from _includes/contentful-image.html:
// a failed resized image retries the original (data-original), and a
// failed original falls back to PLACEHOLDER.
//
// Compares getAttribute values, not the absolute `src` property, so the
// checks match root-relative URLs and a broken placeholder can't loop.
// `error` doesn't bubble, so this listens in the capture phase.
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
      // A decorative image (alt="") stays decorative.
      if (img.alt) img.alt = {{ "image.unavailable" | t | jsonify }};
    } else {
      img.src = img.dataset.original;
    }
  },
  true
);
