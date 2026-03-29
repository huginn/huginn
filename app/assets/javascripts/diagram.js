// This is not included in the core application.js bundle.

$(function () {
  const svg = document.querySelector(".agent-diagram svg.diagram");
  const overlay = document.querySelector(".agent-diagram .overlay");
  if (!svg || !overlay) return;

  $(overlay).width($(svg).width()).height($(svg).height());

  const getTopLeft = function (node) {
    const bbox = node.getBBox();
    const point = svg.createSVGPoint();
    point.x = bbox.x + bbox.width;
    point.y = bbox.y;
    return point.matrixTransform(node.getCTM());
  };

  const getBottomLeft = function (node) {
    const bbox = node.getBBox();
    const point = svg.createSVGPoint();
    point.x = bbox.x;
    point.y = bbox.y;
    return point.matrixTransform(node.getCTM());
  };

  // Position favicon overlays at top-left of each node
  $(svg)
    .find("g.node[data-favicon-id]")
    .each(function () {
      const bl = getBottomLeft(this);
      $("#" + this.getAttribute("data-favicon-id"), overlay).each(function () {
        const fav = $(this);
        fav
          .css({
            left: bl.x - fav.outerWidth() * (1 / 3),
            top: bl.y - fav.outerHeight() * (1 / 3),
          })
          .show();
      });
    });

  // Position badge overlays at top-right of each node
  $(svg)
    .find("g.node[data-badge-id]")
    .each(function () {
      const tl = getTopLeft(this);
      $("#" + this.getAttribute("data-badge-id"), overlay).each(function () {
        const badge = $(this);
        badge
          .css({
            left: tl.x - badge.outerWidth() * (2 / 3),
            top: tl.y - badge.outerHeight() * (1 / 3),
            "background-color": badge.find(".label").css("background-color"),
          })
          .show();
      });
    });
});
