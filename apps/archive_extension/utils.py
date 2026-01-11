def format_datetime_utc(dt):
    """Format a datetime as ISO 8601 with UTC 'Z' suffix, or None if dt is None."""
    return (dt.isoformat() + "Z") if dt else None
