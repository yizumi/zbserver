var Stopwatch = Class.create({
	initialize : function( startNow ) {
		if( startNow ) {
			this.start();
		}
	},
	start : function() {
		this.startTime = new Date().getTime();
	},
	stop : function(doAlert) {
		this.endTime = new Date().getTime();
		if( doAlert ) {
			this.alert();
		}
		return this.toString();
	},
	getDiff : function() {
		return this.endTime - this.startTime;
	},
	alert : function() {
		alert( this.getDiff() + "ms" );
	},
	toString : function() {
		return this.getDiff() + "ms";
	}
});