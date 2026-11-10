export function slide(element, keyframes) {
  const duration = parseFloat(getComputedStyle(element).getPropertyValue("--panel-slide")) * 1000
  return element.animate(keyframes, { duration, easing: "cubic-bezier(.2, .8, .2, 1)" }).finished
}
