chemin = []

Renderer = (canvas) ->
  canvas = $(canvas).get(0)
  ctx = canvas.getContext('2d')
  gfx = arbor.Graphics(canvas)
  particleSystem = null
  that = 
    
    init: (system) ->
      particleSystem = system
      particleSystem.screenSize canvas.width, canvas.height
      particleSystem.screenPadding 40
      that.initMouseHandling()
      return
    
    redraw: ->
      if !particleSystem
        return
      gfx.clear()
      # convenience ƒ: clears the whole canvas rect
      # draw the nodes & save their bounds for edge drawing
      nodeBoxes = {}
      particleSystem.eachNode (node, pt) ->
        # node: {mass:#, p:{x,y}, name:"", data:{}}
        # pt:   {x:#, y:#}  node position in screen coords
        # determine the box size and round off the coords if we'll be 
        # drawing a text label (awful alignment jitter otherwise...)
        label = node.data.label or ''
        w = ctx.measureText('' + label).width + 10
        if !('' + label).match(/^[ \t]*$/)
          pt.x = Math.floor(pt.x)
          pt.y = Math.floor(pt.y)
        else
          label = null
        # draw a rectangle centered at pt
        if node.data.color
          ctx.fillStyle = node.data.color
        else
          ctx.fillStyle = 'rgba(0,0,0,.2)'
        if node.data.color == 'none'
          ctx.fillStyle = 'white'
        if node.data.shape == 'dot'
          gfx.oval pt.x - (w / 2), pt.y - (w / 2), w, w, fill: ctx.fillStyle
          nodeBoxes[node.name] = [
            pt.x - (w / 2)
            pt.y - (w / 2)
            w
            w
          ]
        else
          gfx.rect pt.x - (w / 2), pt.y - 10, w, 20, 4, fill: ctx.fillStyle
          nodeBoxes[node.name] = [
            pt.x - (w / 2)
            pt.y - 11
            w
            22
          ]
        # draw the text
        if label
          ctx.font = '12px Helvetica'
          ctx.textAlign = 'center'
          ctx.fillStyle = 'white'
          if node.data.color == 'none'
            ctx.fillStyle = '#333333'
          ctx.fillText label or '', pt.x, pt.y + 4
          ctx.fillText label or '', pt.x, pt.y + 4
        return
      # draw the edges
      particleSystem.eachEdge (edge, pt1, pt2) ->
        # edge: {source:Node, target:Node, length:#, data:{}}
        # pt1:  {x:#, y:#}  source position in screen coords
        # pt2:  {x:#, y:#}  target position in screen coords
        weight = edge.data.weight
        color = edge.data.color
        if !color or ('' + color).match(/^[ \t]*$/)
          color = null
        # find the start point
        tail = intersect_line_box(pt1, pt2, nodeBoxes[edge.source.name])
        head = intersect_line_box(tail, pt2, nodeBoxes[edge.target.name])
        ctx.save()
        ctx.beginPath()
        ctx.lineWidth = if !isNaN(weight) then parseFloat(weight) else 1
        ctx.strokeStyle = if color then color else '#cccccc'
        ctx.fillStyle = null
        ctx.moveTo tail.x, tail.y
        ctx.lineTo head.x, head.y
        ctx.stroke()
        ctx.restore()
        # draw an arrowhead if this is a -> style edge
        if edge.data.directed
          ctx.save()
          # move to the head position of the edge we just drew
          wt = if !isNaN(weight) then parseFloat(weight) else 1
          arrowLength = 6 + wt
          arrowWidth = 2 + wt
          ctx.fillStyle = if color then color else '#cccccc'
          ctx.translate head.x, head.y
          ctx.rotate Math.atan2(head.y - (tail.y), head.x - (tail.x))
          # delete some of the edge that's already there (so the point isn't hidden)
          ctx.clearRect -arrowLength / 2, -wt / 2, arrowLength / 2, wt
          # draw the chevron
          ctx.beginPath()
          ctx.moveTo -arrowLength, arrowWidth
          ctx.lineTo 0, 0
          ctx.lineTo -arrowLength, -arrowWidth
          ctx.lineTo -arrowLength * 0.8, -0
          ctx.closePath()
          ctx.fill()
          ctx.restore()
        return
      return
    
    initMouseHandling: ->
      # no-nonsense drag and drop (thanks springy.js)
      selected = null
      nearest = null
      dragged = null
      oldmass = 1
      # set up a handler object that will initially listen for mousedowns then
      # for moves and mouseups while dragging
      handler = 
        clicked: (e) ->
          
          pos = $(canvas).offset()
          _mouseP = arbor.Point(e.pageX - (pos.left), e.pageY - (pos.top))
          selected = nearest = dragged = particleSystem.nearest(_mouseP)
          console.log "clicked point :", selected.node
          particleSystem.tweenNode( selected.node , 0.5, {color: "blue"} ) 
          
          if chemin.length > 1
            last = chemin.pop()
            console.log last
            edges = particleSystem.getEdges( last, selected.node)
            console.log "found edges :", edges
            particleSystem.tweenEdge(edges[0], 0.5, {weight : 10})
          chemin.push last
          chemin.push selected.node
        
      $(canvas).mousedown handler.clicked
      return
  # helpers for figuring out where to draw arrows (thanks springy.js)

  intersect_line_line = (p1, p2, p3, p4) ->
    denom = (p4.y - (p3.y)) * (p2.x - (p1.x)) - ((p4.x - (p3.x)) * (p2.y - (p1.y)))
    if denom == 0
      return false
    # lines are parallel
    ua = ((p4.x - (p3.x)) * (p1.y - (p3.y)) - ((p4.y - (p3.y)) * (p1.x - (p3.x)))) / denom
    ub = ((p2.x - (p1.x)) * (p1.y - (p3.y)) - ((p2.y - (p1.y)) * (p1.x - (p3.x)))) / denom
    if ua < 0 or ua > 1 or ub < 0 or ub > 1
      return false
    arbor.Point p1.x + ua * (p2.x - (p1.x)), p1.y + ua * (p2.y - (p1.y))

  intersect_line_box = (p1, p2, boxTuple) ->
    p3 = 
      x: boxTuple[0]
      y: boxTuple[1]
    w = boxTuple[2]
    h = boxTuple[3]
    tl = 
      x: p3.x
      y: p3.y
    tr = 
      x: p3.x + w
      y: p3.y
    bl = 
      x: p3.x
      y: p3.y + h
    br = 
      x: p3.x + w
      y: p3.y + h
    intersect_line_line(p1, p2, tl, tr) or intersect_line_line(p1, p2, tr, br) or intersect_line_line(p1, p2, br, bl) or intersect_line_line(p1, p2, bl, tl) or false

  that

