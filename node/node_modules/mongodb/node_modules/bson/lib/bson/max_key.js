/**
 * A class representation of the BSON MaxKey type.
 *
 * @class Represents the BSON MaxKey type.
 * @return {MaxKey}
 */
function MaxKey() {
  if(!(this instanceof MaxKey)) return new MaxKey();
  
  this._bsontype = 'MaxKey';  
}

if(typeof window === 'undefined') {
  exports.MaxKey = MaxKey;
}