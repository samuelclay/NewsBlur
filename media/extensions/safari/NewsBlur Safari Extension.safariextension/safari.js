setInterval(function() {
    var $iframe = $('#story_iframe');
    if ($iframe.length) {
        console.log(['iframe', $iframe.contents().find('div').length]);
    }
}, 3000);