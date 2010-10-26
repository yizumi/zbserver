
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

	// Generate sample Data
	var hdr = new HistogramDataReader( (function(){
		// In reality, we should be populating this data from database
		// For testing, generate one week worth of data.
		var past = new Date().getTime() - (7*24*60*60*1000);
		var diff = new Date().getTime() - past;
		var rawdata = new Array();
		for( var i = 0 ; i < 10000; i++ ) {
			rawdata.push( Math.floor( (Math.random() * diff) + past ) );
		}
		return rawdata;
	})());

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
			"setup" : "divSetup"
		},
		entrance : function() {
			this.select( "entrance" );
		},
		heatmap : function() {
			this.select( "heatmap" );
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
		{ name : "30mins", title : "過去30分", xname : "n分前",
			getSegmentInfo : function(d) {
				var start = new Date(d.getTime()); 
				start.resetMinute();
				start.setMinutes( start.getMinutes() - 30 );	
				var end = new Date(d.getTime());
				start.resetMinute();
				end.setMinutes( end.getMinutes() + 1 );
				return ['minute',start,end];
			}, 
			transform : function(totals) {
				Loop.$for(0,totals.length,function(i,control){totals[i]=[(30-i)+"",totals[i]?totals[i]:0];});
			} },
		{ name : "24hours", title : "今日", xname : "時間",
			getSegmentInfo : function(d) {
				var start = new Date( d.getTime() );
				start.resetDay();
				var end = new Date( start.getTime() + 86400000 );
				return ['hour',start,end];
			}, transform : function(totals) {
				Loop.$for(0,24,function(i,control){totals[i]=[i+"",totals[i]?totals[i]:0];});
			} },
		{ name : "1week", title : "直近1週間", xname : "日付",
			getSegmentInfo : function(d){
				var start = new Date( d.getTime() );
				start.setDate( start.getDate() - 6 );
				start.resetDay();
				var end = new Date( start.getTime() + 604800000 );
				return ['day',start,end];
			}, transform : function(totals) {
				var start = new Date();
				start.setDate( start.getDate() - 6 );
				Loop.$for(0,7,function(i,control){totals[i]=[start.getDate()+"",totals[i]?totals[i]:0];start.setDate(start.getDate()+1);});
			} },
		{ name : "1month", title : "今月", xname : "日付",
			getSegmentInfo : function(d){
				var start = new Date( d.getTime() );
				start.resetMonth();
				var end = new Date( start.getTime() );
				end.setMonth( end.getMonth() + 1 );
				return ['day',start,end];
			}, transform : function(totals) {
				var start = new Date();
				start.resetMonth();
				var a = parseInt(start.format("t"));
				Loop.$for(0,a,function(i,control){totals[i]=[start.getDate()+"",totals[i]?totals[i]:0];start.setDate(start.getDate()+1);});
			} }
	];

	// Create list options.
	$A(timeSlice).each(function(e,i){
		$("timeSlice").appendChild(new Element("option",{value:i}).update(e.title));
	});
	$("timeSlice").setValue( timeSlice[0].name );

	// Declare the refresh data routine
	var refreshData = function() {
		var ts = timeSlice[parseInt($F("timeSlice"))];
		var segInfo = ts.getSegmentInfo(new Date());
		chartTitle.update( ts.title + "の入退数" );
		nameX.update( ts.xname );
		// Prepare data
		var sw = new Stopwatch(1);
		var totals = hdr.getTotalsBy( segInfo[0], segInfo[1], segInfo[2] );
		sw.stop();
		debug( "Data prep took " + sw +  " :)" );
		
		// Transform the array[int] into a [String,int] with the axis label
		// alert( totals );
		timeSlice[$F("timeSlice")].transform(totals);
		myChart.setDataArray(totals);
		sw.start();
		myChart.draw();
		sw.stop();
		debug( "GUI draw took " + sw +  " :)" );
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
				hdr.addRecord( Date.parseJSON(msg.serverRecpTime) );
				refreshData();
			}
		}
	});

	ripple.start();

});