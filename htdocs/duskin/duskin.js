Number.prototype.commify = function()
{
	var nStr = this.toString(),
		x = nStr.split('.'),
		x1 = x[0],
		x2 = x.length > 1 ? '.' + x[1] : '',
		rgx = /(\d+)(\d{3})/;

	while (rgx.test(x1)) {
		x1 = x1.replace(rgx, '$1' + ',' + '$2');
	}
	return x1 + x2;
}

var webapp = {
	start : function() {
		var self = this;
		var hash = "";
		setInterval( function() {
			if( document.location.hash != hash )
			{
				hash = document.location.hash;
				self.onHashChange( hash+"" );
			}
		}, 100 );
	},
	
	onHashChange : function( hash ) {
		if( hash.match("^\#([a-zA-Z0-9]+)") )
		{
			var action = RegExp.$1;
			switch( action )
			{
				case "traffic":
					Canvas.setAquaGradient( $("menuTraffic"), "0 5", "0 #42A128,1 #4AB62D" );
					Canvas.setAquaGradient( $("menuSecurity"), "0 5", "0 #17390E,1 #215114" );
					Canvas.setAquaGradient( $("menuMedical"), "0 5", "0 #17390E,1 #215114" );
					$("trafficTab").show();
					$("securityTab").hide();
					$("medicalTab").hide();
					break;
				case "security":
					Canvas.setAquaGradient( $("menuTraffic"), "0 5", "0 #17390E,1 #215114" );
					Canvas.setAquaGradient( $("menuSecurity"), "0 5", "0 #42A128,1 #4AB62D" );
					Canvas.setAquaGradient( $("menuMedical"), "0 5", "0 #17390E,1 #215114" );
					$("trafficTab").hide();
					$("securityTab").show();
					$("medicalTab").hide();
					break;
				case "medical":
					Canvas.setAquaGradient( $("menuTraffic"), "0 5", "0 #17390E,1 #215114" );
					Canvas.setAquaGradient( $("menuSecurity"), "0 5", "0 #17390E,1 #215114" );
					Canvas.setAquaGradient( $("menuMedical"), "0 5", "0 #42A128,1 #4AB62D" );
					$("trafficTab").hide();
					$("securityTab").hide();
					$("medicalTab").show();
					break;
			}
		}
	}
};

Element.observe(window,'load',function(){
	$$("DIV.Gradient").each(function(div){
		Canvas.setGradient(div,div.getAttribute("x-gradient"));
	});

	$$("DIV.AquaGradient").each(function(div){
		Canvas.setAquaGradient(div,div.getAttribute("x-radius"),div.getAttribute("x-gradient"));
	});

	$$("DIV.RoundedGradient").each(function(div){
		Canvas.setRoundedGradient(div,div.getAttribute("x-radius"),div.getAttribute("x-gradient"));

	});
	
	var stopScrolling = function( touchEvent ) { touchEvent.preventDefault(); };
	// document.addEventListener( 'touchstart', stopScrolling, false );
	document.addEventListener( 'touchmove', stopScrolling, false );

	var rtcounter = new RealtimeCounterPresenter($("rtcountComp"));
	var medica = new Medica($("medicalTab"));

	var ripple = new Ripple(document.location.hostname,{
		onOpen: function() {
			$("modalMessageDialog").hide();
		},
		onMessage : function( obj ) {
			this.updateRssi( obj.rssi );
			rtcounter.onMessage(obj);
			medica.onMessage(obj);
		},
		updateRssi : function( rssi ) {
			var str = rssi < 50 ? "強" : rssi < 70 ? "中" : rssi < 90 ? "弱" : "微";
			$("rssi").update(str);
		},
		onClose : function(totalFail, retryInt) {
			var remainingSec = retryInt;
			var rm = $("retryMessage");
			for( var i = 0; i < retryInt; i++ ) {
				setTimeout( function() {
					remainingSec--;
					if( remainingSec > 0 )
						rm.update("接続が切断されました。<br/>"+remainingSec+"秒で再接続をします。");
					else
						rm.update("再接続中");

				}, i * 1000 );
			}
			$("modalMessageDialog").show();
		}
	});
	ripple.start();
	webapp.start();
});

function px2int(px)
{
	if( (px+"").match(/([0-9]+)px/) )
		return parseInt( RegExp.$1 );
	return 0;
}


