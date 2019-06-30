//function to control different actions for the speaker
function control(action){
    console.log(action)
    var http = new XMLHttpRequest();
    var url = '/'+action;
    http.open('POST', url, true);
    http.send();
  }