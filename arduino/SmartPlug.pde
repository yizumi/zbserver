#include <XBee.h>

// Create the XBee object
XBee xbee = XBee();

XBeeAddress64 dest64 = XBeeAddress64( 0x00000000, 0x0000FFFF ); // Broadcast
ZBTxStatusResponse txStatus;

#define PIN_COUNT 6
int pin[6] = { 13, 12, 11, 10, 9, 8 };
int mode[6] = {'L','L','L','L','L','L'};
int modeLast[6] = {'H','H','H','H','H','H'};

boolean isL1On = false;
int bufSize = 0;
uint8_t buffer[128];
Rx64Response rx64 = Rx64Response();

void setup()
{
  pinMode( pin[0], OUTPUT );
  pinMode( pin[1], OUTPUT );
  pinMode( pin[2], OUTPUT );
  pinMode( pin[3], OUTPUT );
  pinMode( pin[4], OUTPUT );
  pinMode( pin[5], OUTPUT );
  refresh();
  xbee.begin( 19200 );
}

void refresh()
{
  boolean modeChanged = false;
  for( int i = 0; i < PIN_COUNT; i++ ) {
    mode[i] = mode[i] == 'H' ? 'H' : 'L'; // Normalizing -- anything other than H is considered LOW
    if( mode[i] != modeLast[i] ) {
      digitalWrite( pin[i], mode[i] == 'H' ? HIGH : LOW );
      modeLast[i] = mode[i];
      modeChanged = true;
    }
  }
  // If anything has really changed, broadcast current state
  if( modeChanged ) {
    uint8_t payload[PIN_COUNT+2] = {'C','S'};
    for( int i = 0; i < PIN_COUNT; i++ ) {
      payload[i+2] = mode[i];
    }    
    Tx64Request zbTxState = Tx64Request( dest64, payload, sizeof( payload ) );
    xbee.send( zbTxState );
  }
}

void loop()
{
  /*
  if( Serial.available() ) {
    bufSize = 0;
    buffer[bufSize++] = Serial.read();
    while( Serial.available() ) {
      buffer[bufSize++] = Serial.read();
    }

    delay(100);
    Serial.print( "\nResponse: " );
    for( int i = 0; i < bufSize; i++ ) {
      if( buffer[i] == 0x7E ) {
        Serial.println("");
        Serial.print( "Response: " );
      }
      Serial.print( " 0x" );
      Serial.print( buffer[i], HEX );
    }
    Serial.println("");
  }

  if( !isS0Down && digitalRead( PIN_S0 ) ) {
    xbee.send( zbTxSwitchOn );
    isS0Down = true;
  }
  else if( isS0Down && !digitalRead( PIN_S0) ) {
    xbee.send( zbTxSwitchOff );
    isS0Down = false;
  }  
  */
  
  xbee.readPacket();

  if( xbee.getResponse().isAvailable()) {
    Serial.println( "Received I/O Sample from someone" );
    
    if( xbee.getResponse().getApiId() == RX_64_RESPONSE ) {
      xbee.getResponse().getRx64Response(rx64);
      int device = rx64.getData(0);
      int pin = rx64.getData(1);
      int data = rx64.getData(2);
      Serial.print( "Received: 0x" );
      Serial.print( device, HEX );
      Serial.print( " 0x" );
      Serial.print( pin, HEX );
      Serial.print( " 0x" );
      Serial.println( data, HEX );
      switch( pin ) {
        case '0': mode[0] = data; break;
        case '1': mode[1] = data; break;
        case '2': mode[2] = data; break;
        case '3': mode[3] = data; break;
        case '4': mode[4] = data; break;
        case '5': mode[5] = data; break;
      }
      refresh();
    }
  }
  else if( xbee.getResponse().isError() ) {
    switch( xbee.getResponse().getErrorCode() ) {
      case CHECKSUM_FAILURE:
        Serial.println( "ERROR: Checksum Failure" );
        break;
      case PACKET_EXCEEDS_BYTE_ARRAY_LENGTH:
        Serial.println( "ERROR: Byte Array Length Excess" );
        break;
      case UNEXPECTED_START_BYTE:
        Serial.println( "ERROR: Unexpected Start Byte" );
        break;
      default:
        Serial.println( "ERROR: Unknown" );
        break;
    }
  }
}

