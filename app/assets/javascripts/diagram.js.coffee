# This is not included in the core application.js bundle.

$ ->
  svg = document.querySelector('.agent-diagram svg.diagram')
  overlay = document.querySelector('.agent-diagram .overlay')
  getTopLeft = (node) ->
    bbox = node.getBBox()
    point = svg.createSVGPoint()
    point.x = bbox.x + bbox.width
    point.y = bbox.y
    point.matrixTransform(node.getCTM())
  $(svg).find('g.node[data-badge-id]').each ->
    tl = getTopLeft(this)
    $('#' + this.getAttribute('data-badge-id'), overlay).each ->
      badge = $(this)
      badge.css
        left: tl.x - badge.outerWidth()  * (2/3)
        top:  tl.y - badge.outerHeight() * (1/3)
        position: "absolute"
      .show()
      return
    return
