var redis = require('redis');

rc = redis.createClient();

rc.on('error', function (err) {
        console.log('Redis error ' + err);
});

var jsonStr = '{\"glossary\":{\"title\":\"example glossary\",\"GlossDiv\":{\"title\":\"S\",\"GlossList\":{\"GlossEntry\":{\"ID\":\"SGML\",\"SortAs\":\"SGML\",\"GlossTerm\":\"Standard Generalized Markup Language\",\"Acronym\":\"SGML\",\"Abbrev\":\"ISO 8879:1986\",\"GlossDef\":{\"para\":\"A meta-markup language, used to create markup languages such as DocBook.\",\"GlossSeeAlso\":[\"GML\",\"XML\"]},\"GlossSee\":\"markup\"}}}}}';

for (var i = 0, len = 100; i < len; i++) {
        rc.rpush('test:case', jsonStr);
}

rc.lrange('test:case', 0, -1, function (err, data) {
        console.log(data); // it will return 100 elements, but the last ones will be null's instead of the actual value
        rc.end();
});
