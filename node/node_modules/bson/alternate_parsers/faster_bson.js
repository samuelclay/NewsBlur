/// reduced to ~ 410 LOCs (parser only 300 vs. 1400+) with (some, needed) BSON classes "inlined".
/// Compare ~ 4,300 (22KB vs. 157KB) in browser build at: https://github.com/mongodb/js-bson/blob/master/browser_build/bson.js

module.exports.calculateObjectSize = calculateObjectSize;

function calculateObjectSize(object) {
    var totalLength = (4 + 1);      /// handles the obj.length prefix + terminating '0' ?!
    for(var key in object) {        /// looks like it handles arrays under the same for...in loop!?
      totalLength += calculateElement(key, object[key])
    }
    return totalLength;
}

function calculateElement(name, value) {
    var len = 1;                                /// always starting with 1 for the data type byte!
    if (name) len += Buffer.byteLength(name, 'utf8') + 1;   /// cstring: name + '0' termination

    if (value === undefined || value === null) return len;  /// just the type byte plus name cstring
    switch( value.constructor ) {      /// removed all checks 'isBuffer' if Node.js Buffer class is present!?

        case ObjectID:          /// we want these sorted from most common case to least common/deprecated;
            return len + 12;
        case String:
            return len + 4 + Buffer.byteLength(value, 'utf8') +1; ///
        case Number:
            if (Math.floor(value) === value) {  /// case: integer; pos.# more common, '&&' stops if 1st fails!
                if ( value <= 2147483647 && value >= -2147483647 ) // 32 bit
                    return len + 4;
                else return len + 8;    /// covers Long-ish JS integers as Longs!
            } else return len + 8;      /// 8+1 --- covers Double & std. float
        case Boolean:
            return len + 1;

        case Array:
        case Object:
            return len + calculateObjectSize(value);

        case Buffer:   ///  replaces the entire Binary class!
            return len + 4 + value.length + 1;

        case Regex:  /// these are handled as strings by serializeFast() later, hence 'gim' opts = 3 + 1 chars
            return len + Buffer.byteLength(value.source, 'utf8') + 1
                + (value.global ? 1 : 0) + (value.ignoreCase ? 1 : 0) + (value.multiline ? 1 : 0) +1;
        case Date:
        case Long:
        case Timestamp:
        case Double:
            return len + 8;

        case MinKey:
        case MaxKey:
            return len;     /// these two return the type byte and name cstring only!
    }
    return 0;
}

module.exports.serializeFast = serializeFast;
module.exports.serialize = function(object, checkKeys, asBuffer, serializeFunctions, index) {
  var buffer = new Buffer(calculateObjectSize(object));
  return serializeFast(object, checkKeys, buffer, 0);
}

function serializeFast(object, checkKeys, buffer, i) {   /// set checkKeys = false in query(..., options object to save performance IFF you're certain your keys are safe/system-set!
    var size = buffer.length;
    buffer[i++] = size & 0xff; buffer[i++] = (size >> 8) & 0xff;   /// these get overwritten later!
    buffer[i++] = (size >> 16) & 0xff; buffer[i++] = (size >> 24) & 0xff;

    if (object.constructor === Array) {     /// any need to checkKeys here?!? since we're doing for rather than for...in, should be safe from extra (non-numeric) keys added to the array?!
        for(var j = 0; j < object.length; j++) {
            i = packElement(j.toString(), object[j], checkKeys, buffer, i);
        }
    } else {   /// checkKeys is needed if any suspicion of end-user key tampering/"injection" (a la SQL)
        for(var key in object) {    /// mostly there should never be direct access to them!?
            if (checkKeys && (key.indexOf('\x00') >= 0 || key === '$where') ) {  /// = "no script"?!; could add back key.indexOf('$') or maybe check for 'eval'?!
/// took out: || key.indexOf('.') >= 0...  Don't we allow dot notation queries?!
                console.log('checkKeys error: ');
                return new Error('Illegal object key!');
            }
            i = packElement(key, object[key], checkKeys, buffer, i);  /// checkKeys pass needed for recursion!
        }
    }
    buffer[i++] = 0;   /// write terminating zero; !we do NOT -1 the index increase here as original does!
    return i;
}

