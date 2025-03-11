// ==UserScript==
// @name     OpnSense WoL for ghetto-blaster
// @version  1
// @grant    none
// @include     /^https?://(packets|frames)(.dvlp.casa)?/ui/wol/
// ==/UserScript==

let ghettoBlasterMac = "b4:2e:99:88:8c:0e";
window.onload = setInterval(() => {
  var wakeInterface = document.getElementById("wake.interface");
  var wakeInterfaceDiv = document.getElementById("select_wake.interface");
  var wakeInterfaceName = wakeInterfaceDiv.getElementsByClassName("filter-option-inner-inner")[0];
  
  var macField = document.getElementById("wake.mac");
  if (macField){
    wakeInterface.value	= "lan";
    wakeInterfaceName.textContent = "core_lan";
    macField.value = ghettoBlasterMac;
  }
},500);
