// Registry.js — engine-wide bridge. QML JS libraries are singletons per
// process, so a bar-widget instance on any monitor and the popup both reach
// the plugin's singleton day service without caring about load order.
var _service = null

function set(inst) {
  _service = inst
}

function get() {
  return _service
}