var Canvas = {
	// returns an array of: nw, ne, sw, se
	parseRadius : function(rd) {
		rd = rd+"";
		var r;
		if( rd.match(/([0-9]+)\s+([0-9]+)\s+([0-9]+)\s+([0-9]+)/) ) {
			r = new Array( 
				parseInt(RegExp.$1), 
				parseInt(RegExp.$2),
				parseInt(RegExp.$3),
				parseInt(RegExp.$4)
			);
		}
		// for two elements tops, then bottoms
		else if( rd.match( /([0-9]+)\s+([0-9]+)/ ) ) {
			r = new Array(
				parseInt(RegExp.$1),
				parseInt(RegExp.$1),
				parseInt(RegExp.$2),
				parseInt(RegExp.$2)
			);
		}
		// for single parameter, apply to all
		else if( rd.match( /([0-9]+)/ ) ) {
			r = new Array(
				parseInt(RegExp.$1),
				parseInt(RegExp.$1),
				parseInt(RegExp.$1),
				parseInt(RegExp.$1)
			);
		}
		// default value is 5
		else {
			r = new Array(5,5,5,5);
		}
		return r;
	},
	
	parseGradientStops : function(grd) {
		var gr = new Array();
		(grd+"").split(",").each(function(stop){
			if( stop.match(/([0-9\.]+) (\#[A-F0-9]+)/i) ) {
				gr.push( [RegExp.$1 * 1, RegExp.$2] );
			}
		});
		return gr;
	},

	setGradient : function( elm, grd )
	{
		var gr = this.parseGradientStops(grd);
		var c = elm.down("canvas.cvr");
		if( c == null ) {
			var padtop = px2int( elm.getStyle("padding-top") );
			var padleft = px2int( elm.getStyle("padding-left") );
			c = new Element('canvas',{width:elm.getWidth(),height:elm.getHeight(),"class":"cvr"});
			c.setStyle({'position':'absolute','z-index':-1,'margin-top':(padtop*-1)+"px",'margin-left':(padleft*-1)+"px"});
			elm.insertBefore( c, elm.firstChild );
		}
		var ctx = c.getContext('2d');
		var lg = ctx.createLinearGradient(0,0,0,elm.getHeight());
		gr.each( function(i) { lg.addColorStop( i[0], i[1] ); } );
		ctx.fillStyle = lg;
		ctx.fillRect( 0, 0, elm.getWidth(), elm.getHeight() );
	},
	
	setRoundedGradient : function( elm, rd, grd )
	{
		var gr = this.parseGradientStops(grd);
		var r = this.parseRadius( rd );
		var w = elm.getWidth();
		var h = elm.getHeight();
		var c = elm.down("canvas.cvr");
		if( c == null ) {
			var padtop = px2int( elm.getStyle("padding-top") );
			var padleft = px2int( elm.getStyle("padding-left") );
			c = new Element('canvas',{width:elm.getWidth(),height:elm.getHeight(),"class":"cvr"});
			c.setStyle({'position':'absolute','z-index':-1,'margin-top':(padtop*-1)+"px",'margin-left':(padleft*-1)+"px"});
			elm.insertBefore( c, elm.firstChild );
		}
		var ctx = c.getContext('2d');
		var lg = ctx.createLinearGradient(0,0,0,elm.getHeight());
		$A(gr).each( function(i) { lg.addColorStop( i[0], i[1] ); } );
		ctx.fillStyle = lg;
		ctx.beginPath();
		ctx.moveTo(0,r[0]);
		ctx.quadraticCurveTo(0,0,r[0],0);
		ctx.lineTo(w-r[1],0);
		ctx.quadraticCurveTo(w,0,w,r[1]);
		ctx.lineTo(w,h-r[3]);
		ctx.quadraticCurveTo(w,h,w-r[3],h);
		ctx.lineTo(r[2],h);
		ctx.quadraticCurveTo(0,h,0,h-r[2]);
		ctx.lineTo(0,r[0]);
		ctx.fill();
	},

	setAquaGradient : function( elm, rd, grd )
	{
		var gr = this.parseGradientStops(grd);
		var r = this.parseRadius(rd);
		var w = elm.getWidth();
		var h = elm.getHeight();
		var m = 2; // margin for the glass effect

		// create the canvas
		var c = elm.down("canvas.cvr");
		if( c == null ) {
			var padtop = px2int( elm.getStyle("padding-top") );
			var padleft = px2int( elm.getStyle("padding-left") );
			c = new Element('canvas',{width:elm.getWidth(),height:elm.getHeight(),"class":"cvr"});
			c.setStyle({'position':'absolute','z-index':-1,'margin-top':(padtop*-1)+"px",'margin-left':(padleft*-1)+"px"});
			elm.insertBefore( c, elm.firstChild );
		}
		var ctx = c.getContext('2d');
		var lg = ctx.createLinearGradient(0,0,0,elm.getHeight());
		$A(gr).each( function(i) { lg.addColorStop( i[0], i[1] ); } );

		// back-fill
		ctx.fillStyle = lg;
		ctx.beginPath();
		ctx.moveTo(0,r[0]);
		ctx.quadraticCurveTo(0,0,r[0],0);
		ctx.lineTo(w-r[1],0);
		ctx.quadraticCurveTo(w,0,w,r[1]);
		ctx.lineTo(w,h-r[3]);
		ctx.quadraticCurveTo(w,h,w-r[3],h);
		ctx.lineTo(r[2],h);
		ctx.quadraticCurveTo(0,h,0,h-r[2]);
		ctx.lineTo(0,r[0]);
		ctx.fill();

		// draw the inset glass effect box
		var lg2 = ctx.createLinearGradient(0,0,0,elm.getHeight()/3);
		lg2.addColorStop( 0, "rgba(255,255,255,0.6)" );
		lg2.addColorStop( 1, "rgba(255,255,255,0)" );
		ctx.fillStyle = lg2;
		r.each(function(c,i){r[i]=c-m}); // reduce the inset-radius by 'm'argin
		w = w - (m*2); // reduce the width by 'm'argin;
		h = h / 3; // glass effect, we should draw about 1/3 of the full height
		ctx.beginPath();
		ctx.moveTo(m,m+r[0]);
		ctx.quadraticCurveTo(m,m,m+r[0],m);
		ctx.lineTo(m+w-r[1],m);
		ctx.quadraticCurveTo(m+w,m,m+w,m+r[1]);
		ctx.lineTo(m+w,m+h-r[3]);
		ctx.quadraticCurveTo(m+w,m+h,m+w-r[3],m+h);
		ctx.lineTo(m+r[2],m+h);
		ctx.quadraticCurveTo(m,m+h,m,m+h-r[2]);
		ctx.lineTo(m,m+r[0]);
		ctx.fill();
	}
};

var RealtimeCounterPresenter = Class.create({
	initialize : function( view ) {
		this.view = view;
		this.refreshCount();
	},
	
	siteSummary : {
		"jp" : 2200,
		"jp.tk" : 1000,
		"jp.tk.hachioji" : 500,
		"jp.tk.hachioji.utstuki" : 500,
		"jp.tk.shibuya" :  500,
		"jp.tk.shibuya.ebisu" : 500,
		"jp.os" : 1200,
		"jp.os.suita" : 1200,
		"jp.os.suita.toyotsu" : 1200
	},
	
	// increment all site summaries including parent sites for the given site.
	updateSiteSummary : function( site ) {
		var sites = site.split(".");
		var key = "";
		for( var i = 0; i < sites.length; i++ ) {
			key += (key==""?"":".")+sites[i];
			if( !(this.siteSummary[key] > 0 ) )
				this.siteSummary[key] = 0;
			this.siteSummary[key]++;
			this.refreshCount(key);
		}
	},
	
	// gets the string representation of the number
	getSiteSummary : function( site ) {
		var t = this.siteSummary[site];
		if( t > 0 )
			return t.commify();
		else
			return "0";
	},

	// Ripple.addEventListener(this);
	onMessage : function( obj ) {
		try
		{
			// update the datamodel
			if( obj.nodeInfo.site && obj.nodeInfo.site != "" ) {
				this.updateSiteSummary( obj.nodeInfo.site );
			}
		}
		catch(e)
		{
			// do nothing
			if( console && console.log ) {
				console.log( e );
			}
		}
	},

	refreshCount : function( key ) {
		this.view.select("div.rtcount-item").each(function(item){
			var site = item.getAttribute("x-site");
			if( key === undefined || site == key )
			{
				var count = this.getSiteSummary(site);
				item.down("span.rtcount-last-update").update( new Date().format("H:i:s") );
				var countElm = item.down("span.rtcount-count");
				countElm.update(count);
				// Set animation if it was specifically redrawn
				if( site == key )
				{
					var myAnim = new YAHOO.util.ColorAnim(countElm,{
						color: { from: "#ff0000", to: "#ffffff" }
					});
					myAnim.animate();
				}
			}
		},this);
	}
});

var Medica = Class.create({
	currCard : null,

	initialize : function(view) {
		this.view;
		this.currCard = $("card-00000000000001FA");
	},
	
	onMessage : function( obj ) {
		try
		{
			if( obj.nodeInfo.deviceId == "PANDA:DEVICE:003" )
			{
				var data = obj.data;
				var elm = $("card-"+data);
				if( elm != null && this.currCard != elm )
				{
					this.currCard.hide();
					elm.show();
					this.currCard = elm;
				}
			}
		}
		catch (e)
		{
		}
	}
});