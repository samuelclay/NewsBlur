"""Story clustering for duplicate and near-duplicate detection across feeds.

Groups stories with identical or similar titles into clusters using
normalized title matching and fuzzy word-overlap similarity. Clusters
are stored in Redis with a configurable TTL and tracked via Prometheus
metrics for monitoring.
"""
