/*app.ports.firebaseWrite.subscribe(function(data) {
  firebase.database().ref("/Counter").set(data);
});

firebase.database().ref("/Counter").on("value", function(snapshot) {
  console.log(snapshot.val());
  app.ports.firebaseRead.send(snapshot.val());
});*/

app.ports.infoForJS.subscribe(function(elm_data) {
  firebase.database().ref(elm_data.tag).set(elm_data.data)
})

firebase.database().ref("sharedModel/roundTime").on("value", function(snapshot) {
  //console.log(snapshot.val())
  app.ports.infoForElm.send({"tag": "sharedModel/roundTime", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/gameTime").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag" : "sharedModel/gameTime", "data" : snapshot.val()})
})

firebase.database().ref("sharedModel/restStart").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/restStart", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/roundNumber").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/roundNumber", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/numPlayers").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/numPlayers", "data": snapshot.val()})
})

firebase.database().ref("sharedModel/roundPlaying").on("value", function(snapshot) {
  app.ports.infoForElm.send({"tag": "sharedModel/numPlayers", "data": snapshot.val()})
})
