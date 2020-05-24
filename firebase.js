app.ports.firebaseWrite.subscribe(function(data) {
  firebase.database().ref("/").set(data);
});

firebase.database().ref("/").on("value", function(snapshot) {
  console.log(snapshot.val());
  app.ports.firebaseRead.send(snapshot.val());
});
