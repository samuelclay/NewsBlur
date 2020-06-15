'use strict';

var Buffer = require('safer-buffer').Buffer;

// == UTF32-LE/BE codec. ==========================================================

exports._utf32 = Utf32Codec;

function Utf32Codec(codecOptions, iconv) {
    this.iconv = iconv;
    this.bomAware = true;
    this.isLE = codecOptions.isLE;
}

exports.utf32le = { type: '_utf32', isLE: true };
exports.utf32be = { type: '_utf32', isLE: false };

// Aliases
exports.ucs4le = 'utf32le';
exports.ucs4be = 'utf32be';

Utf32Codec.prototype.encoder = Utf32Encoder;
Utf32Codec.prototype.decoder = Utf32Decoder;

// -- Encoding

function Utf32Encoder(options, codec) {
    this.isLE = codec.isLE;
    this.highSurrogate = 0;
}

Utf32Encoder.prototype.write = function(str) {
    var src = Buffer.from(str, 'ucs2');
    var dst = Buffer.alloc(src.length * 2);
    var write32 = this.isLE ? dst.writeUInt32LE : dst.writeUInt32BE;
    var offset = 0;

    for (var i = 0; i < src.length; i += 2) {
        var code = src.readUInt16LE(i);
        var isHighSurrogate = (0xD800 <= code && code < 0xDC00);
        var isLowSurrogate = (0xDC00 <= code && code < 0xE000);

        if (this.highSurrogate) {
            if (isHighSurrogate || !isLowSurrogate) {
                // There shouldn't be two high surrogates in a row, nor a high surrogate which isn't followed by a low
                // surrogate. If this happens, keep the pending high surrogate as a stand-alone semi-invalid character
                // (technically wrong, but expected by some applications, like Windows file names).
                write32.call(dst, this.highSurrogate, offset);
                offset += 4;
            }
            else {
                // Create 32-bit value from high and low surrogates;
                var codepoint = (((this.highSurrogate - 0xD800) << 10) | (code - 0xDC00)) + 0x10000;

                write32.call(dst, codepoint, offset);
                offset += 4;
                this.highSurrogate = 0;

                continue;
            }
        }

        if (isHighSurrogate)
            this.highSurrogate = code;
        else {
            // Even if the current character is a low surrogate, with no previous high surrogate, we'll
            // encode it as a semi-invalid stand-alone character for the same reasons expressed above for
            // unpaired high surrogates.
            write32.call(dst, code, offset);
            offset += 4;
            this.highSurrogate = 0;
        }
    }

    if (offset < dst.length)
        dst = dst.slice(0, offset);

    return dst;
};

Utf32Encoder.prototype.end = function() {
    // Treat any leftover high surrogate as a semi-valid independent character.
    if (!this.highSurrogate)
        return;

    var buf = Buffer.alloc(4);

    if (this.isLE)
        buf.writeUInt32LE(this.highSurrogate, 0);
    else
        buf.writeUInt32BE(this.highSurrogate, 0);

    this.highSurrogate = 0;

    return buf;
};

// -- Decoding

function Utf32Decoder(options, codec) {
    this.isLE = codec.isLE;
    this.badChar = codec.iconv.defaultCharUnicode.charCodeAt(0);
    this.overflow = null;
}

Utf32Decoder.prototype.write = function(src) {
    if (src.length === 0)
        return '';

    if (this.overflow)
        src = Buffer.concat([this.overflow, src]);

    var goodLength = src.length - src.length % 4;

    if (src.length !== goodLength) {
        this.overflow = src.slice(goodLength);
        src = src.slice(0, goodLength);
    }
    else
        this.overflow = null;

    var dst = Buffer.alloc(goodLength);
    var offset = 0;

    for (var i = 0; i < goodLength; i += 4) {
        var codepoint = this.isLE ? src.readUInt32LE(i) : src.readUInt32BE(i);

        if (codepoint < 0x10000) {
            // Simple 16-bit character
            dst.writeUInt16LE(codepoint, offset);
            offset += 2;
        }
        else {
            if (codepoint > 0x10FFFF) {
                // Not a valid Unicode codepoint
                dst.writeUInt16LE(this.badChar, offset);
                offset += 2;
            }
            else {
                // Create high and low surrogates.
                codepoint -= 0x10000;
                var high = 0xD800 | (codepoint >> 10);
                var low = 0xDC00 + (codepoint & 0x3FF);
                dst.writeUInt16LE(high, offset);
                offset += 2;
                dst.writeUInt16LE(low, offset);
                offset += 2;
            }
        }
    }

    return dst.slice(0, offset).toString('ucs2');
};

