
var GridView = Class.create({
	initialize : function( element ) {
		this.elem = element;
	}
});

var GridController = Class.create({
	initialize : function( view, data ) {
		this.view = view;
		this.data = data;
		this.view.setDimention
		this.render();
	},

	render : function() {
		for( var i = 0 ; i < this.data.length; i++ ) {
		}
	}
});
