export function getOverlayPortalTarget(): Element {
  return document.querySelector('ion-app') || document.body;
}
