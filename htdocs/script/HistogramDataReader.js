
var HistogramDataReader = Class.create({
	initialize : function( array ) {
		this.data = array;
		this.data.sort(function(a,b){return a-b;}); // Sort
	},

	/*
	 * @samplingFreq:int use SamplingFreq
	 * @start:Date start time (inclusive)
	 * @end:Date end time in yyyymmddHHMMSS format (exclusive)
	 */
	getTotalsBy : function( samplingFreq, startDate, endDate ) {
		var tStart = this.getNearestBiggerValueIndex( startDate.getTime() );
		var tEnd = this.getNearestSmallerValueIndex( endDate.getTime() );
		var getIdx, idx, d0 = startDate, d1, t0 = startDate.getTime();

		switch(samplingFreq.toLowerCase()){
			case "year":   getIdx = function(t1){d1=new Date(t1);return d1.getFullYear()-d0.getFullYear();}; break;
			case "quater": getIdx = function(t1){}; break;
			case "month":  getIdx = function(t1){d1=new Date(t1);return ((d1.getFullYear()-d0.getFullYear())*12)+(d1.getMonth()-d0.getMonth());}; break;
			case "day":    getIdx = function(t1){return Math.floor((t1-t0)/86400000); }; break;
			case "hour":   getIdx = function(t1){return Math.floor((t1-t0)/3600000); }; break;
			case "minute": getIdx = function(t1){return Math.floor((t1-t0)/60000); }; break;
			case "second": getIdx = function(t1){return Math.floor((t1-t0)/1000); }; break;
		}

		var totals = new Array();
		for( var i = 0; i < getIdx( endDate.getTime() ); i++ ) {
			totals.push(0);
		}

		for( var i = tStart; i <= tEnd; i++ ) {
			totals[getIdx(new Date(this.data[i]))]++;
		}
		return totals;
	},

	// Gets the nearest bigger value (Used for greater-than-or-equal-to, i.e. inclusive)
	getNearestBiggerValueIndex : function( x ) {
		if( x <= this.data[0] )
			return 0;
		if( x > this.data[this.data.length-1] )
			return -1;
		// TODO: consider using binary search
		/*
		for( var i = this.data.length-1; i >= 0; i-- ) {
			if( this.data[i] < t )
				return i+1;
		}
		*/
		var low = 0, high = this.data.length - 1, mid;
		while( low <= high ) {
			mid = Math.floor( ( low + high ) / 2 );
			if( this.data[mid] < x )
				low = mid + 1;
			else if( this.data[mid] > x )
				high = mid - 1;
			else {
				// we want to include all that matches, so make sure we capture all
				for( var i = mid; i >= 0; i-- ) {
					if( this.data[i] < x )
						return i+1;
				}
				return mid;
			}
		}
		// alert( x + ":" + low + "/" + high );
		if( this.data[low] >= x )
			return low;
		throw new Error( "Shouldn't be here!" );

	},

	// Gets the nearest smaller value (Used for smaller-than, i.e. exclusive)
	getNearestSmallerValueIndex: function( x ) {
		if( x <= this.data[0] )
			return -1;
		if( x > this.data[this.data.length-1] )
			return this.data.length-1;
		// TODO: consider using binary search
		/*
		for( var i = 0 ; i < this.data.length; i++ ) {
			return i-1;
		}
		*/
		var low = 0, high = this.data.length - 1, mid;
		while( low <= high ) {
			mid = Math.floor( ( low + high ) / 2 );
			if( this.data[mid] < x )
				low = mid + 1;
			else if( this.data[mid] > x )
				high = mid - 1;
			else {
				for( var i = mid; i >= 0; i-- ) {
					if( this.data[i] < x )
						return i;
				}
				return -1;
			}
		}
		if( this.data[high] < x )
			return high;
		throw new Error( "Shouldn't be here!" );
	},

	// integer: 99991231235959
	// 
	addRecord : function( time ) {
		var index = this.getNearestBiggerValueIndex( time );
		if(index == -1 )
			this.data.push( time );
		else
			this.data.splice( index, 0, time );
	}
});
