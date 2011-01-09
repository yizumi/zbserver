
/**
 * A helper object that allows client to communicate with Ripple's ZigBee end devices.
 *
 * It implmenets methods that help clients to send message to specific 
 *
 */
var Ripple = Class.create({

	connected : false,
	websocket : null,
	failCount : 0,

	/**
	 * @server : the server to call websocket
	 * @config An object containing event call-back method and configuration paramters.
	 *			onOpen() : function invoked when connection is established
	 *			onMessage(obj) : function invoked when the a message object is published
	 *						a typical message object looks like:
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
				onClose(failCount,retryInterval) : function invoked when connection is closed.  You can return "false" if you don't want to retry
				onGiveUp() : function invoked when connection cannot be established within retryMax attempts
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
			this.createSocket();
		}
		else
		{
			alert( "WebSocket NOT supported here!\r\n\r\nBrowser: " + 
				navigator.appName + " " + navigator.appVersion );
		}
	},
	
	createSocket : function() {
		var self = this;
		if( self.websocket == null )
		{
			self.websocket = new WebSocket("ws://"+self.server+"/socket");
			self.websocket.onopen = function() {
				self.failCount = 0; // reset the fail count on open
				self.config.onOpen();
			};
			self.websocket.onmessage = function(evt) {
				self.config.onMessage( evt.data.evalJSON() );
			};
			self.websocket.onclose = function() {
				self.websocket = null;
				var interval = self.getRetryInterval();
				var rc = self.config.onClose( self.failCount, interval );
				if( rc !== false )
				{
					// setting timeout
					setTimeout(function(){
						self.createSocket();
					}, interval * 1000 );
					self.failCount++;
				}
			};
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
	},

	getRetryInterval : function()
	{
		// double the interval each time until it hits 30 seconds
		return Math.min( 30, Math.pow( 2, this.failCount ) );
	}
});