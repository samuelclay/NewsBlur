NEWSBLUR.InteractionsPopover = NEWSBLUR.ReaderPopover.extend({
    
    className: "NB-interactions-popover",
    
    options: {
        'width': 386,
        'anchor': '.NB-feeds-header-user-interactions',
        'placement': '-bottom',
        'popover_class': 'NB-interactions-popover-container',
        'overlay_top': true,
        offset: {
            top: 36,
            left: -1
        },
        'tab': 'interactions'
    },
    
    page: 0,
    
    events: {
        "click .NB-tab" : "switch_tab"
    },
    
    end_of_list: {},
    
    initialize: function(options) {
        this.options = _.extend({}, this.options, options);
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this);
        
        this.model = NEWSBLUR.assets;
        this.render();
        this.show_loading();

        $(".NB-feeds-header-user-notifications").addClass('NB-active');
        
        this.fetch_next_page();
        
    },
    
    close: function() {
        $(".NB-feeds-header-user-notifications").removeClass('NB-active');
        NEWSBLUR.app.sidebar_header.update_interactions_count(0);
        this.model.preference('dashboard_date', new Date);
        NEWSBLUR.ReaderPopover.prototype.close.call(this);
    },

    render: function() {
        var self = this;
        
        if (!this._on_page) {
            NEWSBLUR.ReaderPopover.prototype.render.call(this);
            this._on_page = true;
        }
        
        var $tab = $.make('div', [
            $.make('div', { className: 'NB-interactions-header' }, [
                $.make("div", { className: "NB-tab NB-tab-interactions" }, [
                    $.make('span', "Interactions")
                ]),
                $.make("div", { className: "NB-tab NB-tab-activities" }, [
                    $.make('span', "Activities")
                ])
            ]),
            $.make('div', { className: 'NB-interactions-container ' + (this.options.tab == 'interactions' && 'NB-active') }),
            $.make('div', { className: 'NB-activities-container ' + (this.options.tab == 'activities' && 'NB-active') })
        ]);
        
        this.$el.html($tab);
        this.$el.removeClass("NB-active-interactions");
        this.$el.removeClass("NB-active-activities");
        this.$el.addClass("NB-active-" + this.options.tab);
        
        this.$(".NB-interactions-container,.NB-activities-container").unbind('scroll')
            .bind('scroll', _.bind(this.fill_out, this));
        
        return this;
    },
    
    // ===========
    // = Actions =
    // ===========
    
    show_loading: function() {
        this.hide_loading();
        
        var $endline = $.make('div', { className: "NB-end-line NB-short" });
        $endline.css({'background': '#FFF'});
        this.$(".NB-"+this.options.tab+"-container").append($endline);
        
        $endline.animate({'backgroundColor': '#E1EBFF'}, {'duration': 550, 'easing': 'easeInQuad'})
                .animate({'backgroundColor': '#5C89C9'}, {'duration': 1550, 'easing': 'easeOutQuad'})
                .animate({'backgroundColor': '#E1EBFF'}, 1050);
        _.delay(_.bind(function() {
            this.interactions_loading = setInterval(function() {
                $endline.animate({'backgroundColor': '#5C89C9'}, {'duration': 650})
                        .animate({'backgroundColor': '#E1EBFF'}, 1050);
            }, 1700);
        }, this), (550+1550+1050) - 1700);
     
    },
    
    hide_loading: function() {
        clearInterval(this.interactions_loading);
        this.$(".NB-end-line").remove();
    },
    
    fetch_next_page: function() {
        if (this.fetching) return;
        this.page += 1;
        this.show_loading();
        this.fetching = true;
        
        // load_interactions_page or load_activities_page
        this.model['load_'+this.options.tab+'_page'](this.page, _.bind(function(resp, type) {
            console.log(["type", type, this.options.tab]);
            if (type != this.options.tab) return;
            this.fetching = false;
            this.hide_loading();
            var $interactions = $(resp);
            if (!resp || !$(".NB-interaction", $interactions).length) {
                this.no_more();
            } else {
                this.$(".NB-"+this.options.tab+"-container").append($interactions);
                this.fill_out();
            }
        }, this));
    },
    
    no_more: function() {
        this.end_of_list[this.options.tab] = true;
        var $end = $.make('div', { className: "NB-end-line" }, [
            $.make('div', { className: 'NB-fleuron' })
        ]);
        this.$(".NB-"+this.options.tab+"-container").append($end);
    },
    
    fill_out: function() {
        if (this.end_of_list[this.options.tab]) return;
        
        var $container = this.$(".NB-"+this.options.tab+"-container");
        var containerHeight = $container.height();
        var scrollTop = $container.scrollTop();
        var $bottom = $(".NB-interaction,.NB-activity", $container).last();
        var bottomOffset = $bottom.offset().top - $container.offset().top + $bottom.height();

        if (bottomOffset < containerHeight) {
            this.fetch_next_page();
        }
        
    },
    
    reset: function(type) {
        this.end_of_list = {};
        this.options.tab = type;
        this.page = 0;
        this.fetching = false;
    },
    
    // ==========
    // = Events =
    // ==========
    
    switch_tab: function(e) {
        var $tab = $(e.currentTarget);
        e.preventDefault();
        e.stopPropagation();
        
        if ($tab.hasClass("NB-tab-interactions")) {
            this.reset('interactions');
            this.render();
            this.fetch_next_page();
        } else if ($tab.hasClass("NB-tab-activities")) {
            this.reset('activities');
            this.render();
            this.fetch_next_page();
        }
    }
    
});