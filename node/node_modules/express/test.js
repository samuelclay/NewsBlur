
/**
 * Module dependencies.
 */

var express = require('./')
  , app = express()

app.get('/', function(req, res){
  console.log(req.query);
});

app.listen(3000);
console.log('listening on 3000');
