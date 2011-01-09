
Element.observe(window,'load',function(){
	Canvas.setGradient( $("globalDiv"), [[0,'#54547F'],[0.75,'#000']] );
	Canvas.setGradient( $("toolbar"), [[0,'#FFF'],[0.75,'#8d8d8d']] );
	Canvas.setAquaGradient( $("menuTraffic"), [[0,'#42A128'],[1,'#4AB62D']] );
	Canvas.setAquaGradient( $("menuSecurity"), [[0,'#17390E'],[1,'#215114']] );
	
	var stopScrolling = function( touchEvent ) { touchEvent.preventDefault(); };
	document.addEventListener( 'touchstart', stopScrolling, false );
	document.addEventListener( 'touchmove', stopScolling, false );

	
});


var Canvas = {
	setGradient : function( elm, gr )
	{
		var c = new Element('canvas',{width:elm.getWidth(),height:elm.getHeight()});
		c.setStyle({'position':'absolute',"z-index":-1});
		elm.insertBefore( c, elm.firstChild );
		var ctx = c.getContext('2d');
		var lg = ctx.createLinearGradient(0,0,0,elm.getHeight());
		$A(gr).each( function(i) { lg.addColorStop( i[0], i[1] ); } );
		ctx.fillStyle = lg;
		ctx.fillRect( 0, 0, elm.getWidth(), elm.getHeight() );
	},
	
	setAquaGradient : function( elm, gr )
	{
		var w = elm.getWidth();
		var h = elm.getHeight();
		var r = 5; // roundness
		var m = 2; // margin for the glass effect

		// create the canvas
		var c1 = new Element('canvas',{width:elm.getWidth(),height:elm.getHeight()});
		c1.setStyle({'position':'absolute',"z-index":-1});
		elm.insertBefore( c1, elm.firstChild );
		var ctx = c1.getContext('2d');
		var lg = ctx.createLinearGradient(0,0,0,elm.getHeight());
		$A(gr).each( function(i) { lg.addColorStop( i[0], i[1] ); } );

		// back-fill
		ctx.fillStyle = lg;
		ctx.beginPath();
		ctx.moveTo(0,0);
		ctx.lineTo(w,0);
		ctx.lineTo(w,h-r);
		ctx.quadraticCurveTo(w,h,w-r,h);
		ctx.lineTo(r,h);
		ctx.quadraticCurveTo(0,h,0,h-r);
		ctx.lineTo(0,0);
		ctx.fill();

		// glass effect
		var lg2 = ctx.createLinearGradient(0,0,0,elm.getHeight()/3);
		lg2.addColorStop( 0, "rgba(255,255,255,0.6)" );
		lg2.addColorStop( 1, "rgba(255,255,255,0)" );
		ctx.fillStyle = lg2;
		ctx.fillRect( m, 0, w-(m*2), elm.getHeight()/3 );

	}
};