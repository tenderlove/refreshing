const source = new EventSource("/refreshing", { withCredentials: true })
source.addEventListener("status", function(event) {
  var data = JSON.parse(event.data);
  if (data.type == "refresh") {
    window.location.reload();
  } else {
    console.log("status", event);
  }
});
