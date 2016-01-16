// Naive English transformations on words.
window.Inflector = {

    small : "(a|an|and|as|at|but|by|en|for|if|in|of|on|or|the|to|v[.]?|via|vs[.]?)",
    punct : "([!\"#$%&'()*+,./:;<=>?@[\\\\\\]^_`{|}~-]*)",

    // Titleize function by John Resig after John Gruber. MIT Licensed.
    titleize : function(s) {
        s = s.replace(/[-.\/_]/g, ' ').replace(/\s+/gm, ' ');
        var cap = this.capitalize;
        var parts = [], split = /[:.;?!] |(?: |^)["Ò]/g, index = 0;
        while (true) {
            var m = split.exec(s);
            parts.push( s.substring(index, m ? m.index : s.length)
            .replace(/\b([A-Za-z][a-z.'Õ]*)\b/g, function(all){
                return (/[A-Za-z]\.[A-Za-z]/).test(all) ? all : cap(all);
            })
            .replace(RegExp("\\b" + this.small + "\\b", "ig"), this.lowercase)
            .replace(RegExp("^" + this.punct + this.small + "\\b", "ig"), function(all, punct, word) {
                return punct + cap(word);
            })
            .replace(RegExp("\\b" + this.small + this.punct + "$", "ig"), cap));
            index = split.lastIndex;
            if ( m ) parts.push( m[0] );
            else break;
        }
        return parts.join("").replace(/ V(s?)\. /ig, " v$1. ")
        .replace(/(['Õ])S\b/ig, "$1s")
        .replace(/\b(AT&T|Q&A)\b/ig, function(all){
            return all.toUpperCase();
        });
    },

    // Delegate to the ECMA5 String.prototype.trim function, if available.
    trim : function(s) {
        return s.trim ? s.trim() : s.replace(/^\s+|\s+$/g, '');
    },

    // Trim leading and trailing non-whitespace characters, and add ellipses.
    // Try to find natural breaks in the sentence, and avoid breaking HTML fragments.
    trimExcerpt : function(s) {
        s = s.replace(/^([^<>]{0,100}?[.,!]|[^<>\s]+)/g, '');
        s = s.replace(/(([.,!]\s?)[^<>]{0,100}?|[^<>\s]+)$/g, '$2');
        return '&hellip;' + s + '&hellip;';
    },

    camelize : function(s) {
        var parts = s.split('-'), len = parts.length;
        if (len == 1) return parts[0];

        var camelized = s.charAt(0) == '-'
        ? parts[0].charAt(0).toUpperCase() + parts[0].substring(1)
        : parts[0];

        for (var i = 1; i < len; i++)
        camelized += parts[i].charAt(0).toUpperCase() + parts[i].substring(1);

        return camelized;
    },

    lowercase : function(s) {
        return s.toLowerCase();
    },

    capitalize : function(s) {
        return s.charAt(0).toUpperCase() + s.substring(1).toLowerCase();
    },

    underscore : function(s) {
        return s.replace(/::/g, '/').replace(/([A-Z]+)([A-Z][a-z])/g,'$1_$2').replace(/([a-z\d])([A-Z])/g,'$1_$2').replace(/-/g,'_').toLowerCase();
    },

    spacify : function(s) {
        return s.replace(/_/g, ' ');
    },

    dasherize : function(s) {
        return s.replace(/_/g,'-');
    },

    singularize : function(s) {
        return s.replace(/s$/, '');
    },

    // Only works for words that pluralize by adding an 's', end in a 'y', or
    // that we've special-cased. Not comprehensive.
    pluralize : function(s, count, include_count) {
        if (count != 1) {
            if (s == 'person') s = 'people';
            else if (s == 'is') s = 'are';
            else if (s == 'has') s = 'have';
            else if (s == 'following') s = s;
            else if (s == 'day') s = 'days';
            else if (s.match(/y$/i)) s = s.replace(/y$/i, 'ies');
            else s = s + 's';
        }
        if (include_count) s = Inflector.commas(count) + ' ' + s;
        return s;
    },

    classify : function(s) {
        return this.camelize(this.capitalize(this.dasherize(this.singularize(s))));
    },

    possessivize : function(s) {
        var endsInS = s.charAt(s.length - 1) == 's';
        return s + (endsInS ? "'" : "'s");
    },

    truncate : function(s, length, truncation) {
        length = length || 30;
        truncation = _.isUndefined(truncation) ? '...' : truncation;
        return s.length > length ? s.slice(0, length - truncation.length) + truncation : s;
    },

    // Convert a string (usually a title), to something appropriate for use in a URL.
    // Apostrophes and quotes are removed, non-word-chars become spaces, whitespace
    // is trimmed, lowercased, and spaces become dashes.
    sluggify : function(s) {
        return $.trim(s.replace(/['"]+/g, '').replace(/\W+/g, ' ')).toLowerCase().replace(/\s+/g, '-');
    },

    commify : function(list, options) {
        var words = [];
        _.each(list, function(word, i) {
            if (options.quote) word = '"' + word + '"';
            words.push(word);
            var end = i == list.length - 1 ? '' :
            (i == list.length - 2) && options.conjunction ? ', ' + options.conjunction + ' ' :
            ', ';
            words.push(end);
        });
        return words.join('');
    },

    commas : function(number) {
        var numberMatcher = /(\d+)(\d{3})/;
        number += '';
        var fragments = number.split('.');
        whole = fragments[0];
        decimal = fragments.length > 1 ? '.' + fragments[1] : '';
        while (numberMatcher.test(whole)) {
            whole = whole.replace(numberMatcher, '$1,$2');
        }
        return whole + decimal;
    },

    // Convert bytes into KB or MB
    bytesToMB : function(bytes) {
        var byteSize = Math.round(bytes / 1024 * 100) * 0.01;
        var suffix = 'KB';
        if (byteSize > 1000) {
            byteSize = Math.round(byteSize * 0.001 * 100) * 0.01;
            suffix = 'MB';
        }
        var sizeParts = byteSize.toString().split('.');
        byteSize = sizeParts[0] + (sizeParts.length > 1 ? '.' + sizeParts[1].substr(0,1) : '');
        return byteSize + ' ' + suffix;
    },

    // Normalize an entered-by-hand url, trimming and adding the protocol, if missing.
    normalizeUrl : function(s) {
        s = Inflector.trim(s);
        if (!s) return null;
        return (/^https?:\/\//).test(s) ? s : 'http://' + s;
    },

    // From Prototype.js. Strip out HTML tags.
    stripTags : function(s) {
        return _.string.escapeHTML($('<p>' + s + '</p>').text());
    },

    escapeRegExp : function(s) {
        return s.replace(/([.*+?^${}()|[\]\/\\])/g, '\\$1');
    }

};