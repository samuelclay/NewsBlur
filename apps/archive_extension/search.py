"""
Elasticsearch integration for Archive Extension.

Provides full-text search across archived pages using the same patterns
as NewsBlur's existing search functionality.
"""

import html
import re

import elasticsearch
import urllib3
from django.conf import settings

from utils import log as logging


class SearchArchive:
    """Elasticsearch search for archived pages."""

    _es_client = None
    name = "archives"

    @classmethod
    def ES(cls):
        """Get or create Elasticsearch client."""
        if cls._es_client is None:
            # Use the story search host for archives (same cluster)
            cls._es_client = elasticsearch.Elasticsearch(settings.ELASTICSEARCH_STORY_HOST)
            cls.create_elasticsearch_mapping()
        return cls._es_client

    @classmethod
    def index_name(cls):
        """Get the index name."""
        return "%s-index" % cls.name

    @classmethod
    def doc_type(cls):
        """Get the document type (deprecated in newer ES versions)."""
        if settings.DOCKERBUILD or getattr(settings, "ES_IGNORE_TYPE", True):
            return None
        return "%s-type" % cls.name

    @classmethod
    def create_elasticsearch_mapping(cls, delete=False):
        """Create the Elasticsearch index mapping for archives."""
        if delete:
            logging.debug(" ---> ~FRDeleting search index for ~FM%s" % cls.index_name())
            try:
                cls.ES().indices.delete(cls.index_name())
            except elasticsearch.exceptions.NotFoundError:
                logging.debug(f" ---> ~FBCan't delete {cls.index_name()} index, doesn't exist...")

        try:
            if cls.ES().indices.exists(cls.index_name()):
                return
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for index mapping check: {e}")
            return

        mapping = {
            "title": {
                "store": False,
                "type": "text",
                "analyzer": "snowball",
                "term_vector": "yes",
            },
            "content": {
                "store": False,
                "type": "text",
                "analyzer": "snowball",
                "term_vector": "yes",
            },
            "url": {
                "store": False,
                "type": "keyword",
            },
            "domain": {
                "store": False,
                "type": "keyword",
            },
            "categories": {
                "store": False,
                "type": "keyword",
            },
            "user_id": {
                "store": False,
                "type": "integer",
            },
            "archived_date": {
                "store": False,
                "type": "date",
            },
        }

        try:
            cls.ES().indices.create(
                cls.index_name(),
                body={
                    "mappings": {
                        "_source": {"enabled": False},
                        "properties": mapping,
                    }
                },
            )
            logging.debug(" ---> ~FCCreating search index for ~FM%s" % cls.index_name())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRCould not create search index for ~FM%s: %s" % (cls.index_name(), e))
            return
        except (
            elasticsearch.exceptions.ConnectionError,
            urllib3.exceptions.NewConnectionError,
            urllib3.exceptions.ConnectTimeoutError,
        ) as e:
            logging.debug(f" ***> ~FRNo search server available for creating archive mapping: {e}")
            return

        cls.ES().indices.flush(cls.index_name())

    @classmethod
    def index(
        cls,
        archive_id,
        user_id,
        title,
        content,
        url,
        domain,
        categories,
        archived_date,
    ):
        """
        Index an archived page for search.

        Args:
            archive_id: Unique identifier for the archive (str(ObjectId))
            user_id: User ID who owns this archive
            title: Page title
            content: Extracted page content (text)
            url: Original URL
            domain: Domain of the URL
            categories: List of AI-generated categories
            archived_date: When the page was archived
        """
        cls.create_elasticsearch_mapping()

        doc = {
            "title": title or "",
            "content": content or "",
            "url": url,
            "domain": domain or "",
            "categories": categories or [],
            "user_id": user_id,
            "archived_date": archived_date,
        }

        try:
            cls.ES().create(
                index=cls.index_name(),
                id=archive_id,
                body=doc,
                doc_type=cls.doc_type(),
                ignore=409,  # Ignore conflict if already exists
            )
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for archive indexing: {e}")

    @classmethod
    def update(cls, archive_id, **fields):
        """
        Update an indexed archive document.

        Args:
            archive_id: Archive document ID
            **fields: Fields to update (title, content, categories, etc.)
        """
        try:
            cls.ES().update(
                index=cls.index_name(),
                id=archive_id,
                body={"doc": fields},
                doc_type=cls.doc_type(),
            )
        except elasticsearch.exceptions.NotFoundError:
            logging.debug(f" ***> ~FRArchive {archive_id} not found in index for update")
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for archive update: {e}")

    @classmethod
    def remove(cls, archive_id):
        """Remove an archive from the search index."""
        try:
            if not cls.ES().exists(index=cls.index_name(), id=archive_id, doc_type=cls.doc_type()):
                return

            cls.ES().delete(index=cls.index_name(), id=archive_id, doc_type=cls.doc_type())
        except elasticsearch.exceptions.NotFoundError:
            pass
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for archive deletion: {e}")

    @classmethod
    def drop(cls):
        """Drop the entire archives index."""
        try:
            cls.ES().indices.delete(cls.index_name())
        except elasticsearch.exceptions.NotFoundError:
            logging.debug(" ***> ~FBNo archives index found, nothing to drop.")

    @classmethod
    def _sanitize_query(cls, query):
        """
        Escape unbalanced quotes to prevent Elasticsearch query_string errors.

        Elasticsearch's query_string query requires balanced quotes for phrase searches.
        If a user enters an odd number of quotes (e.g., 'hello "world'), this will
        escape the last quote to prevent a parsing error.
        """
        quote_count = query.count('"')
        if quote_count % 2 != 0:
            last_quote_idx = query.rfind('"')
            query = query[:last_quote_idx] + '\\"' + query[last_quote_idx + 1 :]
        return query

    @classmethod
    def query(
        cls,
        user_id,
        query,
        order="newest",
        offset=0,
        limit=20,
        domain=None,
        categories=None,
        date_from=None,
        date_to=None,
        strip=False,
    ):
        """
        Search archives for a user.

        Args:
            user_id: User ID to search archives for
            query: Search query string
            order: Sort order ("newest" or "oldest")
            offset: Pagination offset
            limit: Maximum results to return
            domain: Optional domain filter
            categories: Optional list of categories to filter by
            date_from: Optional start date filter
            date_to: Optional end date filter
            strip: Whether to strip special characters from query

        Returns:
            List of archive IDs matching the query
        """
        try:
            cls.ES().indices.flush(cls.index_name())
        except elasticsearch.exceptions.NotFoundError as e:
            logging.debug(f" ***> ~FRNo search server available: {e}")
            return []

        if strip:
            query = re.sub(
                r'([^\s\w_\-"])+', " ", query
            )  # Strip non-alphanumeric, preserve quotes for phrases
        query = html.unescape(query)
        query = cls._sanitize_query(query)

        # Build the query
        must_clauses = [
            {"query_string": {"query": query, "default_operator": "AND", "fields": ["title^2", "content"]}},
            {"term": {"user_id": user_id}},
        ]

        # Add optional filters
        if domain:
            must_clauses.append({"term": {"domain": domain}})

        if categories:
            must_clauses.append({"terms": {"categories": categories}})

        # Date range filter
        if date_from or date_to:
            date_range = {}
            if date_from:
                date_range["gte"] = date_from.isoformat() if hasattr(date_from, "isoformat") else date_from
            if date_to:
                date_range["lte"] = date_to.isoformat() if hasattr(date_to, "isoformat") else date_to
            must_clauses.append({"range": {"archived_date": date_range}})

        body = {
            "query": {"bool": {"must": must_clauses}},
            "sort": [{"archived_date": {"order": "desc" if order == "newest" else "asc"}}],
            "from": offset,
            "size": limit,
        }

        try:
            results = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRSearch query error: %s" % e)
            return []
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for archive query: {e}")
            return []

        logging.info(
            " ---> ~FG~SNSearch ~FCarchives~FG for user ~SB%s~SN: ~SB%s~SN, ~SB%s~SN results"
            % (user_id, query, len(results["hits"]["hits"]))
        )

        try:
            result_ids = [r["_id"] for r in results["hits"]["hits"]]
        except Exception as e:
            logging.info(' ---> ~FRInvalid archive search query "%s": %s' % (query, e))
            return []

        return result_ids

    @classmethod
    def get_user_archive_count(cls, user_id):
        """Get the total count of indexed archives for a user."""
        try:
            body = {"query": {"term": {"user_id": user_id}}}
            result = cls.ES().count(index=cls.index_name(), body=body)
            return result.get("count", 0)
        except Exception:
            return 0

    @classmethod
    def reindex_user_archives(cls, user_id):
        """
        Reindex all archives for a user.

        This is useful when the mapping changes or archives need to be re-indexed.
        """
        from apps.archive_extension.models import MArchivedStory

        archives = MArchivedStory.objects.filter(user_id=user_id, deleted=False)
        count = 0

        for archive in archives:
            cls.index(
                archive_id=str(archive.id),
                user_id=archive.user_id,
                title=archive.title,
                content=archive.get_content(),
                url=archive.url,
                domain=archive.domain,
                categories=archive.ai_categories or [],
                archived_date=archive.archived_date,
            )
            count += 1

        logging.info(f" ---> ~FCReindexed ~SB{count}~SN archives for user ~SB{user_id}")
        return count

    @classmethod
    def index_archive(cls, archive):
        """
        Index a single archive document.

        Args:
            archive: MArchivedStory instance
        """
        cls.index(
            archive_id=str(archive.id),
            user_id=archive.user_id,
            title=archive.title,
            content=archive.get_content(),
            url=archive.url,
            domain=archive.domain,
            categories=archive.ai_categories or [],
            archived_date=archive.archived_date,
        )

    @classmethod
    def debug_index(cls, show_data=True, show_source=False):
        """Debug method to inspect index fields and entries."""
        try:
            if not cls.ES().indices.exists(cls.index_name()):
                logging.info(f"~FR Index {cls.index_name()} does not exist")
                return

            mapping = cls.ES().indices.get_mapping(index=cls.index_name())
            logging.info(f"~FB Index mapping for {cls.index_name()}:")
            logging.info(
                f"Properties: {list(mapping[cls.index_name()]['mappings'].get('properties', {}).keys())}"
            )

            stats = cls.ES().indices.stats(index=cls.index_name())
            total_docs = stats["indices"][cls.index_name()]["total"]["docs"]["count"]
            logging.info(f"~FG Total documents in index: {total_docs}")

            if show_data:
                body = {
                    "query": {"match_all": {}},
                    "size": 3,
                    "sort": [{"archived_date": {"order": "desc"}}],
                }
                results = cls.ES().search(body=body, index=cls.index_name())

                logging.info("~FB Sample documents:")
                for hit in results["hits"]["hits"]:
                    logging.info(f"Document ID: {hit['_id']}")
                    if show_source:
                        logging.info(f"Content: {hit.get('_source', {})}")
                    logging.info("---")

        except elasticsearch.exceptions.NotFoundError as e:
            logging.info(f"~FR Error accessing index: {e}")
        except Exception as e:
            logging.info(f"~FR Unexpected error: {e}")
