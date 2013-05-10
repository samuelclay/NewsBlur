from django import template
from django.db import models
from haystack.query import SearchQuerySet


register = template.Library()


class MoreLikeThisNode(template.Node):
    def __init__(self, model, varname, for_types=None, limit=None):
        self.model = template.Variable(model)
        self.varname = varname
        self.for_types = for_types
        self.limit = limit
        
        if not self.limit is None:
            self.limit = int(self.limit)
    
    def render(self, context):
        try:
            model_instance = self.model.resolve(context)
            sqs = SearchQuerySet()
            
            if not self.for_types is None:
                intermediate = template.Variable(self.for_types)
                for_types = intermediate.resolve(context).split(',')
                search_models = []
                
                for model in for_types:
                    model_class = models.get_model(*model.split('.'))
                    
                    if model_class:
                        search_models.append(model_class)
                
                sqs = sqs.models(*search_models)
            
            sqs = sqs.more_like_this(model_instance)
            
            if not self.limit is None:
                sqs = sqs[:self.limit]
            
            context[self.varname] = sqs
        except:
            pass
        
        return ''


@register.tag
def more_like_this(parser, token):
    """
    Fetches similar items from the search index to find content that is similar
    to the provided model's content.
    
    Syntax::
    
        {% more_like_this model_instance as varname [for app_label.model_name,app_label.model_name,...] [limit n] %}
    
    Example::
    
        # Pull a full SearchQuerySet (lazy loaded) of similar content.
        {% more_like_this entry as related_content %}
        
        # Pull just the top 5 similar pieces of content.
        {% more_like_this entry as related_content limit 5  %}
        
        # Pull just the top 5 similar entries or comments.
        {% more_like_this entry as related_content for "blog.entry,comments.comment" limit 5  %}
    """
    bits = token.split_contents()
    
    if not len(bits) in (4, 6, 8):
        raise template.TemplateSyntaxError(u"'%s' tag requires either 3, 5 or 7 arguments." % bits[0])
    
    model = bits[1]
    
    if bits[2] != 'as':
        raise template.TemplateSyntaxError(u"'%s' tag's second argument should be 'as'." % bits[0])
    
    varname = bits[3]
    limit = None
    for_types = None
    
    if len(bits) == 6:
        if bits[4] != 'limit' and bits[4] != 'for':
            raise template.TemplateSyntaxError(u"'%s' tag's fourth argument should be either 'limit' or 'for'." % bits[0])
        
        if bits[4] == 'limit':
            limit = bits[5]
        else:
            for_types = bits[5]
    
    if len(bits) == 8:
        if bits[4] != 'for':
            raise template.TemplateSyntaxError(u"'%s' tag's fourth argument should be 'for'." % bits[0])
        
        for_types = bits[5]
        
        if bits[6] != 'limit':
            raise template.TemplateSyntaxError(u"'%s' tag's sixth argument should be 'limit'." % bits[0])
        
        limit = bits[7]
    
    return MoreLikeThisNode(model, varname, for_types, limit)
