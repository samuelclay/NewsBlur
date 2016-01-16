NEWSBLUR.Router = Backbone.Router.extend({
    
    routes: {
        "add/?": "add_site",
        "try/?": "try_site",
        "site/:site_id/:slug": "site",
        "site/:site_id/": "site",
        "site/:site_id": "site",
        "read": "read",
        "saved": "starred",
        "saved/:tag": "starred",
        "folder/saved": "starred",
        "folder/saved/:tag": "starred",
        "folder/:folder_name": "folder",
        "folder/:folder_name/": "folder",
        "social/:user_id/:slug": "social",
        "social/:user_id/": "social",
        "social/:user_id": "social",
        "user/*user": "user"
    },
    
    add_site: function() {
        NEWSBLUR.log(["add", window.location, $.getQueryString('url')]);
        NEWSBLUR.reader.open_add_feed_modal({url: $.getQueryString('url')});
    },
    
    try_site: function() {
        NEWSBLUR.log(["try", window.location]);
    },
    
    site: function(site_id, slug) {
        // NEWSBLUR.log(["site", site_id, slug]);
        site_id = parseInt(site_id, 10);
        var feed = NEWSBLUR.assets.get_feed(site_id);
        var query = $.getQueryString('search');
        if (query) {
            NEWSBLUR.reader.flags.searching = true;
            NEWSBLUR.reader.flags.search = query;
        }
        if (feed) {
            NEWSBLUR.reader.open_feed(site_id, {router: true, force: true, search: query});
        } else {
            NEWSBLUR.reader.load_feed_in_tryfeed_view(site_id, {
                router: true,
                force: true, 
                search: query,
                feed: {
                    feed_title: _.string.humanize(slug || "")
                }
            });
        }
    },
    
    read: function() {
        var options = {
            router: true
        };
        var query = $.getQueryString('search');
        if (query) {
            NEWSBLUR.reader.flags.searching = true;
            NEWSBLUR.reader.flags.search = query;
            options['search'] = query;
        }
        console.log(["read stories", options]);
        NEWSBLUR.reader.open_read_stories(options);
    },
    
    starred: function(tag) {
        var options = {
            router: true,
            tag: tag
        };
        var query = $.getQueryString('search');
        if (query) {
            NEWSBLUR.reader.flags.searching = true;
            NEWSBLUR.reader.flags.search = query;
            options['search'] = query;
        }
        console.log(["starred", options, tag]);
        NEWSBLUR.reader.open_starred_stories(options);
    },
    
    folder: function(folder_name) {
        folder_name = folder_name.replace(/-/g, ' ');
        // NEWSBLUR.log(["folder", folder_name]);
        var options = {router: true};
        var query = $.getQueryString('search');
        if (query) {
            NEWSBLUR.reader.flags.searching = true;
            NEWSBLUR.reader.flags.search = query;
            options['search'] = query;
        }

        if (folder_name == "everything") {
            NEWSBLUR.reader.open_river_stories(null, null, options);
        } else if (folder_name == "blurblogs") {
            NEWSBLUR.reader.open_river_blurblogs_stories(options);
        } else if (folder_name == "global blurblogs") {
            options['global'] = true;
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
        var query = $.getQueryString('search');
        if (query) {
            NEWSBLUR.reader.flags.searching = true;
            NEWSBLUR.reader.flags.search = query;
        }
        var feed_id = "social:" + user_id;
        if (NEWSBLUR.assets.get_feed(feed_id)) {
            NEWSBLUR.reader.open_social_stories(feed_id, {router: true, force: true, search: query});
        } else {
            NEWSBLUR.reader.load_social_feed_in_tryfeed_view(feed_id, {
                router: true, 
                force: true, 
                search: query,
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