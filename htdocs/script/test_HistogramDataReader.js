(function()
{
	var hdr = new HistogramDataReader( [0,1,4,5,9,14,14,23,24,28,31,32] );
	var testUnit = new TestUnit();
	testUnit.assertEquals( "Test#1", hdr.getNearestSmallerValueIndex(0), -1 );
	testUnit.assertEquals( "Test#2", hdr.getNearestSmallerValueIndex(1), 0 );
	testUnit.assertEquals( "Test#3", hdr.getNearestSmallerValueIndex(14), 4 );
	testUnit.assertEquals( "Test#4", hdr.getNearestSmallerValueIndex(15), 6 );
	testUnit.assertEquals( "Test#5", hdr.getNearestSmallerValueIndex(32), 10 );
	testUnit.assertEquals( "Test#6", hdr.getNearestSmallerValueIndex(33), 11 );
	
	testUnit.assertEquals( "Test#7", hdr.getNearestBiggerValueIndex(-1), 0 );
	testUnit.assertEquals( "Test#8", hdr.getNearestBiggerValueIndex(0), 0 );
	testUnit.assertEquals( "Test#9", hdr.getNearestBiggerValueIndex(1), 1 );
	testUnit.assertEquals( "Test#10", hdr.getNearestBiggerValueIndex(4), 2 );
	testUnit.assertEquals( "Test#11", hdr.getNearestBiggerValueIndex(13), 5 );
	testUnit.assertEquals( "Test#12", hdr.getNearestBiggerValueIndex(32), 11 );
	testUnit.assertEquals( "Test#13", hdr.getNearestBiggerValueIndex(33), -1 );

	hdr.addRecord(0); testUnit.assertEquals( "Test#13", hdr.data[1], 0 );
	hdr.addRecord(13); testUnit.assertEquals( "Test#13", hdr.data[6], 13 );
	hdr.addRecord(14); testUnit.assertEquals( "Test#13", hdr.data[9], 14 );
	hdr.addRecord(15); testUnit.assertEquals( "Test#13", hdr.data[10], 15 );
	hdr.addRecord(32); testUnit.assertEquals( "Test#13", hdr.data[16], 32 );
	hdr.addRecord(33); testUnit.assertEquals( "Test#13", hdr.data[17], 33 );
	alert( hdr.data.join(",") );

	if( testUnit.hasErrors() ) {
		alert( "Test failed:\n" + testUnit.getErrorMessage() );
	}
	else {
		alert( "OK" );
	}
}); // ();