/*
 * IRrecord: record and play back IR signals as a minimal 
 * An IR detector/demodulator must be connected to the input RECV_PIN.
 * An IR LED must be connected to the output PWM pin 3.
 * A button must be connected to the input BUTTON_PIN; this is the
 * send button.
 * A visible LED can be connected to STATUS_PIN to provide status.
 *
 * The logic is:
 * If the button is pressed, send the IR code.
 * If an IR code is received, record it.
 *
 * Version 0.11 September, 2009
 * Copyright 2009 Ken Shirriff
 * http://arcfn.com
 */

#include <IRremote.h>
#include <XBee.h>

int RECV_PIN = 11;
int BUTTON_PIN = 12;
int STATUS_PIN = 13;
int HASH_SIZE = 16;
byte HASH[16];

XBee xbee = XBee();
XBeeAddress64 dest64 = XBeeAddress64( 0x00000000, 0x0000FFFF ); // Broadcast

IRrecv irrecv(RECV_PIN);
IRsend irsend;

decode_results results;

void setup()
{
  xbee.begin( 19200 );
  irrecv.enableIRIn(); // Start the receiver
  pinMode(BUTTON_PIN, INPUT);
  pinMode(STATUS_PIN, OUTPUT);
}

// Storage for the recorded code
// int codeType = -1; // The type of code
// unsigned long codeValue; // The code value if not raw
// unsigned int rawCodes[RAWBUF]; // The durations if raw
// int codeLen; // The length of the code
// int toggle = 0; // The RC5/6 toggle state

// Initializes Hash
void initTickList()
{
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
      HASH[i] = ticks;
      return i;
    }
  }
}

// Stores the code for later playback
// Most of this code is just logging
void storeCode(decode_results *results) {
  int codeType = results->decode_type;
  int count = results->rawlen;
  if (codeType == UNKNOWN) {
    // Serial.println("Received unknown code, saving as raw");
    int codeLen = results->rawlen - 1;
    initTickList();
    uint8_t payload[codeLen+1];// for int's
    int data[codeLen];
    payload[0] = lowByte(codeType);
    // To store raw codes:
    // Drop first value (gap)
    // Convert from ticks to microseconds
    // Tweak marks shorter, and spaces longer to cancel out IR receiver distortion
    for (int i = 1; i <= codeLen; i++) {
      // if (i % 2) {
        // Mark
        // rawCodes[i - 1] = results->rawbuf[i]*USECPERTICK - MARK_EXCESS;
        data[i-1] = getIndexForTicks( lowByte( results->rawbuf[i] ) ); // Recording in ticks, so we can downsize to bytes
        Serial.print( " 0x" );
        Serial.print( data[i-1], HEX );
        // payload[(i*2)] = lowByte( a );
        // Serial.print( a, DEC );
        // Serial.print( "mt " );
        //Serial.print(" m");
      // } 
      // else {
        // Space
        // rawCodes[i - 1] = results->rawbuf[i]*USECPERTICK + MARK_EXCESS;
        // byte b = lowByte(results->rawbuf[i]); // Recording in ticks, so we can downsize to bytes
        // payload[i] = b;
        // payload[(i*2)] = lowByte( b );
        // Serial.print( b, DEC );
        // Serial.print( "st " );
        //Serial.print(" s");
      // }
      //Serial.print(rawCodes[i - 1], DEC);
    }
    //Serial.print("Length: ");
    //Serial.print( codeLen, DEC );
    //Serial.println( " bytes" );
    Tx64Request txRawCode = Tx64Request( dest64, payload, sizeof(payload) );  // count is int, so int * codeLen = size
    // xbee.send( txRawCode );
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
    else if (codeType == SONY) {
      //Serial.print("Received SONY: ");
    } 
    else if (codeType == RC5) {
      //Serial.print("Received RC5: ");
    } 
    else if (codeType == RC6) {
      //Serial.print("Received RC6: ");
    } 
    else {
      //Serial.print("Unexpected codeType ");
      //Serial.print(codeType, DEC);
      //Serial.println("");
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

void sendCode(int repeat) {
  /*
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
  */
}

int lastButtonState;

void loop() {
  // If button pressed, send the code.
  int buttonState = digitalRead(BUTTON_PIN);
  if (lastButtonState == HIGH && buttonState == LOW) {
    // Serial.println("Released");
    irrecv.enableIRIn(); // Re-enable receiver
  }

  if (buttonState) {
    // Serial.println("Pressed, sending");
    digitalWrite(STATUS_PIN, HIGH);
    sendCode(lastButtonState == buttonState);
    digitalWrite(STATUS_PIN, LOW);
    delay(50); // Wait a bit between retransmissions
  } 
  else if (irrecv.decode(&results)) {
    digitalWrite(STATUS_PIN, HIGH);
    storeCode(&results);
    irrecv.resume(); // resume receiver
    digitalWrite(STATUS_PIN, LOW);
  }
  lastButtonState = buttonState;
}

