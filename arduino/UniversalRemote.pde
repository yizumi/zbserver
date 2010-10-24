/*
 * Copyright (c) 2009, Yusuke Izumi <yizumi@ripplesystem.com>
 
 * Permission to use, copy, modify, and/or distribute this software for any
 * non-commercial purpose with or without fee is hereby granted, provided that
 * the above copyright notice and this permission notice appear in all copies.
 
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

 * UniversalRemote: record and send IR signals via XBee
 * Receives XBee request and play back IR signals
 */

#include <IRremote.h>
#include <XBee.h>

int STATUS_PIN  = 13;
int RECV_PIN    = 12;

int BUTTON1_PIN  = 11;
int BUTTON2_PIN  = 10;
int BUTTON3_PIN  = 9;

int HASH_SIZE   = 16;
int HASH_LENGTH = 0;

byte HASH[16];

int lastButtonState1;
int lastButtonState2;
int lastButtonState3;

XBee xbee = XBee();
XBeeAddress64 dest64 = XBeeAddress64( 0x00000000, 0x0000FFFF ); // Broadcast
Rx64Response rx64 = Rx64Response();

IRrecv irrecv(RECV_PIN);
IRsend irsend;

decode_results results;

void setup()
{
  xbee.begin( 19200 );
  irrecv.enableIRIn(); // Start the receiver
  pinMode(BUTTON1_PIN, INPUT);
  pinMode(BUTTON2_PIN, INPUT);
  pinMode(BUTTON3_PIN, INPUT);
  pinMode(STATUS_PIN, OUTPUT);
}

// Initializes Hash
void initTickList()
{
  HASH_LENGTH = 0;
  for( int i = 0; i <  HASH_SIZE; i++ )
  {
    HASH[i] = 0x00;
  }
}

// Get index for the given ticks
int getIndexForTicks( byte ticks )
{
  for( int i = 0 ;i < HASH_SIZE; i++ ) {
    if( HASH[i] == 0 || HASH[i] == ticks ) {
      if( i + 1 > HASH_LENGTH )
        HASH_LENGTH = i +1;
      HASH[i] = ticks;
      return i;
    }
  }
}

void quantize( volatile unsigned int *data, int len )
{
  short ticksSize = 0;
  short ticks[] = { 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 };
  short count[] = { 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 };
  short qticks[] = { -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1 }; // quantized ticks
  
  // Serial.print( "Length: " ); Serial.println( len );
  
  // Find how many elements there are in each tick bucket.
  for( int i = 0 ; i < len; i++ ) {
    // Serial.print( data[i+1] ); Serial.print( " " );
    for( short n = 0; n < 32; n++ ) {
      if( ticks[n] == 0 ) {
        ticks[n] = lowByte( data[i+1] );
        ticksSize = n;
      }
      if( ticks[n] == lowByte( data[i+1] ) ) {
        count[n]++;
        break;
      }
    }
  }
  
  // Seek for groups by finding adjacent items
  for( short t = 0 ; t < ticksSize; t++ ) {
    if( qticks[t] > -1 ) continue;
    for( short s = t + 1; s < ticksSize; s++ ) {
      if( qticks[s] > -1 ) continue;
      for( short u = s + 1; u < ticksSize; u++ ) {
        if( qticks[u] > -1 ) continue;
        // If Tom is the middle guy
        if( ( ticks[t] - 1 == ticks[s] && ticks[t] + 1 == ticks[u] ) ||
            ( ticks[t] - 1 == ticks[u] && ticks[t] + 1 == ticks[s] ) ) {
          qticks[t] = ticks[t]; qticks[s] = ticks[t]; qticks[u] = ticks[t];
        }
        // If Sammy is the middle guy
        if( ( ticks[s] - 1 == ticks[t] && ticks[s] + 1 == ticks[u] ) ||
            ( ticks[s] - 1 == ticks[u] && ticks[s] + 1 == ticks[t] ) ) {
          qticks[t] = ticks[s]; qticks[s] = ticks[s]; qticks[u] = ticks[s];
        }
        // If Uske is the middle guy
        if( ( ticks[u] - 1 == ticks[t] && ticks[u] + 1 == ticks[s] ) ||
            ( ticks[u] - 1 == ticks[s] && ticks[u] + 1 == ticks[t] ) ) {
          qticks[t] = ticks[u]; qticks[s] = ticks[u]; qticks[u] = ticks[u];
        }        
      }
    }
    if( qticks[t] == -1 ) {
      qticks[t] = ticks[t];
    }
  }
  
  // if( ticksSize >= 16 ) {
    for( short i = 1 ; i <= len; i++ ) {
      if( data[i] > 0 ) {
        for( short t = 0 ; t < ticksSize; t++ ) {
          if( data[i] == ticks[t] ) {
            data[i] = qticks[t];
          }        
        }
      }
    }
  // }
#ifdef X_DEBUG
  else {
    Serial.println( "Not quantizing the data" );
  }
#endif
  
  // for( short i = 0; i < ticksSize; i++ ) {
  //   Serial.print( "[" ); Serial.print( i ); Serial.print( "] " );
  //   Serial.print( ticks[i] ); Serial.print( " " ); Serial.print( count[i] ); Serial.print( " " ); Serial.println( qticks[i] );
  // }
}

