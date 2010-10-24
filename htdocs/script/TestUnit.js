
var TestUnit = Class.create({
	errors : new Array(),
	getErrorMessage : function() {
		return this.errors.join("\n");
	},
	assertEquals : function( msg, a, b ) {
		if( a != b ) {
			this.errors.push( "Failed on: " + msg + "(Result: " + a + ", expected: " + b + ")" );
		}
	},
	hasErrors : function() {
		return this.errors.length > 0;
	}
});
