
var Loop = {
	$for : function(start,end,f){
		var rv;
		var control = { "stop" : false };
		for( var i = start; i < end; i++ ) {
			rv = f( i, control );
			if( control.stop ) {
				break;
			}
		}
		return rv;
	}
};