function packElement(name, value, checkKeys, buffer, i) {    /// serializeFunctions removed! checkKeys needed for Array & Object cases pass through (calling serializeFast recursively!)
    if (value === undefined || value === null){
        buffer[i++] = 10;                                       /// = BSON.BSON_DATA_NULL;
        i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;    /// buffer.write(...) returns bytesWritten!
        return i;
    }
    switch(value.constructor) {

    case ObjectID:
        buffer[i++] = 7;   /// = BSON.BSON_DATA_OID;
        i += buffer.write(name, i, 'utf8');     buffer[i++] = 0;
///     i += buffer.write(value.id, i, 'binary');  ///  OLD: writes a String to a Buffer; 'binary' deprecated!!
        value.id.copy(buffer, i);  /// NEW ObjectID version has this.id = Buffer at the ready!
        return i += 12;

    case String:
        buffer[i++] = 2;    ///  = BSON.BSON_DATA_STRING;
        i += buffer.write(name, i, 'utf8');     buffer[i++] = 0;

        var size = Buffer.byteLength(value) + 1;  /// includes the terminating '0'!?
        buffer[i++] = size & 0xff; buffer[i++] = (size >> 8) & 0xff;
        buffer[i++] = (size >> 16) & 0xff; buffer[i++] = (size >> 24) & 0xff;

        i += buffer.write(value, i, 'utf8');    buffer[i++] = 0;
        return i;

    case Number:
        if ( ~~(value) === value) {     /// double-Tilde is equiv. to Math.floor(value)
            if ( value <= 2147483647 && value >= -2147483647){ /// = BSON.BSON_INT32_MAX / MIN asf.
                buffer[i++] = 16;   /// = BSON.BSON_DATA_INT;
                i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;
                buffer[i++] = value & 0xff; buffer[i++] = (value >> 8) & 0xff;
                buffer[i++] = (value >> 16) & 0xff; buffer[i++] = (value >> 24) & 0xff;

// Else large-ish JS int!? to Long!?
            } else {  /// if (value <= BSON.JS_INT_MAX && value >= BSON.JS_INT_MIN){ /// 9007199254740992 asf.
                buffer[i++] = 18;   /// = BSON.BSON_DATA_LONG;
                i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;
                var lowBits = ( value % 4294967296 ) | 0, highBits = ( value / 4294967296 ) | 0;

                buffer[i++] = lowBits & 0xff;           buffer[i++] = (lowBits >> 8) & 0xff;
                buffer[i++] = (lowBits >> 16) & 0xff;   buffer[i++] = (lowBits >> 24) & 0xff;
                buffer[i++] = highBits & 0xff;          buffer[i++] = (highBits >> 8) & 0xff;
                buffer[i++] = (highBits >> 16) & 0xff;  buffer[i++] = (highBits >> 24) & 0xff;
            }
        } else {    /// we have a float / Double
            buffer[i++] = 1;    /// = BSON.BSON_DATA_NUMBER;
            i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;
/// OLD:    writeIEEE754(buffer, value, i, 'little', 52, 8);
            buffer.writeDoubleLE(value, i);     i += 8;
        }
        return i;

    case Boolean:
        buffer[i++] = 8;    /// = BSON.BSON_DATA_BOOLEAN;
        i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;
        buffer[i++] = value ? 1 : 0;
        return i;

    case Array:
    case Object:
        buffer[i++] = value.constructor === Array ? 4 : 3; /// = BSON.BSON_DATA_ARRAY / _OBJECT;
        i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;

	    var endIndex = serializeFast(value, checkKeys, buffer, i); /// + 4); no longer needed b/c serializeFast writes a temp 4 bytes for length
        var size = endIndex - i;
        buffer[i++] = size & 0xff;          buffer[i++] = (size >> 8) & 0xff;
        buffer[i++] = (size >> 16) & 0xff;  buffer[i++] = (size >> 24) & 0xff;
        return endIndex;

    /// case Binary:        /// is basically identical unless special/deprecated options!
    case Buffer:            /// solves ALL of our Binary needs without the BSON.Binary class!?
        buffer[i++] = 5;    /// = BSON.BSON_DATA_BINARY;
        i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;
        var size = value.length;
        buffer[i++] = size & 0xff;          buffer[i++] = (size >> 8) & 0xff;
        buffer[i++] = (size >> 16) & 0xff;  buffer[i++] = (size >> 24) & 0xff;

        buffer[i++] = 0;        /// write BSON.BSON_BINARY_SUBTYPE_DEFAULT;
        value.copy(buffer, i);  ///, 0, size); << defaults to sourceStart=0, sourceEnd=sourceBuffer.length);
        i += size;
        return i;

    case RegExp:
        buffer[i++] = 11;   /// = BSON.BSON_DATA_REGEXP;
        i += buffer.write(name, i, 'utf8');         buffer[i++] = 0;
        i += buffer.write(value.source, i, 'utf8'); buffer[i++] = 0x00;

        if (value.global) buffer[i++] = 0x73;        // s = 'g' for JS Regex!
        if (value.ignoreCase) buffer[i++] = 0x69;    // i
        if (value.multiline) buffer[i++] = 0x6d;     // m
        buffer[i++] = 0x00;
        return i;

    case Date:
        buffer[i++] = 9;    /// = BSON.BSON_DATA_DATE;
        i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;
        var millis = value.getTime();
        var lowBits = ( millis % 4294967296 ) | 0, highBits = ( millis / 4294967296 ) | 0;

        buffer[i++] = lowBits & 0xff;           buffer[i++] = (lowBits >> 8) & 0xff;
        buffer[i++] = (lowBits >> 16) & 0xff;   buffer[i++] = (lowBits >> 24) & 0xff;
        buffer[i++] = highBits & 0xff;          buffer[i++] = (highBits >> 8) & 0xff;
        buffer[i++] = (highBits >> 16) & 0xff;  buffer[i++] = (highBits >> 24) & 0xff;
        return i;

    case Long:
    case Timestamp:
        buffer[i++] = value.constructor === Long ? 18 : 17; /// = BSON.BSON_DATA_LONG / _TIMESTAMP
        i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;
        var lowBits = value.getLowBits(), highBits = value.getHighBits();

        buffer[i++] = lowBits & 0xff;           buffer[i++] = (lowBits >> 8) & 0xff;
        buffer[i++] = (lowBits >> 16) & 0xff;   buffer[i++] = (lowBits >> 24) & 0xff;
        buffer[i++] = highBits & 0xff;          buffer[i++] = (highBits >> 8) & 0xff;
        buffer[i++] = (highBits >> 16) & 0xff;  buffer[i++] = (highBits >> 24) & 0xff;
        return i;

    case Double:
        buffer[i++] = 1;    /// = BSON.BSON_DATA_NUMBER;
        i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;
/// OLD: writeIEEE754(buffer, value, i, 'little', 52, 8);    i += 8;
        buffer.writeDoubleLE(value, i);     i += 8;
        return i

    case MinKey:    /// = BSON.BSON_DATA_MINKEY;
        buffer[i++] = 127; i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;
        return i;
    case MaxKey:    /// = BSON.BSON_DATA_MAXKEY;
        buffer[i++] = 255; i += buffer.write(name, i, 'utf8'); buffer[i++] = 0;
        return i;

    } /// end of switch
    return i;   /// ?! If no value to serialize
}