// Stores the code for later playback
// Most of this code is just logging
void storeCode(decode_results *results) {
  int codeType = results->decode_type;
  int count = results->rawlen;
  if (codeType == UNKNOWN) {
    // Serial.println("Received unknown code, saving as raw");
    int codeLen = results->rawlen - 1;
    quantize( results->rawbuf, codeLen );
    /*
    Serial.print( "\nRAW: " );
    for (int i = 1; i <= codeLen; i++) {
      if (i % 2) {
        // Mark
        Serial.print( results->rawbuf[i]*USECPERTICK - MARK_EXCESS, DEC );
        Serial.print("m ");
      } 
      else {
        // Space
        Serial.print( results->rawbuf[i]*USECPERTICK + MARK_EXCESS, DEC );
        Serial.print("s ");
      }
    }
    Serial.println("");
    */

    int codeLenHalf = ( codeLen / 2 ) + (codeLen % 2);
    initTickList();
    uint8_t data[codeLenHalf];

    for (int i = 1; i <= codeLen; i++) {
      // Serial.print( results->rawbuf[i] * 50 ); Serial.println( "ms ");
      if( i % 2 ) {
        data[(i-1)/2] = getIndexForTicks( lowByte( results->rawbuf[i] ) ) << 4; // Recording in ticks, so we can downsize to bytes
        // Serial.print( "M: 0x" ); Serial.println( data[(i-1)/2], HEX );
      }
      else {
        data[(i-1)/2] += getIndexForTicks( lowByte( results->rawbuf[i] ) ); // Recording in ticks, so we can downsize to bytes
        // Serial.print( "S: 0x" ); Serial.println( data[(i-1)/2], HEX );        
      }
    }
    //Serial.print("Length: "); Serial.print( codeLen, DEC ); Serial.println( " bytes" );
    int payloadLen = 2 + HASH_LENGTH + codeLenHalf;
    uint8_t payload[payloadLen];// for int's
    payload[0] = lowByte(codeType);
    payload[1] = lowByte(HASH_LENGTH);
    for( int i = 0 ; i < HASH_LENGTH; i++ ) {
      payload[i+2] = HASH[i];
    }
    for( int i = 0 ; i < codeLenHalf; i++ ) {
      payload[i+2+HASH_LENGTH] = data[i];
    }
    //for( int i = 0 ; i < payloadLen; i++ ) {
    //  Serial.print( "[" ); Serial.print( i ); Serial.print( "] 0x" ); Serial.println( payload[i], HEX );
    //}
    Tx64Request txRawCode = Tx64Request( dest64, payload, sizeof(payload) );  // count is int, so int * codeLen = size
    xbee.send( txRawCode );
  }
  else {
    if (codeType == NEC) {
      //Serial.print("Received NEC: ");
      if (results->value == REPEAT) {
        // Don't record a NEC repeat value as that's useless.
        //Serial.println("repeat; ignoring.");
        return;
      }
    } 
    unsigned long codeValue = results->value;
    byte a = (byte) codeValue;
    byte b = lowByte( codeValue >> 8 );
    byte c = lowByte( codeValue >> 16 );
    byte d = lowByte( codeValue >> 24 );
    // Serial.println( a, HEX );
    // Serial.println( b, HEX );
    // Serial.println( c, HEX );
    // Serial.println( d, HEX );
    int codeLen = results->bits;
    uint8_t payload[1 + 2 + 4];
    payload[0] = lowByte(codeType);
    payload[1] = highByte(codeLen);
    payload[2] = lowByte(codeLen);
    payload[6] = a;
    payload[5] = b;
    payload[4] = c;
    payload[3] = d;
    Tx64Request zbKnownCode = Tx64Request( dest64, payload, sizeof( payload ) );
    // Serial.println( payload, HEX );
    xbee.send( zbKnownCode );
  }
}

