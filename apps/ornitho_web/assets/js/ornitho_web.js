// This is a placeholder to check that import works both when embedded in another app
// and in dev mode.
// window.addEventListener("DOMContentLoaded", _ => console.log("OrnithoWeb loaded."))

document.addEventListener('DOMContentLoaded', function () {
  const buttons = document.querySelectorAll('button.import-btn');

  const disableAll = (clickedButton) => {
    buttons.forEach(button => {
      button.disabled = true;
      if (clickedButton == button) {
        button.dataset.originalText = button.textContent; // store current text
        button.textContent = button.getAttribute('oweb-disable-with');
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