module.exports.deserializeFast = deserializeFast;

function deserializeFast(buffer, i, isArray){   //// , options, isArray) {       //// no more options!
    if (buffer.length < 5) return new Error('Corrupt bson message < 5 bytes long'); /// from 'throw'
    var elementType, tempindex = 0, name;
    var string, low, high;              /// = lowBits / highBits
                                        /// using 'i' as the index to keep the lines shorter:
    i || ( i = 0 );  /// for parseResponse it's 0; set to running index in deserialize(object/array) recursion
    var object = isArray ? [] : {};         /// needed for type ARRAY recursion later!
    var size = buffer[i++] | buffer[i++] << 8 | buffer[i++] << 16 | buffer[i++] << 24;
    if(size < 5 || size > buffer.length) return new Error('Corrupt BSON message');
/// 'size' var was not used by anything after this, so we can reuse it

    while(true) {                           // While we have more left data left keep parsing
        elementType = buffer[i++];          // Read the type
        if (elementType === 0) break;       // If we get a zero it's the last byte, exit

        tempindex = i;  /// inlined readCStyleString & removed extra i<buffer.length check slowing EACH loop!
        while( buffer[tempindex] !== 0x00 ) tempindex++;  /// read ahead w/out changing main 'i' index
        if (tempindex >= buffer.length) return new Error('Corrupt BSON document: illegal CString')
        name = buffer.toString('utf8', i, tempindex);
        i = tempindex + 1;               /// Update index position to after the string + '0' termination

        switch(elementType) {

        case 7:     /// = BSON.BSON_DATA_OID:
            var buf = new Buffer(12);
            buffer.copy(buf, 0, i, i += 12 );   /// copy 12 bytes from the current 'i' offset into fresh Buffer
            object[name] = new ObjectID(buf);   ///... & attach to the new ObjectID instance
            break;

        case 2:     /// = BSON.BSON_DATA_STRING:
            size = buffer[i++] | buffer[i++] <<8 | buffer[i++] <<16 | buffer[i++] <<24;
            object[name] = buffer.toString('utf8', i, i += size -1 );
            i++;        break;          /// need to get the '0' index "tick-forward" back!

        case 16:    /// = BSON.BSON_DATA_INT:        // Decode the 32bit value
            object[name] = buffer[i++] | buffer[i++] << 8 | buffer[i++] << 16 | buffer[i++] << 24;    break;

        case 1:     /// = BSON.BSON_DATA_NUMBER:     // Decode the double value
            object[name] = buffer.readDoubleLE(i);   /// slightly faster depending on dec.points; a LOT cleaner
            /// OLD: object[name] = readIEEE754(buffer, i, 'little', 52, 8);
            i += 8;     break;

        case 8:     /// = BSON.BSON_DATA_BOOLEAN:
            object[name] = buffer[i++] == 1;    break;

        case 6:     /// = BSON.BSON_DATA_UNDEFINED:     /// deprecated
        case 10:    /// = BSON.BSON_DATA_NULL:
            object[name] = null;     break;

        case 4:     /// = BSON.BSON_DATA_ARRAY
            size = buffer[i] | buffer[i+1] <<8 | buffer[i+2] <<16 | buffer[i+3] <<24;  /// NO 'i' increment since the size bytes are reread during the recursion!
            object[name] = deserializeFast(buffer, i, true );  /// pass current index & set isArray = true
            i += size;      break;
        case 3:     /// = BSON.BSON_DATA_OBJECT:
            size = buffer[i] | buffer[i+1] <<8 | buffer[i+2] <<16 | buffer[i+3] <<24;
            object[name] = deserializeFast(buffer, i, false );          /// isArray = false => Object
            i += size;      break;

        case 5:     /// = BSON.BSON_DATA_BINARY:             // Decode the size of the binary blob
            size = buffer[i++] | buffer[i++] << 8 | buffer[i++] << 16 | buffer[i++] << 24;
            buffer[i++];             /// Skip, as we assume always default subtype, i.e. 0!
            object[name] = buffer.slice(i, i += size);  /// creates a new Buffer "slice" view of the same memory!
            break;

        case 9:     /// = BSON.BSON_DATA_DATE:      /// SEE notes below on the Date type vs. other options...
            low  = buffer[i++] | buffer[i++] << 8 | buffer[i++] << 16 | buffer[i++] << 24;
            high = buffer[i++] | buffer[i++] << 8 | buffer[i++] << 16 | buffer[i++] << 24;
            object[name] = new Date( high * 4294967296 + (low < 0 ? low + 4294967296 : low) );  break;

        case 18:    /// = BSON.BSON_DATA_LONG:  /// usage should be somewhat rare beyond parseResponse() -> cursorId, where it is handled inline, NOT as part of deserializeFast(returnedObjects); get lowBits, highBits:
            low  = buffer[i++] | buffer[i++] << 8 | buffer[i++] << 16 | buffer[i++] << 24;
            high = buffer[i++] | buffer[i++] << 8 | buffer[i++] << 16 | buffer[i++] << 24;

            size = high * 4294967296 + (low < 0 ? low + 4294967296 : low);      /// from long.toNumber()
            if (size < JS_INT_MAX && size > JS_INT_MIN) object[name] = size;    /// positive # more likely!
            else object[name] = new Long(low, high);    break;

        case 127:   /// = BSON.BSON_DATA_MIN_KEY:   /// do we EVER actually get these BACK from MongoDB server?!
            object[name] = new MinKey();     break;
        case 255:   /// = BSON.BSON_DATA_MAX_KEY:
            object[name] = new MaxKey();     break;

        case 17:    /// = BSON.BSON_DATA_TIMESTAMP:   /// somewhat obscure internal BSON type; MongoDB uses it for (pseudo) high-res time timestamp (past millisecs precision is just a counter!) in the Oplog ts: field, etc.
            low  = buffer[i++] | buffer[i++] << 8 | buffer[i++] << 16 | buffer[i++] << 24;
            high = buffer[i++] | buffer[i++] << 8 | buffer[i++] << 16 | buffer[i++] << 24;
            object[name] = new Timestamp(low, high);     break;

///        case 11:    /// = RegExp is skipped; we should NEVER be getting any from the MongoDB server!?
        }   /// end of switch(elementType)
    }   /// end of while(1)
    return object;  // Return the finalized object
}


