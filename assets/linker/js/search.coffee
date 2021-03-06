currentTab = "search-tab"
count = 0
searchResults = []

switchTab = (tab)->
  $("#" + currentTab).fadeOut ()->
    $("#" + tab).fadeIn()
    currentTab = tab

escapeHtml = (str) ->
  div = document.createElement("div")
  div.appendChild document.createTextNode(str)
  div.innerHTML
  
escapeMagnet = (str)->
  escapeHtml(str).replace /&amp;/g, "&"
    
decodeMagnet = (uri) ->
  result = {}
  data = uri.split("magnet:?")[1]
  throw new Error("Invalid magnet URI") if not data or data.length is 0
  params = data.split("&")
  params.forEach (param) ->
    keyval = param.split("=")
    key = keyval[0]
    val = keyval[1]
    throw new Error("Invalid magnet URI") if keyval.length isnt 2
      
    # Address tracker (tr) is an encoded URI, so decode it
    val = decodeURIComponent(val)  if key is "tr"
      
    # If there are repeated parameters, return an array of values
    if result[key]
      if Array.isArray(result[key])
        result[key].push val
      else
        old = result[key]
        result[key] = [old, val]
    else
      result[key] = val
  result
Router = Backbone.Router.extend 
  routes:
    "search":"search"
    "search/*query":"search"
    "publish":"publish"
    "faq":"faq"
    "about":"about"
    "future":"future"
    "*default":"search"
  search:(query)->
    switchTab("search-tab") unless currentTab == "search-tab"
    if !query?
      if $("#searchResultsBody").is(":visible")
        $("#searchResultsBody").fadeOut ()->
          $("#searchBody").fadeIn()
    else
      $("#searchQuery").val(query)
      $("#innerSearchQuery").val(query)
      count = 0
      $("#searchResults").empty()
      socket.get "/feathercoin/search?query=" + query
      $("#searchBody").fadeOut ()->
        $("#searchResultsBody").removeClass("hidden").fadeIn()
  publish:()->
    switchTab("publish-tab")
  faq:()->
    switchTab("faq-tab")
  about:()->
    switchTab("about-tab")
  future:()->
    switchTab("future-tab")

renderGoals = (goals)->
  html = window.JST["assets/linker/templates/goalItem.html"] 
    goals:goals
  $("#goalBody").empty().append html
  
   


$(document).ready ()->
  count = 0
  router = new Router();
  Backbone.history.start()
  socket.on "connect", ()->
    socket.removeAllListeners "searchResult"
    socket.removeAllListeners "goals"
    socket.on "searchResult", (result)->
      return false if not result.name? or not result.name.trim() or not result.payloadInline? or result.payloadInline.indexOf("magnet:") != 0 or _.contains searchResults, result.payloadInline
      searchResults.push result.payloadInline
      result.count = count++
      html = window.JST["assets/linker/templates/searchResult.html"] result
      $("#searchResults").append html
    socket.on "goals", (goals)->
      renderGoals goals
    socket.get "/feathercoin/goals", (goals)->
      renderGoals goals
  $("#publishButton").click (event)->
    event.preventDefault()
    formData = $("#publishForm").serializeArray()
    sendMe = {}
    for key,value of formData
      if value.value
        sendMe[value.name] = value.value
    if not sendMe.payloadInline? or sendMe.payloadInline.indexOf("magnet:") != 0
      $('<div>You can\'t publish anything but magnet links.<br></br>For more information on magnet links please visit <a href="http://lifehacker.com/5875899/what-are-magnet-links-and-how-do-i-use-them-to-download-torrents">this web page.</a>').dialog
        width: 500
        show: "fadeIn"
        modal:true
        closeText: "I Understand"
        buttons: [
          text:"I understand"
          click: ()->
            $(@).dialog "close"
        ]
      return false
    if not sendMe.name? or not sendMe.name.trim() or not sendMe.description? or not sendMe.description.trim()
      $('<div>You need to supply a name and a description.</div>').dialog
        width: 500
        show: "fadeIn"
        modal:true
        closeText: "I Understand"
        buttons: [
          text:"I understand"
          click: ()->
            $(@).dialog "close"
        ]
      return false
    socket.put "/feathercoin/publish", sendMe, (message)->
      html = window.JST["assets/linker/templates/publishResults.html"] message
      $(html).dialog
        width: 500
        title: "Ready To Publish"
        show: "fadeIn"
        modal:true
        closeText: "Ok"
        buttons: [ 
          text: "Ok"
          click: ()->
            $(@).dialog "close"
        ]
      socket.on message.sendAddress, (result)->
        html = window.JST["assets/linker/templates/publishSuccess.html"] result
        $(html).dialog
          width: 850
          title: "Successfully Published"
          show: "fadeIn"
          modal:true
          closeText: "Ok"
          buttons: [ 
            text: "Ok"
            click: ()->
              $(@).dialog "close"
          ] 
  populateTimeout = -1      
  runPrepopulate = ()->
    clearTimeout populateTimeout if populateTimeout isnt -1
    populateTimeout = setTimeout prepopulate, 1000
    
  prepopulate = ()->
    populateTimeout = -1
    try
      r = decodeMagnet $("#payloadInline").val()
      name = decodeURI(r["dn"]).replace(/\+/g, ' ')
      if name.indexOf(" ") == -1
        name = name.replace(/\./g, " ")
      $("#name").val(name)
      xt = r["xt"]
      xt = xt.join("&xt=") if Array.isArray xt
      payload = "magnet:?xt=" + xt + "&dn=" + r["dn"]
      $("#payloadInline").val(payload) if payload isnt $("#payloadInline").val()
      socket.get "/feathercoin/keywords?query=" + name, (keywords)->
        $("#keywords").val keywords.join ", "
    catch e
      console.log e
  $("#payloadInline").on "keyup blur", runPrepopulate
  
  $("#searchForm").submit (event)->
    count = 0
    searchResults = []
    window.location = "#search/" + $("#searchQuery").val()
    event.preventDefault()
    return false
    
  $("#searchButton").click (event)->
    count = 0
    searchResults = []
    window.location = "#search/" + $("#searchQuery").val()
    event.preventDefault()
    return false
  $("#innerSearchButton").click (event)->
    count = 0
    searchResults = []
    window.location = "#search/" + $("#innerSearchQuery").val()
    event.preventDefault()
    return false
    
    