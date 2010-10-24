
var History = Class.create( {
	initialize : function( handlerObj ) {
		this.listener = new History.Listener( handlerObj );
		this.lastHash = null;
	},
	getHash : function() {
		var str = top.location.href, v = str.indexOf("#");
		return ( v > 0 ) ? str.substr( v + 1 ) : null;
	},
	start : function() {
		var self = this;
		this.refreshId = setInterval( function() {
			var hash = self.getHash();
			if( self.lastHash != hash ) {
				self.lastHash = hash;
				self.listener.onchange( hash );
			}
		}, 50 );
	},
	stop : function() {
		clearInterval( this.refreshId );
	}
} );

History.Listener = Class.create({
	initialize : function( config ) {
		this.config = config;
	},
	onchange : function( hash ) {
		if( hash.match( /([^\/]+)(\/?(.*))/ ) ) {
			if( typeof( this.config[RegExp.$1] ) == "function" ) {
				this.config[RegExp.$1]( RegExp.$3 );
			}
		}
	}
});