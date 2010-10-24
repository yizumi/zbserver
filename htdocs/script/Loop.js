var Loop = {
	$for : function(start,end,f) {
		var rv, control = { "continue" : true };
		for( var i = start; i < end; i++ ) {
			rv = f( i, control );
			if( !control.continue )
				break;
		}
		return rv;
	}
};
