var urlParams = new URLSearchParams(window.location.search)
var connectAs = urlParams.get('connectAs')
var connectTo = urlParams.get('connectTo')

var app = Elm.Main.init({
  flags: {
    connectAs: connectAs,
    connectTo: connectTo,
  }
})

var peer = null
var conn = null

app.ports.outgoingActorMessages.subscribe(function (msg) {
  console.log("Outgoing message", msg)
  if (msg.tag === "ConnectToServer") {
    var id = msg.data
    peer = new Peer(id)

    peer.on('open', function(id) {
      app.ports.incomingActorMessages.send({tag: "ConnectedToServer", data: id})
    })

    peer.on('connection', function(connection) {
      conn = connection
      setupConnection(conn)
    })
  } else if (msg.tag === "ConnectToPeer") {
    var peerId = msg.data
    conn = peer.connect(peerId)
    setupConnection(conn)
  } else if (msg.tag === "SendPayload") {
    conn.send(msg.data)
  } else {
    console.log("Unknown message " + msg.tag, msg)
  }
})

function setupConnection(conn) {
  conn.on('data', function(data) {
    console.log('Received from peer', data)
    app.ports.incomingActorMessages.send({tag: "ReceivedPayload", data: data})
  })

  conn.on('open', function() {
    app.ports.incomingActorMessages.send({tag: "ConnectedToPeer", data: null})
  })
}
