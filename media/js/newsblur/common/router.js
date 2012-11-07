NEWSBLUR.Router = Backbone.Router.extend({
    
    routes: {
        "": "index",
        "add/?": "add_site",
        "try/?": "try_site",
        "site/:site_id/:slug": "site",
        "site/:site_id/": "site",
        "site/:site_id": "site",
        "folder/:folder_name": "folder",
        "folder/:folder_name/": "folder",
        "social/:user_id/:slug": "social",
        "social/:user_id/": "social",
        "social/:user_id": "social",
        "user/*user": "user"
    },
    
    index: function() {
        // NEWSBLUR.log(["index"]);
        NEWSBLUR.reader.show_splash_page();
    },
    
    add_site: function() {
        NEWSBLUR.log(["add", window.location, $.getQueryString('url')]);
        NEWSBLUR.reader.open_add_feed_modal({url: $.getQueryString('url')});
    },
    
    try_site: function() {
        NEWSBLUR.log(["try", window.location]);
    },
    
    site: function(site_id, slug) {
        NEWSBLUR.log(["site", site_id, slug]);
        site_id = parseInt(site_id, 10);
        var feed = NEWSBLUR.assets.get_feed(site_id);
        if (feed) {
            NEWSBLUR.reader.open_feed(site_id, {router: true, force: true});
        } else {
            NEWSBLUR.reader.load_feed_in_tryfeed_view(site_id, {
                router: true,
                force: true, 
                feed: {
                    feed_title: _.string.humanize(slug || "")
                }
            });
        }
    },
    
    folder: function(folder_name) {
        folder_name = folder_name.replace(/-/g, ' ');
        NEWSBLUR.log(["folder", folder_name]);
        var options = {router: true};
        if (folder_name == "everything") {
            NEWSBLUR.reader.open_river_stories(null, null, options);
        } else if (folder_name == "blurblogs") {
            NEWSBLUR.reader.open_river_blurblogs_stories(options);
        } else {
            var folder = NEWSBLUR.assets.get_folder(folder_name);
            if (folder) {
                NEWSBLUR.reader.open_river_stories(folder.folder_view.$el, folder, options);
            }
        }
    },
    
    social: function(user_id, slug) {
        NEWSBLUR.log(["router:social", user_id, slug]);
        var feed_id = "social:" + user_id;
        if (NEWSBLUR.assets.get_feed(feed_id)) {
            NEWSBLUR.reader.open_social_stories(feed_id, {router: true, force: true});
        } else {
            NEWSBLUR.reader.load_social_feed_in_tryfeed_view(feed_id, {
                router: true, 
                force: true, 
                feed: {
                    username: _.string.humanize(slug),
                    id: feed_id,
                    user_id: parseInt(user_id, 10),
                    feed_title: _.string.humanize(slug)
                }
            });
        }
    },
    
    user: function(user) {
        NEWSBLUR.log(["user", user]);
    }
    
});