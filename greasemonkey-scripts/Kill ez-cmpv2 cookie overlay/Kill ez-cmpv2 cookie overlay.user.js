// ==UserScript==
// @name     Kill ez-cmpv2 cookie overlay
// @version  1
// @grant    none
// ==/UserScript==

window.onload = setInterval(() => {
  var cookieDiv = document.getElementById("ez-cmpv2-container");
  if (cookieDiv) {
  	cookieDiv.remove();
  	console.log("GreaseMonkey: removed #ez-cmpv2-container cookie overlay")
  }
},100);