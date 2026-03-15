from collections import defaultdict


class AIClassifierCostEstimator:
    """Estimate costs for AI classifiers based on actual LLM costs and feed story volumes."""

    # Fallback cost estimates when no actual data is available
    FALLBACK_COST_TEXT = 0.001  # ~$0.001 per text classification
    FALLBACK_COST_IMAGE = 0.005  # ~$0.005 per image classification (VLM)

    # Markup applied to all user-facing costs (50% over actual cost)
    COST_MARKUP = 1.5

    def __init__(self, user):
        self.user = user

    def get_cost_estimate(self, feed_id=None):
        """Get cost estimate for AI classifiers, optionally scoped to a specific feed."""
        from apps.analyzer.models import MClassifierPrompt
        from apps.rss_feeds.models import Feed

        prompts = list(MClassifierPrompt.objects.filter(user_id=self.user.pk))
        if not prompts:
            return {
                "estimated_monthly_requests": 0,
                "estimated_monthly_cost": 0.0,
                "feeds_with_classifiers": 0,
                "avg_cost_per_text": self._get_avg_cost("story_classification"),
                "avg_cost_per_image": self._get_avg_cost("vision_classification"),
                "feed_estimates": [],
            }

        # Group classifiers by feed and type
        feed_classifiers = defaultdict(lambda: {"text": 0, "image": 0})
        global_classifiers = {"text": 0, "image": 0}
        for p in prompts:
            key = "image" if p.include_images else "text"
            if p.feed_id == 0:
                global_classifiers[key] += 1
            else:
                feed_classifiers[p.feed_id][key] += 1

        # Get story volumes for feeds with classifiers
        feed_ids = list(feed_classifiers.keys())
        feed_volumes = {}
        feed_titles = {}
        if feed_ids:
            feeds = Feed.objects.filter(pk__in=feed_ids).values_list("pk", "stories_last_month", "feed_title")
            for pk, slm, title in feeds:
                feed_volumes[pk] = slm
                feed_titles[pk] = title

        avg_cost_text = self._get_avg_cost("story_classification")
        avg_cost_image = self._get_avg_cost("vision_classification")

        # Build per-feed estimates
        feed_estimates = []
        total_requests = 0
        total_cost = 0.0

        for fid, counts in feed_classifiers.items():
            stories = feed_volumes.get(fid, 0)
            text_requests = stories * counts["text"]
            image_requests = stories * counts["image"]
            feed_requests = text_requests + image_requests
            feed_cost = text_requests * avg_cost_text + image_requests * avg_cost_image

            total_requests += feed_requests
            total_cost += feed_cost

            feed_estimates.append(
                {
                    "feed_id": fid,
                    "feed_title": feed_titles.get(fid, ""),
                    "stories_per_month": stories,
                    "text_filters": counts["text"],
                    "image_filters": counts["image"],
                    "estimated_requests": feed_requests,
                    "estimated_cost": round(feed_cost, 4),
                }
            )

        # Global classifiers apply to all feeds the user subscribes to
        if global_classifiers["text"] or global_classifiers["image"]:
            total_global_stories = sum(feed_volumes.values())
            global_text = total_global_stories * global_classifiers["text"]
            global_image = total_global_stories * global_classifiers["image"]
            total_requests += global_text + global_image
            total_cost += global_text * avg_cost_text + global_image * avg_cost_image

        # Sort by cost descending so most expensive feeds are first
        feed_estimates.sort(key=lambda x: x["estimated_cost"], reverse=True)

        # If scoped to a specific feed, find that feed's estimate
        scoped_estimate = None
        if feed_id:
            for fe in feed_estimates:
                if fe["feed_id"] == feed_id:
                    scoped_estimate = fe
                    break
            if not scoped_estimate:
                # No classifiers on this feed yet, but we can still show its volume
                try:
                    feed = Feed.objects.get(pk=feed_id)
                    scoped_estimate = {
                        "feed_id": feed_id,
                        "feed_title": feed.feed_title,
                        "stories_per_month": feed.stories_last_month,
                        "text_filters": 0,
                        "image_filters": 0,
                        "estimated_requests": 0,
                        "estimated_cost": 0.0,
                    }
                except Feed.DoesNotExist:
                    pass

        result = {
            "estimated_monthly_requests": total_requests,
            "estimated_monthly_cost": round(total_cost, 2),
            "feeds_with_classifiers": len(feed_ids),
            "avg_cost_per_text": avg_cost_text,
            "avg_cost_per_image": avg_cost_image,
            "feed_estimates": feed_estimates[:10],  # Top 10 by cost
        }
        if scoped_estimate:
            result["this_feed"] = scoped_estimate

        return result

    def _get_avg_cost(self, feature):
        """Get actual average cost per request from LLM cost records, or use fallback."""
        try:
            from apps.monitor.models import MLLMCost

            pipeline = [
                {"$match": {"feature": feature, "user_id": self.user.pk}},
                {"$sort": {"timestamp": -1}},
                {"$limit": 50},
                {"$group": {"_id": None, "avg": {"$avg": "$cost_usd"}, "count": {"$sum": 1}}},
            ]
            result = list(MLLMCost._get_collection().aggregate(pipeline))
            if result and result[0]["count"] >= 1:
                return round(result[0]["avg"] * self.COST_MARKUP, 6)
        except Exception:
            pass

        if feature == "vision_classification":
            return self.FALLBACK_COST_IMAGE * self.COST_MARKUP
        return self.FALLBACK_COST_TEXT * self.COST_MARKUP