function MinKey() { this._bsontype = 'MinKey'; }  /// these are merely placeholders/stubs to signify the type!?

function MaxKey() { this._bsontype = 'MaxKey'; }

function Long(low, high) {
    this._bsontype = 'Long';
    this.low_ = low | 0;    this.high_ = high | 0;          /// force into 32 signed bits.
}
Long.prototype.getLowBits = function(){ return this.low_; }
Long.prototype.getHighBits = function(){ return this.high_; }

Long.prototype.toNumber = function(){
    return this.high_ * 4294967296 + (this.low_ < 0 ? this.low_ + 4294967296 : this.low_);
}
Long.fromNumber = function(num){
    return new Long(num % 4294967296, num / 4294967296);    /// |0 is forced in the constructor!
}
function Double(value) {
    this._bsontype = 'Double';
    this.value = value;
}
function Timestamp(low, high) {
    this._bsontype = 'Timestamp';
    this.low_ = low | 0;    this.high_ = high | 0;          /// force into 32 signed bits.
}
Timestamp.prototype.getLowBits = function(){ return this.low_; }
Timestamp.prototype.getHighBits = function(){ return this.high_; }

///////////////////////////////  ObjectID /////////////////////////////////
/// machine & proc IDs stored as 1 string, b/c Buffer shouldn't be held for long periods (could use SlowBuffer?!)

