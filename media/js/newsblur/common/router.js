NEWSBLUR.Router = Backbone.Router.extend({
    
    routes: {
        "": "index",
        "add/?": "add_site",
        "try/?": "try_site",
        "site/:site_id": "site",
        "site/:site_id/:slug": "site",
        "social/:user_id": "social",
        "social/:user_id/:slug": "social",
        "user/*user": "user"
    },
    
    index: function() {
        NEWSBLUR.reader.show_splash_page();
    },
    
    add_site: function() {
        console.log(["add", window.location, $.getQueryString('url')]);
        NEWSBLUR.reader.open_add_feed_modal({url: $.getQueryString('url')});
    },
    
    try_site: function() {
        console.log(["try", window.location]);
    },
    
    site: function(site_id, slug) {
        console.log(["site", site_id, slug]);
        site_id = parseInt(site_id, 10);
        var feed = NEWSBLUR.reader.model.get_feed(site_id);
        if (feed) {
            NEWSBLUR.reader.open_feed(site_id, {force: true});
        } else {
            NEWSBLUR.reader.load_feed_in_tryfeed_view(site_id, {force: true, feed: {
                feed_title: _.string.humanize(slug)
            }});
        }
    },
    
    social: function(user_id, slug) {
        console.log(["router:social", user_id, slug]);
        var feed_id = "social:" + user_id;
        if (NEWSBLUR.reader.model.get_feed(feed_id)) {
            NEWSBLUR.reader.open_social_stories(feed_id, {force: true});
        } else {
            NEWSBLUR.reader.load_social_feed_in_tryfeed_view(feed_id, {force: true, feed: {
                username: _.string.humanize(slug),
                id: feed_id,
                user_id: parseInt(user_id, 10),
                feed_title: _.string.humanize(slug)
            }});
        }
    },
    
    user: function(user) {
        console.log(["user", user]);
    }
    
});