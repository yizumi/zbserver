
Ext.setup({
	phoneStartupScreen: "img/iphone_startup.png",
	icon: "img/icon.png",
	onReady: function() {
		Ripple.init();
	}
});

var devices = {};
var Ripple = {};