"""Browser extension backend for automatic browsing history archival.

Receives page visits from the NewsBlur browser extension, deduplicates URLs,
stores zlib-compressed content in MongoDB, and matches visits to NewsBlur stories.
"""
