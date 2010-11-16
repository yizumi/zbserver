
Number.prototype.cutoff = function(d) {
	return Math.floor( this * Math.pow(10,d) ) / Math.pow(10,d);
};

function debug( str )
{
	if( console && console.log ) {
		console.log( "[" + new Date() + "] " + str );
	}
}

function pad(str){
	return (str+"").length < 2 ? "0" + str : str+"";
}

function onResize() {
	var chart = $("chartContainer");
}

Element.observe(window,"load",function(){
	//new Ajax.Request("/data.txt", {
	new Ajax.Request("/query/RxResponse/resTime>'2010/10/1' and data like 'B%1'", {
		method : "GET",
		onSuccess : function( resp ) {
			try {
				var obj = resp.responseText.evalJSON();
				$A(obj).each( function(v,i){obj[i]=Date.parseSimple(v).getTime();} );
				// $A(obj).each(function(v,i){obj[i]=D
				initComponents( obj );
			}
			catch( e ) {
				alert( "***"  + e );
				throw new Error( e );
			}
		},
		onFailure : function( resp ) {
			alert( "GRrrrr." + resp.responseText );
		}
	});
} );

var initComponents = function( initData ) {
	// Generate sample Data
	var hdr = new HistogramDataReader( initData );

	// generate chart
	var myChart = new JSChart('chartcontainer', 'bar');
	myChart.setSize( 750, 300 );
	myChart.setBarOpacity( 0.95 );
	myChart.setBarSpacingRatio( 40 );
	myChart.setBarColor( "#36f" );
	myChart.setTitle( "" );
	myChart.setAxisNameX( "" );
	myChart.setAxisNameY( "" );

	// Set chart title in japanese
	var charttext = $("charttext");
	var nameX, chartTitle;
	charttext.appendChild( new Element("DIV", {"class": "TitleY"} ).update("入退数") ); 
	charttext.appendChild( nameX = new Element("DIV", {"class": "TitleX"} ).update("時間帯") ); 
	charttext.appendChild( chartTitle = new Element("DIV", {"class": "Title"} ).update("本日の入退数") ); 

	// Configure and start the history watcher
	new History( {
		menu : {
			"entrance" : "divEntrance",
			"heatmap" : "divHeatmap",
			"security" : "divSecurity",
			"setup" : "divSetup"
		},
		entrance : function() {
			this.select( "entrance" );
		},
		heatmap : function() {
			this.select( "heatmap" );
		},
		security : function() {
			this.select( "security" );
		},
		setup : function() {
			this.select( "setup" );
		},
		select : function( name ) {
			for( var key in this.menu ) {
				if( key == name )
					$(this.menu[key]).show();
				else
					$(this.menu[key]).hide();
			}
		}
	} ).start();

	var timeSlice = [
		{ name : "30mins", title : "過去30分", xname : "n分前", pname : "1時間前",
			getSegmentInfo : function(d) {
				var start = new Date(d.getTime()); 
				start.resetMinute();
				start.setMinutes( start.getMinutes() - 30 );	
				var end = new Date(d.getTime());
				start.resetMinute();
				end.setMinutes( end.getMinutes() + 1 );
				return ['minute',start,end];
			}, 
			getPrevSegmentInfo : function(d) {
				var a = this.getSegmentInfo( d );
				a[1].setHours( a[1].getHours() - 1);
				a[2].setHours( a[2].getHours() - 1); // :)
				return a;
			},
			transform : function(totals) {
				Loop.$for(0,totals.length,function(i){totals[i]=[(30-i)+"",totals[i]||0];});
			} },
		{ name : "24hours", title : "今日", xname : "時間", pname : "前日",
			getSegmentInfo : function(d) {
				var start = new Date( d.getTime() );
				start.resetDay();
				var end = new Date( start.getTime() + 86400000 );
				return ['hour',start,end];
			},
			getPrevSegmentInfo : function(d) {
				var a = this.getSegmentInfo(d);
				a[1].setDate( a[1].getDate() - 1 );
				a[2].setDate( a[2].getDate() - 1 );
				return a;
			},
			transform : function(totals) {
				Loop.$for(0,24,function(i){totals[i]=[i+"",totals[i]||0];});
			} },
		{ name : "1week", title : "直近1週間", xname : "日付", pname : "前週",
			getSegmentInfo : function(d){
				var start = new Date( d.getTime() );
				start.setDate( start.getDate() - 6 );
				start.resetDay();
				var end = new Date( start.getTime() + 604800000 );
				return ['day',start,end];
			},
			getPrevSegmentInfo : function(d) {
				var a = this.getSegmentInfo(d);
				a[1].setDate( a[1].getDate() - 7 );
				a[2].setDate( a[2].getDate() - 7 );
				return a;
			},
			transform : function(totals) {
				var start = new Date();
				start.setDate( start.getDate() - 6 );
				Loop.$for(0,7,function(i){totals[i]=[start.getDate()+"",totals[i]||0];start.setDate(start.getDate()+1);});
			} },
		{ name : "1month", title : "今月", xname : "日付", pname : "前月",
			getSegmentInfo : function(d){
				var start = new Date( d.getTime() );
				start.resetMonth();
				var end = new Date( start.getTime() );
				end.setMonth( end.getMonth() + 1 );
				return ['day',start,end];
			},
			getPrevSegmentInfo : function(d) {
				var a = this.getSegmentInfo(d);
				a[1].setMonth( a[1].getMonth() - 1 );
				a[2].setMonth( a[2].getMonth() - 1 );
				return a;
			},
			transform : function(totals) {
				var start = new Date();
				start.resetMonth();
				var a = parseInt(start.format("t"));
				Loop.$for(0,a,function(i){totals[i]=[start.getDate()+"",totals[i]||0];start.setDate(start.getDate()+1);});
			} }
	];

	// Create list options.
	$A(timeSlice).each(function(e,i){
		$("timeSlice").appendChild(new Element("option",{value:i}).update(e.title));
	});
	$("timeSlice").setValue( timeSlice[0].name );

	// create grid
	var valuePerCustomer = 350, gridDiv;
	var grid = new FastGrid( $("gridcontainer"), [
		{ title: "時間", width : 100, dataField : "segment" },
		{ title: "入退数", width : 100, dataField : "count", format : function(v){return v.commify();} },
		{ title: "入退数(前日)", width : 100, dataField : "countPrev", format : function(v){return (v||0).commify();} },
		{ title: "前日比", width : 100, dataField : "countPrev", format : function(v,r){return v?((((r.count||1)/v)-1)*100).cutoff(2)+"%":"-";}},
		{ title: "予想売上高", width : 100, dataField : "count", format : function(v){return Math.floor((v||0)/2*valuePerCustomer).commify();}}
	] );

	// Declare the refresh data routine
	var refreshData = function() {
		// Get the time slice definition
		var ts = timeSlice[parseInt($F("timeSlice"))];
		var segInfo = ts.getSegmentInfo(new Date());
		var segPrevInfo = ts.getPrevSegmentInfo(new Date());
		chartTitle.update( ts.title + "の入退数" );
		nameX.update( ts.xname );
		
		// Prepare data
		var sw = new Stopwatch(1);
		var totals = hdr.getTotalsBy( segInfo[0], segInfo[1], segInfo[2] );
		var totalsPrev = hdr.getTotalsBy( segPrevInfo[0], segPrevInfo[1], segPrevInfo[2] );
		debug( "Data prep took " + sw.stop() +  " :)" );
		
		// Transform the array[int] into a [String,int] with the axis label
		// alert( totals );
		ts.transform(totals);
		myChart.setDataArray(totals);
		sw.start();
		myChart.draw();
		debug( "GUI draw took " + sw.stop() +  " :)" );

		// Transform the array into something ... readable by the grid
		sw.start();
		Loop.$for(0,totals.length,function(i){totals[i]={segment:totals[i][0],count:totals[i][1],countPrev:totalsPrev[i]}});
		debug( "Grid data took " + sw.stop() );
		grid.setHeader(0, ts.xname);
		grid.setHeader(2, "入退数("+ts.pname+")");
		grid.setHeader(3, ts.pname+"比");
		sw.start();
		grid.draw( totals );
		debug( "Grid draw took " + sw.stop() );
	};
	refreshData();
	$("timeSlice").observe("change",refreshData);

	// Set the close at in the info bar
	var lastMinute = -1;
	window.setInterval( function() {
		var d = new Date();
		$("tiempo").update( d.format("H:i:s") );
		if( d.getMinutes() != lastMinute ) {
			lastMinute = d.getMinutes();
			refreshData();
		}
	}, 1000 );

	// Start the communication with the Ripple server
	var ripple = new Ripple("192.168.1.14",{
		onMessage : function( msg ) {
			if( msg.nodeInfo.deviceId == "PANDA:DEVICE:002" ||
				msg.nodeInfo.deviceId == "RIPPLE/SMARTREMOTE" ) {
				this.addAndRefreshStepData( msg );
			}
		},
		addAndRefreshStepData : function(msg) {
			if( msg.data.match( /B([0-9])1/ ) ) {
				var button = parseInt(RegExp.$1);
				hdr.addRecord( Date.parseJSON(msg.serverRecpTime) );
				refreshData();
				if( $("enabledSound").checked ) {
					switch(button) {
						case 1: $("sound3").play(); break;
						case 2: $("sound2").play(); break;
						case 3: $("sound1").play(); break;
					}
				}
				if( $("enableAlert").checked ) {
					var myAnim = new YAHOO.util.ColorAnim($("dialogSecurity"),{
						backgroundColor: {
							to: "#ffcccc"
						}
					});
					myAnim.animate();

					new Ajax.Request( "/mail/" + $F("mailAddress"), {
						onSuccess : function( resp ) {
							var myAnim = new YAHOO.util.ColorAnim($("dialogSecurity"),{
								backgroundColor: {
									to: "#ffffcc"
								}
							});
							myAnim.animate();
						}
					} );
				}
				if( $("enabledLight").checked ) {
					var cx = $F("lightCx");
					new Ajax.Request( "/send/000000000000ffff/L" + cx + "H", {
						onSuccess : function( resp ) {
						}
					} );
					
					setTimeout( function(){
						new Ajax.Request( "/send/000000000000ffff/L" + cx + "L", {
							onSuccess : function( resp ) {
							}
						} );
					}, parseInt( $F("lightDuration")*1000 ) );
				}
			}
		}
	});

	ripple.start();
}

