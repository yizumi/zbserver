
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

var FastGrid = Class.create( {
	initialize : function( elm, cm ) {
		this.elm = elm;
		this.cm = cm;

		for( var i = 0 ; i < this.cm.length; i++ ) {
			if( typeof(this.cm[i].format) != "function" ) {
				this.cm[i].format = this.v;
			}
		}
	},
	
	// a method that simply returns the passed value
	v : function(v) {
		return v;
	},
	
	setHeader : function( i, title ) {
		this.cm[i].title = title;
	},
	
	draw : function( data ) {
		var html = '<table class="grid-table"><tr class="grid-header-row">';
		$A(this.cm).each(function(col, i){ html += '<td class="grid-header-cell grid-header-'+col.dataField+'">'+col.title+'</td>';});
		html += '</tr><tbody class="grid-body">';
		for( var row = 0; row < data.length; row++) {
			html += '<tr class="grid-data-row">';
			for( var col = 0; col < this.cm.length; col++ ) {
				var c = this.cm[col];
				html += '<td class="grid-data-cell grid-data-'+c.dataField+(row%2?" grid-data-alt":"")+'">'+
					c.format(data[row][c.dataField],data[row])+"</td>";
			}
			html += '</tr>';
		}
		html += '</tbody></table>';
		this.elm.innerHTML = html;
	}
} );

/*
function test_Grid()
{
	var cm = new ColumnModel( [
		{ title: "会社名", width : 150, dataField : "company" },
		{ title: "氏名", width : 200, dataField : "name" },
		{ title: "連絡先", width : "auto", dataField: "telnumber", format : function(v) { return new Element("A",{href:"#call:"+v}).update(v); } },
		{ title: "保有量", width : "auto", dataField: "holdings", format : function(v){ return v.commify() } }
	] );

	var data = [
		{ company : "Visual Japan", name : "Yusuke Izumi", telnumber: "03-5424-2345", holdings : -1000000 },
		{ company : "Morgan Stanley", name : "Jaime Manzone", telnumber: "03-5424-1234", holdings: 20000 },
		{ company : "Zero Labs", name : "Kevin Seng", telnumber : "03-1234-9999", holdings: 40000 },
		{ company : "Cheng Industry", name : "(Company)", telnumber : "03-5123-1234", holdings: 50.1 }
	];

	var gridDiv;
	var grid = new Grid( gridDiv = new Element("div"), cm, data );
	document.body.appendChild( gridDiv );
	grid.draw();
}
*/