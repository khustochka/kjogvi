// This is a placeholder to check that import works both when embedded in another app
// and in dev mode.
// window.addEventListener("DOMContentLoaded", _ => console.log("OrnithoWeb loaded."))

document.addEventListener('DOMContentLoaded', function () {
  const buttons = document.querySelectorAll('button.import-btn');

  const disableAll = (clickedButton) => {
    buttons.forEach(button => {
      button.disabled = true;
      if (clickedButton == button) {
        // Replace the button with a plain label, so it doesn't look like a
        // disabled (still clickable-looking) button while the import runs.
        const label = document.createElement('span');
        label.className = button.dataset.processingClass || '';
        label.textContent = button.getAttribute('oweb-disable-with');
        button.replaceWith(label);
      }
    })
  };

  buttons.forEach(button => {
    const form = button.closest("form");
    if (form) {
      form.addEventListener("submit", () => disableAll(button), { once: true });
    }
  });
});
