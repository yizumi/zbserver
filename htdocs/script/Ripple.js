
/**
 * A helper object that allows client to communicate with Ripple's ZigBee end devices.
 *
 * It implmenets methods that help clients to send message to specific 
 *
 */
var Ripple = Class.create({

	connected : false,

	/**
	 * @config An object containing event call-back method and configuration paramters.
	 *			onMessage : function Receives an object that typically contains node information and the data.
	 *						Example:
	 *						{
								"options":2,
								"nodeInfo": {
									"deviceId":"PANDA:DEVICE:002",
									"serial":"0013a20040625ada",
									"area":"Utsuki/2F/StudyNW",
									"permission":null,
									"my":"fffe",
									"deviceType":null,
									"currentState":null,
									"lastUpdate":"2010-10-24 17:49:32",
									"signalStrength":"50",
									"displayName":null },
								"raw_data":"800013a20040625ada3402423330",
								"serial":"0013a20040625ada",
								"data":"B30",
								"rssi":52,
								"checksum":"OK",
								"length":14,
								"type":"RxResponse"
							}
							If you don't receive nodeInfo, the chance is that the end device was not turned
							on when the server side program did the initial network node scan.  You can manually
							invoke discover and allow end device to send the message.
	 *			server : use server
	 */
	initialize : function( server, config ) {
		this.server = server;
		this.config = config;
	},
	
	/**
	 * Start the subscription to the web event dispatcher using WebSocket
	 */
	start : function() {
		if( "WebSocket" in window )
		{
			this.ws = new WebSocket("ws://"+this.server+"/socket");
			var self = this;
			this.ws.onopen = function() {
				self.connected = true;
			};

			this.ws.onmessage = function(evt) {
				self.config.onMessage( evt.data.evalJSON() );
			};

			this.ws.onclose = function() {
				self.ws = null;
				self.connected = false;
			}
		}
		else
		{
			alert( "WebSocket NOT supported here!\r\n\r\nBrowser: " + 
				navigator.appName + " " + navigator.appVersion );
		}
	},
	
	/** 
	 * Returns true if connected.
	 */
	isConnected : function() {
		return this.connected;
	},
	
	/**
	 * Requests server to scan all nodes in the network.
	 * TODO: Return all nodes found with-in timeout.
	 */
	discover : function( timeout ) {
		new Ajax.Request( "/discover", {
			method: "POST",
			onSuccess : function( message ) {
			}
		});
	},

	/**
	 * Send a string to a specific end-devices.
	 * There will be no translation from string to bytes, so character 'A' will be sent as 0x41 to the
	 * device.
	 */
	sendText : function(addr,payload) {
		new Ajax.Request("/send/"+addr+"/"+payload,{
			method : "POST",
			onSuccess : function() {
			}
		});
	},

	/**
	 * Send data to a specific end-device using hex string.
	 * The string will be translated from hex-string to bytes, and sent to end devices.
	 */
	sendHex : function(addr,hex) {
		// alert( hex );
		new Ajax.Request("/sendhex/"+addr+"/"+payload,{
			method : "POST",
			onSuccess : function() {
			}
		});
	},
	
	/**
	 * Broadcasts payload to all devices in the network
	 * This doesn't retry or gurantee the data transfer to all devices.
	 * (Similar to UDP messages)
	 */
	broadcastText : function( payload ) {
		this.sendText( "000000000000ffff", payload );
	},
	
	/**
	 * Broadcasts payload to all devices in the network.
	 * This doesn't retry or gurantee the data transfer to all devices.
	 * (Similar to UDP messages)
	 */
	broadcastHex : function( payload ) {
		this.sendHex( "000000000000ffff", payload );
	},

	debug : function( str ) {
		if( console && console.log ) {
			console.log( "[" + new Date() + "] " + str );
		}
		else {
			// alert( str );
		}
	}
});