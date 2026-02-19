"""Feed fetching, parsing, story storage, and feed health management.

The data backbone of NewsBlur. Stores Feed metadata in PostgreSQL and story
content in MongoDB. Handles RSS/Atom parsing, duplicate detection, content
diffing, image extraction, and feed exception tracking.
"""
