function SetVolume(val){
    console.log(val)
    var http = new XMLHttpRequest();
    var url = '/volume?val='+val;
    http.open('POST', url, true);
    http.send();
}