var MACHINE = parseInt(Math.random() * 0xFFFFFF, 10);
var PROCESS = process.pid % 0xFFFF;
var MACHINE_AND_PROC = encodeIntBE(MACHINE, 3) + encodeIntBE(PROCESS, 2); /// keep as ONE string, ready to go.

function encodeIntBE(data, bytes){  /// encode the bytes to a string
    var result = '';
    if (bytes >= 4){ result += String.fromCharCode(Math.floor(data / 0x1000000)); data %= 0x1000000; }
    if (bytes >= 3){ result += String.fromCharCode(Math.floor(data / 0x10000)); data %= 0x10000; }
    if (bytes >= 2){ result += String.fromCharCode(Math.floor(data / 0x100)); data %= 0x100; }
    result += String.fromCharCode(Math.floor(data));
    return result;
}
var _counter = ~~(Math.random() * 0xFFFFFF);    /// double-tilde is equivalent to Math.floor()
var checkForHex = new RegExp('^[0-9a-fA-F]{24}$');

function ObjectID(id) {
    this._bsontype = 'ObjectID';
    if (!id){  this.id = createFromScratch();     /// base case, DONE.
    } else {
        if (id.constructor === Buffer){
            this.id = id;  /// case of
        } else if (id.constructor === String) {
            if ( id.length === 24 && checkForHex.test(id) ) {
                this.id = new Buffer(id, 'hex');
            } else {
                this.id = new Error('Illegal/faulty Hexadecimal string supplied!');     /// changed from 'throw'
            }
        } else if (id.constructor === Number) {
            this.id = createFromTime(id);    /// this is what should be the only interface for this!?
        }
    }
}
function createFromScratch() {
    var buf = new Buffer(12), i = 0;
    var ts = ~~(Date.now()/1000);    /// 4 bytes timestamp in seconds, BigEndian notation!
    buf[i++] = (ts >> 24) & 0xFF;    buf[i++] = (ts >> 16) & 0xFF;
    buf[i++] = (ts >> 8) & 0xFF;     buf[i++] = (ts) & 0xFF;

    buf.write(MACHINE_AND_PROC, i, 5, 'utf8');  i += 5;  /// write 3 bytes + 2 bytes MACHINE_ID and PROCESS_ID
    _counter = ++_counter % 0xFFFFFF;       /// 3 bytes internal _counter for subsecond resolution; BigEndian
    buf[i++] = (_counter >> 16) & 0xFF;
    buf[i++] = (_counter >> 8) & 0xFF;
    buf[i++] = (_counter) & 0xFF;
    return buf;
}
function createFromTime(ts) {
    ts || ( ts = ~~(Date.now()/1000) );     /// 4 bytes timestamp in seconds only
    var buf = new Buffer(12), i = 0;
    buf[i++] = (ts >> 24) & 0xFF;    buf[i++] = (ts >> 16) & 0xFF;
    buf[i++] = (ts >> 8) & 0xFF;     buf[i++] = (ts) & 0xFF;

    for (;i < 12; ++i) buf[i] = 0x00;       /// indeces 4 through 11 (8 bytes) get filled up with nulls
    return buf;
}
ObjectID.prototype.toHexString = function toHexString() {
    return this.id.toString('hex');
}
ObjectID.prototype.getTimestamp = function getTimestamp() {
    return this.id.readUIntBE(0, 4);
}
ObjectID.prototype.getTimestampDate = function getTimestampDate() {
    var ts = new Date();
    ts.setTime(this.id.readUIntBE(0, 4) * 1000);
    return ts;
}
ObjectID.createPk = function createPk () {  ///?override if a PrivateKey factory w/ unique factors is warranted?!
  return new ObjectID();
}
ObjectID.prototype.toJSON = function toJSON() {
    return "ObjectID('" +this.id.toString('hex')+ "')";
}

/// module.exports.BSON = BSON;         /// not needed anymore!? exports.Binary = Binary;
module.exports.ObjectID = ObjectID;
module.exports.MinKey = MinKey;
module.exports.MaxKey = MaxKey;
module.exports.Long = Long;    /// ?! we really don't want to do the complicated Long math anywhere for now!?

//module.exports.Double = Double;
//module.exports.Timestamp = Timestamp;
