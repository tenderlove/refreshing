alert("testing");
console.log("HELLO!!!");
const evtSource = new EventSource("/refreshing", { withCredentials: true })
evtSource.addEventListener("status", function(event) {
  console.log("status", event)
});
