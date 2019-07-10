function control(action){
    console.log(action)
    var http = new XMLHttpRequest();
    var url = '/'+action;
    http.open('POST', url, true);
    http.send();
  }
  function reset(action){
    console.log(action)
    var http = new XMLHttpRequest();
    var url = '/reset_smart_speaker/'+action;
    http.open('POST', url, true);
    http.send();
  }
  function SetVolume(val){
    console.log(val)
    var http = new XMLHttpRequest();
    var url = '/volume/'+val;
    http.open('POST', url, true);
    http.send();
  }
 
  function getOfflineSong(e){
    console.log("inside getOfflineSong")
    var folder = e.options[e.selectedIndex].value
    var url = '/getOfflineSong/'+folder;

     fetch(url).then(function(response) {
      return response.json();
    }).then(function(data) {
    var layout = document.getElementById('layout')
    layout.innerHTML=''
    if(data.status.length>0){
     var mod =  document.createElement("div")
        mod.setAttribute('class',"list")
        data.status.forEach(song => {
        var btn = document.createElement("button");
        var icon = document.createElement("i")
        var name = document.createTextNode(song.name);
        icon.className = "fa fa-music"
        btn.value=song.name
        btn.appendChild(icon)
        btn.appendChild(name)
        btn.className= "btn btn-outline-primary m-2"
        btn.setAttribute('onClick','playOfflineSong(this)')
        mod.appendChild(btn)
      });
      layout.appendChild(mod)
    }
    }).catch(function() {
      console.log("Error");
      return null;
    });
  }
  function playOfflineSong(e){
    var folder = document.getElementById('mounted-device')
    folder = folder.options[folder.selectedIndex].value
    var song =  e.value
    console.log("Song: "+song)
    var url = '/playOfflineSong/'+folder+'/'+song;
    console.log("url="+url)
    var http = new XMLHttpRequest();
    http.open('PUT', url, true);
    http.send();
  }

  
  function refershDeviceList(){
      
    var url = '/getdevice'
     fetch(url).then(function(response) {
        return response.json();
      }).then(function(data) {
          console.log(data.status)
          var list = document.getElementById('mounted-device')
          list.innerHTML = ''
          data.status.forEach(folder => {
              var opt = document.createElement('option')
              opt.value =  folder.name
              opt.innerText = folder.name
              list.appendChild(opt)              
          });
      }).catch(function() {
        console.log("Error");
        return null;
      });
  }

  function playYoutube(e){
    var link = document.getElementById('ytb-link').value
    console.log('link='+link)
    var url = '/playyoutube'
     fetch(url,{
        method: 'PATCH', // or 'PUT'
        body: JSON.stringify({'link':link}), // data can be `string` or {object}!
        headers:{
          'Content-Type': 'application/json'
        }
      }).then(function(response) {
        return response.json();
      }).catch(function() {
        console.log("Error");
        return null;
      });
  }