// Storage for the recorded code
// int codeType = -1; // The type of code
// unsigned long codeValue; // The code value if not raw
// unsigned int rawCodes[RAWBUF]; // The durations if raw
// int codeLen; // The length of the code
// int toggle = 0; // The RC5/6 toggle state

void sendCode(int repeat, int codeType, unsigned long codeValue, unsigned int rawCodes[], int codeLen, int toggle) {
  if (codeType == NEC) {
    if (repeat) {
      irsend.sendNEC(REPEAT, codeLen);
      // Serial.println("Sent NEC repeat");
    } 
    else {
      irsend.sendNEC(codeValue, codeLen);
      // Serial.print("Sent NEC ");
      // Serial.println(codeValue, HEX);
    }
  } 
  else if (codeType == SONY) {
    for( int i = 0 ; i < 3; i++ ) {
      irsend.sendSony(codeValue, codeLen);
      delay( 100 );
    }
    // Serial.print("Sent Sony ");
    // Serial.println(codeValue, HEX);
  } 
  else if (codeType == RC5 || codeType == RC6) {
    if (!repeat) {
      // Flip the toggle bit for a new button press
      toggle = 1 - toggle;
    }
    // Put the toggle bit into the code to send
    codeValue = codeValue & ~(1 << (codeLen - 1));
    codeValue = codeValue | (toggle << (codeLen - 1));
    if (codeType == RC5) {
      Serial.print("Sent RC5 ");
      Serial.println(codeValue, HEX);
      irsend.sendRC5(codeValue, codeLen);
    } 
    else {
      irsend.sendRC6(codeValue, codeLen);
      // Serial.print("Sent RC6 ");
      // Serial.println(codeValue, HEX);
    }
  } 
  // Raw
  else if (codeType == UNKNOWN ) {
    // Assume 38 KHz
    irsend.sendRaw(rawCodes, codeLen, 38);
    // Serial.println("Sent raw");
  }
}

