app.ports.infoForJS.subscribe(function(elm_data) {
  firebase.database().ref(elm_data.tag).set(elm_data.data)
})

firebase.database().ref("sharedModel/roundTime").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/roundTime", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/gameTime").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag" : "sharedModel/gameTime", "data" : snapshot.val()})
})

firebase.database().ref("sharedModel/roundNumber").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/roundNumber", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/numPlayers").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/numPlayers", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/roundPlaying").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/roundPlaying", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/currentWord").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/currentWord", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/unusedWords").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/unusedWords", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/tracer").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/tracer", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/color").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/color", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/size").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/size", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/drawerID").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/drawerID", "data": snapshot.val()})
})

firebase.database().ref("players/").on("value", function(snapshot){
  app.ports.infoForElm.send({"tag": "players", "data": snapshot.val()})
})
