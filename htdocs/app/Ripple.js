
Ripple.defaultAnim = Ext.platform.isAndroidOS ? false : 'slide';

Ext.ux.UniversalUI = Ext.extend( Ext.Panel, {
	fullscreen: true,
	layout: 'card',
	initComponent : function() {
		this.backButton = new Ext.Button({
			hidden: true,
			text: 'Back',
			ui: 'back',
			handler: this.onBackButtonTap,
			scope: this
		});

		this.navigationButton = new Ext.Button({
			hidden: Ext.platform.isPhone || Ext.orientation == 'landscape',
			text: 'Navigation',
			handler: this.onNavButtonTap,
			scope: this
		});
		
		this.navigationBar = new Ext.Toolbar({
			ui: 'dark',
			dock: 'top',
			title: this.title,
			items: [this.backButton, this.navigationButton].concat(this.buttons || [] )
		});
		
		this.navigationPanel = new Ext.NestedList({
			items: this.navigationItems || [],
			dock: 'left',
			width: 250,
			height: 456,
			hidden: !Ext.platform.isPhone && Ext.orientation == 'portrait',
			toolbar: Ext.platform.isPhone ? this.navigationBar : null,
			listeners: {
				listchange : this.onListChange,
				scope: this
			}
		});

		this.dockedItems = this.dockedItems || [];
		this.dockedItems.unshift( this.navigationBar );

		if( !Ext.platform.isPhone && Ext.orientation == 'landscape' ) {
			this.dockedItems.unshift( this.navigationPanel );
		}
		else if( Ext.platform.isPhone ) {
			this.items = this.items || [];
			this.items.unshift( this.navigationPanel );
		}

		this.addEvents( "navigate" );
		Ext.ux.UniversalUI.superclass.initComponent.call(this);
	},
	
	onListChange : function( list, item ) {
		if( Ext.orientation == 'portrait' && !Ext.platform.isPhone && item.items && !item.preventHide ) {
			this.navigationPanel.hide();
		}

		if( item.card ) {
			this.setCard( item.card,item.animation || 'slide' );
			this.currentCard = item.card;
			if( item.text ){
				this.navigationBar.setTitle( item.text );
			}
			if( Ext.platform.isPhone ) {
				this.backButton.show();
				this.navigationBar.doLayout();
			}
		}
		this.fireEvent( "navigate", this, item, list );
	},
	
	onNavButtonTap : function() {
		this.navigationPanel.showBy( this.navigationButton, "fade" );
	},
	
	onBackButtonTap : function() {
		this.setCard( this.navigationPanel, {type: 'slide', direction: 'right'} );
		this.currentCard = this.navigationPanel;
		if( Ext.platform.isPhone ) {
			this.backButton.hide();
			this.navigationBar.setTitle( this.title );
			this.navigationBar.doLayout();
		}
		this.fireEvent( 'navigate', this, this.navigationPanel.activeItem, this.navigationPanel );
	},

	onOrientationChange : function( orientation, w, h ) {
		Ext.ux.UniversalUI.superclass.onOrientationChange.call( this, orientation, w, h );

		if( !Ext.platform.isPhone ) {
			if( orientation == 'portrait' ) {
				this.removeDocked( this.navigationPanel, false );
				this.navigationPanel.hide();
				this.navigationPanel.setFloating( true );
				this.navigationButton.show();
			}
			else {
				this.navigationPanel.setFloating( false );
				this.navigationPanel.show();
				this.navigationButton.hide();
				this.insertDocked(0, this.navigationPanel );
			}
		}
	}
} );

Ripple.init = function() {
	this.ui = new Ext.ux.UniversalUI({
		title: Ext.platform.isPhone ? 'Ripple' : 'Ripple System',
		navigationItems: Ripple.devices,
		buttons: [{ xtype: 'spacer'}],
		listeners: {
			navigate : this.onNavigate,
			scope: this
		}
	});
};

Ripple.onNavigate = function( ui, item ) {
	if (item.source) {
		if (this.sourceButton.hidden) {
			this.sourceButton.show();
			ui.navigationBar.doComponentLayout();
		}

		Ext.Ajax.request({
			url: item.source,
			success: function(response) {
				this.codeBox.setValue(Ext.htmlEncode(response.responseText));                   
			},
			scope: this
		});
	}
	else {
		// this.codeBox.setValue('No source for this example.');
		// this.sourceButton.hide();
		// this.sourceActive = false;
		// this.sourceButton.setText('Source');
		ui.navigationBar.doComponentLayout();
	}
};

// Ext.Ajax.method = "GET";
//  Ext.Ajax.disableCaching = true;

Ripple.sendTxRequest = function( addr64, message ) {
	Ext.Ajax.request({
		url: "/send?dest64="+addr64+"&type=byte&payload="+message+"&time="+(new Date().getTime()),
		method: 'GET',
		success : function(response,opts ) {
		},
		failure : function(response, opts ) {
		}
	});
};

Ripple.sendTxRequestHex = function( addr64, hex ) {
	Ext.Ajax.request({
		url: "/send",
		params:{
			dest64: addr64,
			type : 'hex',
			payload : hex,
			time : new Date().getTime()
		},
		success : function(response,opts ) {
		},
		failure : function(response, opts ) {
		}
	});
};