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
        // console.log(["site", site_id, slug]);
        site_id = parseInt(site_id, 10);
        NEWSBLUR.reader.open_feed(site_id, {force: true});
    },
    
    social: function(user_id, slug) {
        console.log(["router:social", user_id, slug]);
        var feed_id = "social:" + user_id;
        NEWSBLUR.reader.open_social_stories(feed_id, {force: true});
    },
    
    user: function(user) {
        console.log(["user", user]);
    }
    
});