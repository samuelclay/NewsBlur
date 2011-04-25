from django import template

register = template.Library()

@register.inclusion_tag('statistics/render_statistics_graphs.xhtml')
def render_statistics_graphs(statistics):
    return {
        'statistics': statistics,
    }
    
@register.filter
def format_graph(n, max_value, height=30):
    if n == 0 or max_value == 0:
        return 1
    return max(1, height * (n/float(max_value)))