Utf32Decoder.prototype.end = function() {
    this.overflow = null;
};

// == UTF-32 Auto codec =============================================================
// Decoder chooses automatically from UTF-32LE and UTF-32BE using BOM and space-based heuristic.
// Defaults to UTF-32LE. http://en.wikipedia.org/wiki/UTF-32
// Encoder/decoder default can be changed: iconv.decode(buf, 'utf32', {defaultEncoding: 'utf-32be'});

// Encoder prepends BOM (which can be overridden with (addBOM: false}).

exports.utf32 = Utf32AutoCodec;
exports.ucs4 = Utf32AutoCodec;

function Utf32AutoCodec(options, iconv) {
    this.iconv = iconv;
}

Utf32AutoCodec.prototype.encoder = Utf32AutoEncoder;
Utf32AutoCodec.prototype.decoder = Utf32AutoDecoder;

// -- Encoding

function Utf32AutoEncoder(options, codec) {
    options = options || {};

    if (options.addBOM === undefined)
        options.addBOM = true;

    this.encoder = codec.iconv.getEncoder(options.defaultEncoding || 'utf-32le', options);
}

Utf32AutoEncoder.prototype.write = function(str) {
    return this.encoder.write(str);
};

Utf32AutoEncoder.prototype.end = function() {
    return this.encoder.end();
};

// -- Decoding

function Utf32AutoDecoder(options, codec) {
    this.decoder = null;
    this.initialBytes = [];
    this.initialBytesLen = 0;
    this.options = options || {};
    this.iconv = codec.iconv;
}

Utf32AutoDecoder.prototype.write = function(buf) {
    if (!this.decoder) {
        // Codec is not chosen yet. Accumulate initial bytes.
        this.initialBytes.push(buf);
        this.initialBytesLen += buf.length;

        if (this.initialBytesLen < 32) // We need more bytes to use space heuristic (see below)
            return '';

        // We have enough bytes -> detect endianness.
        var buf2 = Buffer.concat(this.initialBytes),
            encoding = detectEncoding(buf2, this.options.defaultEncoding);
        this.decoder = this.iconv.getDecoder(encoding, this.options);
        this.initialBytes.length = this.initialBytesLen = 0;
    }

    return this.decoder.write(buf);
};

Utf32AutoDecoder.prototype.end = function() {
    if (!this.decoder) {
        var buf = Buffer.concat(this.initialBytes),
            encoding = detectEncoding(buf, this.options.defaultEncoding);
        this.decoder = this.iconv.getDecoder(encoding, this.options);

        var res = this.decoder.write(buf),
            trail = this.decoder.end();

        return trail ? (res + trail) : res;
    }

    return this.decoder.end();
};

function detectEncoding(buf, defaultEncoding) {
    var enc = defaultEncoding || 'utf-32le';

    if (buf.length >= 4) {
        // Check BOM.
        if (buf.readUInt32BE(0) === 0xFEFF) // UTF-32LE BOM
            enc = 'utf-32be';
        else if (buf.readUInt32LE(0) === 0xFEFF) // UTF-32LE BOM
            enc = 'utf-32le';
        else {
            // No BOM found. Try to deduce encoding from initial content.
            // Using the wrong endian-ism for UTF-32 will very often result in codepoints that are beyond
            // the valid Unicode limit of 0x10FFFF. That will be used as the primary determinant.
            //
            // Further, we can suppose the content is mostly plain ASCII chars (U+00**).
            // So, we count ASCII as if it was LE or BE, and decide from that.
            var invalidLE = 0, invalidBE = 0;
            var asciiCharsLE = 0, asciiCharsBE = 0, // Counts of chars in both positions
                _len = Math.min(buf.length - (buf.length % 4), 128); // Len is always even.

            for (var i = 0; i < _len; i += 4) {
                var b0 = buf[i], b1  = buf[i + 1], b2 = buf[i + 2], b3 = buf[i + 3];

                if (b0 !== 0 || b1 > 0x10) ++invalidBE;
                if (b3 !== 0 || b2 > 0x10) ++invalidLE;

                if (b0 === 0 && b1 === 0 && b2 === 0 && b3 !== 0) asciiCharsBE++;
                if (b0 !== 0 && b1 === 0 && b2 === 0 && b3 === 0) asciiCharsLE++;
            }

            if (invalidBE < invalidLE)
                enc = 'utf-32be';
            else if (invalidLE < invalidBE)
                enc = 'utf-32le';
            if (asciiCharsBE > asciiCharsLE)
                enc = 'utf-32be';
            else if (asciiCharsBE < asciiCharsLE)
                enc = 'utf-32le';
        }
    }

    return enc;
}
