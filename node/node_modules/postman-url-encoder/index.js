var  /**
     * @private
     * @const
     * @type {String}
     */
    PERCENT = '%',

    /**
     * @private
     * @const
     * @type {string}
     */
    ZERO = '0';

module.exports = {

    percentEncode: function(c) {
        var hex = c.toString(16).toUpperCase();
        (hex.length === 1) && (hex = ZERO + hex);
        return PERCENT + hex;
    },

    isPreEncoded: function(buffer, i) {
    // If it is % check next two bytes for percent encode characters
    // looking for pattern %00 - %FF
        return (buffer[i] === 0x25 &&
            (this.isPreEncodedCharacter(buffer[i + 1]) &&
             this.isPreEncodedCharacter(buffer[i + 2]))
          );
    },

    isPreEncodedCharacter: function(byte) {
        return (byte >= 0x30 && byte <= 0x39) ||  // 0-9
           (byte >= 0x41 && byte <= 0x46) ||  // A-F
           (byte >= 0x61 && byte <= 0x66);     // a-f
    },

    charactersToPercentEncode: function(byte) {
        return (byte < 0x23 || byte > 0x7E || // Below # and after ~
            byte === 0x3C || byte === 0x3E || // > and <
            byte === 0x28 || byte === 0x29 || // ( and )
            byte === 0x25 || // %
            byte === 0x27 || // '
            byte === 0x2A    // *
      );
    },

  /**
   * Percent encode a query string according to RFC 3986
   *
   * @param value
   * @returns {string}
   */
    encode: function (value) {
        if (!value) { return ''; }

        var buffer = new Buffer(value),
            ret = '',
            i;

        for (i = 0; i < buffer.length; ++i) {

            if (this.charactersToPercentEncode(buffer[i]) && !this.isPreEncoded(buffer, i)) {
                ret += this.percentEncode(buffer[i]);
            }
            else {
                ret += String.fromCodePoint(buffer[i]);  // Only works in ES6 (available in Node v4+)
            }
        }

        return ret;
    }
};