void loop() {
  // If button pressed, send the code.
  int buttonState1 = digitalRead(BUTTON1_PIN);
  int buttonState2 = digitalRead(BUTTON2_PIN);
  int buttonState3 = digitalRead(BUTTON3_PIN);
  
  if (lastButtonState1 != buttonState1 ) {
    lastButtonState1 = buttonState1;
    uint8_t payload[3];
    payload[0] = 'B';
    payload[1] = '1';
    payload[2] = buttonState1 ? '1' : '0';
    Tx64Request zbKnownCode = Tx64Request( dest64, payload, sizeof( payload ) );
    xbee.send( zbKnownCode );
    return;
  }

  if (lastButtonState2 != buttonState2 ) {
    lastButtonState2 = buttonState2;
    uint8_t payload[3];
    payload[0] = 'B';
    payload[1] = '2';
    payload[2] = buttonState2 ? '1' : '0';
    Tx64Request zbKnownCode = Tx64Request( dest64, payload, sizeof( payload ) );
    xbee.send( zbKnownCode );
    return;
  }

  if (lastButtonState3 != buttonState3 ) {
    lastButtonState3 = buttonState3;
    uint8_t payload[3];
    payload[0] = 'B';
    payload[1] = '3';
    payload[2] = buttonState3 ? '1' : '0';
    Tx64Request zbKnownCode = Tx64Request( dest64, payload, sizeof( payload ) );
    xbee.send( zbKnownCode );
    return;
  }

  xbee.readPacket();
  if ( xbee.getResponse().isAvailable() ) {
    // Serial.println( "Received message from someone" );
    if( xbee.getResponse().getApiId() == RX_64_RESPONSE ) {
      xbee.getResponse().getRx64Response(rx64);
      int codeType = rx64.getData(0); // First Byte

      // Handling raw code
      if( codeType == UNKNOWN ) {
        // See how long the header is (header contains a list of tick counts)
        unsigned int headerSize = (unsigned int) rx64.getData(1);
        // Serial.print( "Header size: " ); Serial.println( headerSize );
        // Let's create the list of ticks
        unsigned short tickList[headerSize];
        int offset = 2;
        for( int i = 0; i < headerSize; i++ ) {
          tickList[i] = (short) rx64.getData(offset + i);
          // Serial.print( "Tick[" ); Serial.print( i ); Serial.print( "=" ); Serial.println( tickList[i] );
        }
        
        // Let's convert the data into rawCodes
        offset += headerSize;
        int codeLen = (rx64.getDataLength() - offset) * 2;
        unsigned int rawCodes[codeLen];
        // Serial.print( "Code Length: " ); Serial.println( codeLen );
        for( int i = 0; i < codeLen; i++ ) {
          // Read data
          unsigned short b = (byte) rx64.getData( offset + (i/2) );
          // Read Upper Byte  
          if( (i % 2) == 0 ) {
            unsigned short ix = b >> 4;
            rawCodes[i] = tickList[ix] * USECPERTICK - MARK_EXCESS; // Marks (Upper byte)
            // Serial.print( rawCodes[i] ); Serial.print( "m " );
          }
          else {
            unsigned short ix = b & 0xF;
            // Serial.print( ix ); Serial.print( "-");
            rawCodes[i] = tickList[ix] * USECPERTICK + MARK_EXCESS; // Spaces (Lower Byte)
            // Serial.print( rawCodes[i] ); Serial.print( "s " );
          }
        }
        // Serial.println();
        // Now Send it!
        sendCode( 0, codeType, 0, rawCodes, codeLen, 0 );
        // Serial.println( "Done" );
      }
      // Handling Known Code
      else {
        int codeLen = ( rx64.getData(1) << 8 ) + rx64.getData(2); // Length

        unsigned long a = (unsigned long)rx64.getData(3);
        unsigned long b = (unsigned long)rx64.getData(4);
        unsigned long c = (unsigned long)rx64.getData(5);
        unsigned long d = (unsigned long)rx64.getData(6);

        unsigned long codeValue = (unsigned long) (a << 24) | (b << 16) | (c << 8) | d;
        // Serial.print( "CodeType: " ); Serial.println( codeType, DEC );
        // Serial.print( "CodeLen: " ); Serial.println( codeLen, DEC );
        // Serial.print( "CodeValue: " ); Serial.println( codeValue, HEX );
        unsigned int rawCodes[0];
        sendCode( 0, codeType, codeValue, rawCodes, codeLen, 0 );
      }
    }
    irrecv.enableIRIn(); // resume receiver
  }
  /*
  else if (buttonState) {
    // Serial.println("Pressed, sending");
    // digitalWrite(STATUS_PIN, HIGH);
    // sendCode(lastButtonState == buttonState);
    // digitalWrite(STATUS_PIN, LOW);
    // delay(50); // Wait a bit between retransmissions
  } 
  */
  else if (irrecv.decode(&results)) {
    digitalWrite(STATUS_PIN, HIGH);
    storeCode(&results);
    irrecv.resume(); // resume receiver
    digitalWrite(STATUS_PIN, LOW);
  }
}
