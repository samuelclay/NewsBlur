from django import template

register = template.Library()

@register.filter
def format_graph(n, max_value, height=30):
    if n == 0:
        return 1
    return max(1, height / (n/(max_value or 1)))