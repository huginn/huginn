#= require cytoscape
#= require_self

window.renderDigraph = (nodes, edges) ->

  $(".digraph").cytoscape
    layout:
      name: 'breadthfirst',
      fit: true,
      maximalAdjustments: 1

    style: cytoscape.stylesheet().selector("node").css(
      content: "data(name)"
      "text-valign": "center"
      color: "white"
      "text-outline-width": 2
      "text-outline-color": "#888"
    ).selector("edge").css("target-arrow-shape": "triangle").selector(":selected").css(
      "background-color": "black"
      "line-color": "black"
      "target-arrow-color": "black"
      "source-arrow-color": "black"
    ).selector(".faded").css(
      opacity: 0.25
      "text-opacity": 0
    )
    elements:
      nodes: nodes
      edges: edges