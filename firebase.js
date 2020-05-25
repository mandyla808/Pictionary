app.ports.firebaseWrite.subscribe(function(data) {
  firebase.database().ref("/Counter").set(data);
});

firebase.database().ref("/Counter").on("value", function(snapshot) {
  console.log(snapshot.val());
  app.ports.firebaseRead.send(snapshot.val());
});
