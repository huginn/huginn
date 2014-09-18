#= require d3
#= require rickshaw
#= require_self

# This is not included in the core application.js bundle.

window.renderGraph = ($chart, data, peaks, name) ->
  graph = new Rickshaw.Graph
    element: $chart.find(".chart").get(0)
    width: 700
    height: 240
    series: [
      data: data
      name: name
      color: 'steelblue'
    ]

  x_axis = new Rickshaw.Graph.Axis.Time(graph: graph)

  annotator = new Rickshaw.Graph.Annotate
     graph: graph
     element: $chart.find(".timeline").get(0)
  $.each peaks, ->
    annotator.add this, "Peak"

  y_axis = new Rickshaw.Graph.Axis.Y
    graph: graph
    orientation: 'left'
    tickFormat: Rickshaw.Fixtures.Number.formatKMBT
    element: $chart.find(".y-axis").get(0)

  graph.onUpdate ->
    mean = d3.mean data, (i) -> i.y
    standard_deviation = Math.sqrt(d3.mean(data.map((i) -> Math.pow(i.y - mean, 2))))
    minX = d3.min data, (i) -> i.x
    maxX = d3.max data, (i) -> i.x
    graph.vis.append("svg:line")
      .attr('x1', graph.x(minX))
      .attr('x2', graph.x(maxX))
      .attr('y1', graph.y(mean))
      .attr('y2', graph.y(mean))
      .attr 'class', 'summary-statistic mean'
    graph.vis.append("svg:line")
      .attr('x1', graph.x(minX))
      .attr('x2', graph.x(maxX))
      .attr('y1', graph.y(mean + standard_deviation))
      .attr('y2', graph.y(mean + standard_deviation))
      .attr 'class', 'summary-statistic one-std'
    graph.vis.append("svg:line")
      .attr('x1', graph.x(minX))
      .attr('x2', graph.x(maxX))
      .attr('y1', graph.y(mean + 2 * standard_deviation))
      .attr('y2', graph.y(mean + 2 * standard_deviation))
      .attr 'class', 'summary-statistic two-std'
    graph.vis.append("svg:line")
      .attr('x1', graph.x(minX))
      .attr('x2', graph.x(maxX))
      .attr('y1', graph.y(mean + 3 * standard_deviation))
      .attr('y2', graph.y(mean + 3 * standard_deviation))
      .attr 'class', 'summary-statistic three-std'

  graph.render()