sys = arbor.ParticleSystem()
sys.parameters
  repulsion : 100
  stiffness : 50
  friction  : 0.5
  gravity   : true
  precision : 0.005
sys.renderer = Renderer("#viewport")
      
render_viewport = () ->
  init : (pointer) ->
    console.log("init") if local_debug 
    particles = $( "#root" ).find(".dropped")      
    if particles.length > 0
      branch = {nodes:{}, edges:[]}
      particles.each ->
        transform_div_to_node($(this))
        create_edges_for_heritier( $(this))
      find_action_pointer $("#root") 
    sys.start()
  
  clear : () -> sys.eachNode (node) -> sys.pruneNode node
    
$ ->  
  $( "#slider-repulsion" ).slider
    range: "max"
    min   : 1
    max   : 3000
    step  : 10
    value : 2000
    slide : ( event, ui ) -> 
      $( "#amount-repulsion" ).html( ui.value )
      sys.parameters repulsion: ui.value          
  $( "#amount-repulsion" ).html("2000")

  
  $( "#slider-stiffness" ).slider
    range: "max"
    min   : 1
    max   : 3000
    step  : 10
    value : 1000
    slide : ( event, ui ) -> 
      $( "#amount-stiffness" ).html( ui.value )
      sys.parameters stiffness: ui.value           
  $( "#amount-stiffness" ).html("1000")
  
  $( "#slider-friction" ).slider
    range: "max"
    min   : 0
    max   : 1
    step  : 0.1
    value : 0
    slide : ( event, ui ) -> 
      $( "#amount-friction" ).html( ui.value )
      sys.parameters friction: ui.value           
  $( "#amount-friction" ).html("0") 
  local_debug = true
  for i in [1..5]
    sys.addNode i, {'color' : "red", 'shape' : 'dot', 'label' : " * ", 'mass' : "1" }
  
  for i in [1..5]
    for j in [1..5]
      sys.addEdge i, j, {type : "arrow", directed : true, color : "black", weight : 1}
