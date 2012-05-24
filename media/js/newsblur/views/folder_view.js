NEWSBLUR.Views.Folder = Backbone.View.extend({

    className: 'folder',
    
    tagName: 'li',
    
    options: {
        depth: 0,
        collapsed: false,
        title: '',
        root: false
    },
    
    events: {
        "contextmenu"                    : "show_manage_menu",
        "click .NB-feedlist-manage-icon" : "show_manage_menu",
        "click"                          : "open",
        "mouseenter"                     : "add_hover_inverse",
        "mouseleave"                     : "remove_hover_inverse"
    },
    
    render: function() {
        var depth = this.options.depth;
        this.options.collapsed =  _.contains(NEWSBLUR.Preferences.collapsed_folders, this.options.title);
        var $feeds = this.collection.map(_.bind(function(item) {
            var $model;
            if (item.is_feed()) {
                var feed_view = new NEWSBLUR.Views.Feed({
                    model: item.feed, 
                    type: 'feed', 
                    depth: depth,
                    folder_title: this.options.title
                }).render();
                item.feed.views.push(feed_view);
                return feed_view.el;
            } else {
                var folder_view = new NEWSBLUR.Views.Folder({
                    model: item,
                    collection: item.folders,
                    depth: depth + 1,
                    title: item.get('folder_title')
                }).render();
                item.folder_views.push(folder_view);
                return folder_view.el;
            }
        }, this));
        $feeds.push(this.make('div', { 'class': 'feed NB-empty' }));

        var $folder = this.render_folder();
        $(this.el).html($folder);
        this.$('.folder').append($feeds);

        return this;
    },
    
    render_folder: function($feeds) {
        var $folder = _.template('\
        <% if (!root) { %>\
            <div class="folder_title <% if (depth <= 1) { %>NB-toplevel<% } %>">\
                <div class="NB-folder-icon"></div>\
                <div class="NB-feedlist-collapse-icon" title="<% if (is_collapsed) { %>Expand Folder<% } else {%>Collapse Folder<% } %>"></div>\
                <div class="NB-feedlist-manage-icon"></div>\
                <span class="folder_title_text"><%= folder_title %></span>\
            </div>\
        <% } %>\
        <ul class="folder <% if (root) { %>NB-root<% } %>" <% if (is_collapsed) { %>style="display: none"<% } %>>\
        </ul>\
        ', {
          depth         : this.options.depth,
          folder_title  : this.options.title,
          is_collapsed  : this.options.collapsed,
          root          : this.options.root
        });

        return $folder;
    },
    
    // ==========
    // = Events =
    // ==========
   
    open: function(e) {
        
    },
    
    show_manage_menu: function(e) {
        e.preventDefault();
        e.stopPropagation();
        // console.log(["showing manage menu", this.model.is_social() ? 'socialfeed' : 'feed', $(this.el), this]);
        NEWSBLUR.reader.show_manage_menu('folder', this.$el, {
            toplevel: this.options.depth == 0
        });
        return false;
    },
    
    add_hover_inverse: function() {
        if (NEWSBLUR.app.feed_list.is_sorting()) {
            return;
        }

        if (this.$el.offset().top > $(window).height() - 314) {
            this.$el.addClass('NB-hover-inverse');
        } 
    },
    
    remove_hover_inverse: function() {
        this.$el.removeClass('NB-hover-inverse');
    }
    
});