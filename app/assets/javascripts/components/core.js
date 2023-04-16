$(function () {
  // Flash
  if ($(".flash").length) {
    setTimeout(() => $(".flash").slideUp(() => $(".flash").remove()), 5000);
  }

  // Help popovers
  $(".hover-help").popover({ trigger: "hover", html: true });

  // Pressing '/' selects the search box.
  $("body").on("keypress", function (e) {
    if (e.keyCode === 47) {
      // The '/' key
      if (e.target.nodeName === "BODY") {
        e.preventDefault();
        return $agentNavigate.focus();
      }
    }
  });

  // Select2 Selects
  $(".select2").select2({ width: "resolve" });

  $(".select2-linked-tags").select2({
    width: "resolve",
    formatSelection(obj) {
      return `<a href=\"${this.element.data("urlPrefix")}/${
        obj.id
      }/edit\" onClick=\"Utils.select2TagClickHandler(event, this)\">${Utils.escape(
        obj.text
      )}</a>`;
    },
  });

  // Helper for selecting text when clicked
  $(".selectable-text").each(function () {
    return $(this).click(function () {
      const range = document.createRange();
      range.setStartBefore(this.firstChild);
      range.setEndAfter(this.lastChild);
      const sel = window.getSelection();
      sel.removeAllRanges();
      return sel.addRange(range);
    });
  });

  // Agent navbar dropdown
  return $(".navbar .dropdown.dropdown-hover").hover(
    function () {
      return $(this).addClass("open");
    },
    function () {
      return $(this).removeClass("open");
    }
  );
});
