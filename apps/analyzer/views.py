"""Intelligence trainer views: save and retrieve per-user classifiers for story scoring.

Handles saving classifier rules (by title, author, tag, feed, and AI prompt)
and populating the trainer modal with current classifier state.
"""

import redis
from django.conf import settings
from django.shortcuts import get_object_or_404, render
from django.views.decorators.http import require_POST
from mongoengine.queryset import NotUniqueError

from apps.analyzer.forms import PopularityQueryForm
from apps.analyzer.models import (
    SCOPED_CLASSIFIER_CLASSES,
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierPrompt,
    MClassifierTag,
    MClassifierText,
    MClassifierTitle,
    MClassifierUrl,
    MPopularityQuery,
    get_classifiers_for_user,
    validate_regex_pattern,
)
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed
from apps.social.models import MSocialSubscription
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required, get_user


def index(requst):
    pass


def _get_recent_story_hashes(feed_id, hours=24):
    """Get story hashes from the last N hours for a feed from Redis."""
    import time

    try:
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        cutoff = int(time.time()) - hours * 60 * 60
        hashes = r.zrangebyscore(f"zF:{feed_id}", cutoff, "+inf")
        return [h.decode("utf-8") if isinstance(h, bytes) else h for h in hashes]
    except redis.ConnectionError:
        return []


@require_POST
@ajax_login_required
@json.json_view
def save_classifier(request):
    post = request.POST
    feed_id = post["feed_id"]
    feed = None
    social_user_id = None

    # Scope controls: 'feed' (default), 'folder', or 'global'
    scope = post.get("scope", "feed")

    if feed_id.startswith("social:"):
        social_user_id = int(feed_id.replace("social:", ""))
        feed_id = None
    else:
        feed_id = int(feed_id)
        if feed_id:
            feed = get_object_or_404(Feed, pk=feed_id)
    code = 0
    message = "OK"
    payload = {}
    scope_folder_name = post.get("folder_name", "")
    if scope not in ("feed", "folder", "global"):
        scope = "feed"

    # Archive gating for folder/global scope
    if scope != "feed" and not request.user.profile.is_archive:
        return dict(code=-1, message="Premium Archive required for folder and global classifiers")

    logging.user(
        request,
        "~FGSaving classifier: ~SB%s~SN (scope=%s%s) ~FW%s"
        % (feed, scope, " folder=%s" % scope_folder_name if scope == "folder" else "", post),
    )

    # Mark subscription as dirty, so unread counts can be recalculated
    usersub = None
    socialsub = None
    if social_user_id:
        socialsub = MSocialSubscription.objects.get(
            user_id=request.user.pk, subscription_user_id=social_user_id
        )
        if not socialsub.needs_unread_recalc:
            socialsub.needs_unread_recalc = True
            socialsub.save()
    elif scope == "feed":
        try:
            usersub = UserSubscription.objects.get(user=request.user, feed=feed)
        except UserSubscription.DoesNotExist:
            pass
        if usersub and (not usersub.needs_unread_recalc or not usersub.is_trained):
            usersub.needs_unread_recalc = True
            usersub.is_trained = True
            usersub.save()
    elif scope == "global":
        # Mark all user subscriptions as needing recalc
        UserSubscription.objects.filter(user=request.user).update(needs_unread_recalc=True)
    elif scope == "folder":
        # Mark subscriptions in the folder as needing recalc
        from apps.reader.models import UserSubscriptionFolders

        try:
            usf = UserSubscriptionFolders.objects.get(user=request.user)
            flat_folders = usf.flatten_folders()
            folder_feed_ids = flat_folders.get(scope_folder_name, [])
            if folder_feed_ids:
                UserSubscription.objects.filter(user=request.user, feed_id__in=folder_feed_ids).update(
                    needs_unread_recalc=True
                )
        except UserSubscriptionFolders.DoesNotExist:
            pass

    def _save_classifier(ClassifierCls, content_type):
        # Standard classifiers (non-regex)
        classifiers = {
            "like_" + content_type: (1, False),
            "dislike_" + content_type: (-1, False),
            "super_dislike_" + content_type: (-2, False),
            "remove_like_" + content_type: (0, False),
            "remove_dislike_" + content_type: (0, False),
            "remove_super_dislike_" + content_type: (0, False),
        }
        # Add regex classifier for title, text, and url types
        if content_type in ("title", "text", "url"):
            classifiers.update(
                {
                    "like_" + content_type + "_regex": (1, True),
                    "dislike_" + content_type + "_regex": (-1, True),
                    "super_dislike_" + content_type + "_regex": (-2, True),
                    "remove_like_" + content_type + "_regex": (0, True),
                    "remove_dislike_" + content_type + "_regex": (0, True),
                    "remove_super_dislike_" + content_type + "_regex": (0, True),
                }
            )

        # Determine scope fields for this classifier type (not applicable to feed classifier)
        use_scope = content_type != "feed" and scope != "feed"

        for opinion, (score, is_regex) in classifiers.items():
            if opinion in post:
                post_contents = post.getlist(opinion)
                for post_content in post_contents:
                    if not post_content:
                        continue

                    # Validate regex patterns before saving
                    if is_regex and score != 0:
                        is_valid, error_msg = validate_regex_pattern(post_content)
                        if not is_valid:
                            logging.user(
                                request, "~FRInvalid regex pattern: %s - %s" % (post_content, error_msg)
                            )
                            continue

                    classifier_dict = {
                        "user_id": request.user.pk,
                        "feed_id": 0 if use_scope else (feed_id or 0),
                        "social_user_id": social_user_id or 0,
                    }
                    if use_scope:
                        classifier_dict["scope"] = scope
                        classifier_dict["folder_name"] = scope_folder_name if scope == "folder" else ""
                    if content_type in ("author", "tag", "title", "text", "url"):
                        max_length = ClassifierCls._fields[content_type].max_length
                        classifier_dict.update({content_type: post_content[:max_length]})
                        # Add is_regex for title, text, and url classifiers
                        if content_type in ("title", "text", "url"):
                            classifier_dict["is_regex"] = is_regex
                    elif content_type == "feed":
                        if not post_content.startswith("social:"):
                            classifier_dict["feed_id"] = post_content
                    try:
                        classifier = ClassifierCls.objects.get(**classifier_dict)
                    except ClassifierCls.DoesNotExist:
                        # Fallback for old classifiers missing scope/is_regex/folder_name fields
                        fallback_dict = {
                            k: v
                            for k, v in classifier_dict.items()
                            if k not in ("scope", "folder_name", "is_regex")
                        }
                        if fallback_dict != classifier_dict:
                            try:
                                classifier = ClassifierCls.objects.get(**fallback_dict)
                            except (ClassifierCls.DoesNotExist, ClassifierCls.MultipleObjectsReturned):
                                classifier = None
                        else:
                            classifier = None
                    except ClassifierCls.MultipleObjectsReturned:
                        classifiers_found = ClassifierCls.objects.filter(**classifier_dict)
                        if score == 0:
                            for classifier in classifiers_found:
                                classifier.delete()
                        else:
                            first_classifier = classifiers_found[0]
                            first_classifier.score = score
                            first_classifier.save()
                            for dup in classifiers_found[1:]:
                                dup.delete()
                        continue
                    if not classifier:
                        if score != 0:
                            try:
                                classifier_dict.update(dict(score=score))
                                classifier = ClassifierCls.objects.create(**classifier_dict)
                            except NotUniqueError:
                                continue
                    elif score == 0:
                        classifier.delete()
                    elif classifier.score != score:
                        classifier.score = score
                        classifier.save()

    _save_classifier(MClassifierAuthor, "author")
    _save_classifier(MClassifierTag, "tag")
    _save_classifier(MClassifierTitle, "title")
    _save_classifier(MClassifierText, "text")
    _save_classifier(MClassifierUrl, "url")
    _save_classifier(MClassifierFeed, "feed")

    # Handle AI prompt classifiers (content and image)
    # Content prompts: like_prompt / dislike_prompt (include_images=False)
    # Image prompts: like_image_prompt / dislike_image_prompt (include_images=True)
    prompt_opinions = {
        "like_prompt": ("focus", False),
        "dislike_prompt": ("hidden", False),
        "remove_like_prompt": (None, False),
        "remove_dislike_prompt": (None, False),
        "like_image_prompt": ("focus", True),
        "dislike_image_prompt": ("hidden", True),
        "remove_like_image_prompt": (None, True),
        "remove_dislike_image_prompt": (None, True),
    }
    for opinion, (classifier_type, include_images) in prompt_opinions.items():
        if opinion in post:
            for prompt_text in post.getlist(opinion):
                if not prompt_text:
                    continue
                if len(prompt_text) > 500:
                    continue
                use_scope = scope != "feed"
                lookup = {
                    "user_id": request.user.pk,
                    "feed_id": 0 if use_scope else (feed_id or 0),
                    "folder_id": scope_folder_name if scope == "folder" else "",
                    "prompt": prompt_text,
                    "include_images": include_images,
                }
                try:
                    classifier = MClassifierPrompt.objects.get(**lookup)
                except MClassifierPrompt.DoesNotExist:
                    classifier = None
                except MClassifierPrompt.MultipleObjectsReturned:
                    classifiers_found = MClassifierPrompt.objects.filter(**lookup)
                    if classifier_type is None:
                        for c in classifiers_found:
                            c.delete()
                    else:
                        first = classifiers_found[0]
                        first.classifier_type = classifier_type
                        first.save()
                        for dup in classifiers_found[1:]:
                            dup.delete()
                    continue
                if not classifier:
                    if classifier_type is not None:
                        MClassifierPrompt.objects.create(
                            user_id=request.user.pk,
                            feed_id=0 if use_scope else (feed_id or 0),
                            folder_id=scope_folder_name if scope == "folder" else "",
                            prompt=prompt_text,
                            classifier_type=classifier_type,
                            include_images=include_images,
                        )
                elif classifier_type is None:
                    classifier.delete()
                elif classifier.classifier_type != classifier_type:
                    classifier.classifier_type = classifier_type
                    classifier.save()

    # Queue async classification for recent stories when a prompt classifier is added
    has_new_prompt = any(opinion in post for opinion in prompt_opinions if "remove_" not in opinion)
    if has_new_prompt and feed_id:
        from apps.analyzer.tasks import ClassifyStoriesWithPrompt

        recent_hashes = _get_recent_story_hashes(feed_id, hours=24)
        if recent_hashes:
            ClassifyStoriesWithPrompt.delay(request.user.pk, recent_hashes)

    # Update has_scoped_classifiers flag on profile
    if scope != "feed":
        if not request.user.profile.has_scoped_classifiers:
            request.user.profile.has_scoped_classifiers = True
            request.user.profile.save()

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "feed:%s" % feed_id)

    response = dict(code=code, message=message, payload=payload)
    return response


@require_POST
@ajax_login_required
@json.json_view
def save_prompt_classifier(request):
    """Save or delete an AI prompt classifier with optional image vision support."""
    post = request.POST
    feed_id = int(post.get("feed_id", 0))
    prompt = post.get("prompt", "").strip()
    classifier_type = post.get("classifier_type", "focus")
    include_images = post.get("include_images", "false") == "true"
    action = post.get("action", "save")  # "save" or "delete"
    prompt_id = post.get("prompt_id", "")

    if classifier_type not in ("focus", "hidden"):
        return {"code": -1, "message": "Invalid classifier_type"}

    if action == "delete" and prompt_id:
        try:
            classifier = MClassifierPrompt.objects.get(id=prompt_id, user_id=request.user.pk)
            classifier.delete()
            MClassifierPrompt.invalidate_cache(request.user.pk, prompt_id)
            logging.user(request, "~FGDeleted prompt classifier: ~SB%s" % prompt_id)
        except MClassifierPrompt.DoesNotExist:
            return {"code": -1, "message": "Prompt classifier not found"}
    elif action == "save" and prompt:
        if len(prompt) > 500:
            return {"code": -1, "message": "Prompt too long (max 500 characters)"}

        classifier = MClassifierPrompt(
            user_id=request.user.pk,
            feed_id=feed_id,
            prompt=prompt,
            classifier_type=classifier_type,
            include_images=include_images,
        )
        classifier.save()
        logging.user(
            request,
            "~FGSaved prompt classifier: ~SB%s~SN (type=%s, images=%s) ~FW%s"
            % (feed_id, classifier_type, include_images, prompt[:50]),
        )

        # Mark subscription as needing recalc
        if feed_id:
            try:
                usersub = UserSubscription.objects.get(user=request.user, feed_id=feed_id)
                usersub.needs_unread_recalc = True
                usersub.save()
            except UserSubscription.DoesNotExist:
                pass

        # Queue async classification for recent stories
        if feed_id:
            from apps.analyzer.tasks import ClassifyStoriesWithPrompt

            recent_hashes = _get_recent_story_hashes(feed_id, hours=24)
            if recent_hashes:
                ClassifyStoriesWithPrompt.delay(request.user.pk, recent_hashes)
    else:
        return {"code": -1, "message": "Missing prompt or prompt_id"}

    # Return current prompt classifiers for this feed
    prompts = MClassifierPrompt.objects.filter(user_id=request.user.pk, feed_id=feed_id)
    prompt_list = [
        {
            "id": str(p.id),
            "prompt": p.prompt,
            "classifier_type": p.classifier_type,
            "include_images": p.include_images,
        }
        for p in prompts
    ]

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "feed:%s" % feed_id)

    from apps.analyzer.vlm_usage import AIClassifierCostEstimator

    cost_estimate = {}
    if request.user.profile.can_use_ai_classifiers:
        estimator = AIClassifierCostEstimator(request.user)
        cost_estimate = estimator.get_cost_estimate(feed_id=feed_id)

    return {"code": 0, "message": "OK", "prompt_classifiers": prompt_list, "cost_estimate": cost_estimate}


@require_POST
@ajax_login_required
@json.json_view
def test_prompt_classifier(request):
    """Test a prompt against a story using AI. Supports text-only or image (VLM) modes."""
    import zlib

    from apps.rss_feeds.models import MStory
    from utils.ai_functions import (
        classify_stories_with_ai,
        classify_stories_with_vision,
    )

    if not request.user.profile.can_use_ai_classifiers:
        return {"code": -1, "message": "Usage billing required for AI classifiers"}

    post = request.POST
    prompt_text = post.get("prompt", "").strip()
    story_hash = post.get("story_hash", "")
    include_images = post.get("include_images", "false") == "true"

    if not prompt_text:
        return {"code": -1, "message": "Missing prompt"}
    if not story_hash:
        return {"code": -1, "message": "Missing story_hash"}

    try:
        story_db = MStory.objects.get(story_hash=story_hash)
    except MStory.DoesNotExist:
        return {"code": -1, "message": "Story not found"}

    # Build a temporary prompt-like object for the classifier
    class TempPrompt:
        pass

    temp_prompt = TempPrompt()
    temp_prompt.prompt = prompt_text

    if include_images:
        # VLM mode: classify each image individually so the frontend
        # can show per-image match/no-match labels.
        image_urls = story_db.image_urls or []
        if not image_urls:
            return {"code": -1, "message": "Story has no images"}

        # Send each image as its own "story" so VLM returns per-image results
        image_stories = []
        for i, url in enumerate(image_urls):
            image_stories.append(
                {
                    "story_id": "img_%d" % i,
                    "story_title": "",
                    "story_content": "",
                    "image_urls": [url],
                }
            )
        results = classify_stories_with_vision(temp_prompt, image_stories, user_id=request.user.pk)

        # Build per-image results list (ordered by image index)
        image_results = []
        for i in range(len(image_urls)):
            cls = results.get("img_%d" % i, 0)
            image_results.append(1 if cls != 0 else 0)

        classification = 1 if any(r == 1 for r in image_results) else 0
    else:
        # Text-only mode: classify based on title and content
        story_content = story_db.story_content or ""
        if story_db.story_content_z:
            story_content = zlib.decompress(story_db.story_content_z).decode("utf-8")

        story_dict = {
            "story_id": story_hash,
            "story_title": story_db.story_title or "",
            "story_content": story_content,
        }
        results = classify_stories_with_ai(temp_prompt, [story_dict], user_id=request.user.pk)

    if not include_images:
        classification = results.get(story_hash, 0)
        classification = 1 if classification != 0 else 0

    mode = "vision" if include_images else "text"

    # Include cost estimate so frontend can show per-run cost
    cost_estimate = {}
    if request.user.profile.can_use_ai_classifiers:
        from apps.analyzer.vlm_usage import AIClassifierCostEstimator

        estimator = AIClassifierCostEstimator(request.user)
        cost_estimate = estimator.get_cost_estimate(feed_id=int(request.POST.get("feed_id", 0)))

    logging.user(
        request,
        "~FBTested %s prompt: ~SB%s~SN → %s ~FW%s" % (mode, story_hash, classification, prompt_text[:50]),
    )

    resp = {"code": 0, "classification": classification, "cost_estimate": cost_estimate}
    if include_images:
        resp["image_results"] = image_results
    return resp


@ajax_login_required
@json.json_view
def get_ai_classifier_usage(request):
    from apps.analyzer.vlm_usage import AIClassifierCostEstimator

    if not request.user.profile.can_use_ai_classifiers:
        return {"code": 0, "can_use_ai": False}

    feed_id = int(request.GET.get("feed_id", 0) or request.POST.get("feed_id", 0))
    estimator = AIClassifierCostEstimator(request.user)
    cost_estimate = estimator.get_cost_estimate(feed_id=feed_id)

    current_spend, limit, is_limit_reached = request.user.profile.get_usage_billing_spend()
    cost_estimate["current_cycle_spend"] = round(current_spend, 2)
    cost_estimate["usage_billing_limit"] = float(limit) if limit else None
    cost_estimate["is_limit_reached"] = is_limit_reached

    return {"code": 0, "can_use_ai": True, **cost_estimate}


@json.json_view
def get_classifiers_feed(request, feed_id):
    user = get_user(request)
    code = 0

    payload = get_classifiers_for_user(user, feed_id=feed_id)

    response = dict(code=code, payload=payload)

    return response


@require_POST
@ajax_login_required
@json.json_view
def save_all_classifiers(request):
    """
    Bulk save classifiers for multiple feeds in a single request.
    Expects JSON body with format:
    {
        "classifiers": {
            "feed_id": {
                "like_author": ["author1", "author2"],
                "dislike_tag": ["tag1"],
                "remove_like_title": ["title1"],
                ...
            },
            ...
        }
    }
    """
    try:
        body = json.decode(request.body)
    except (ValueError, TypeError):
        return {"code": -1, "message": "Invalid JSON"}

    classifiers_by_feed = body.get("classifiers", {})
    if not classifiers_by_feed:
        return {"code": 0, "message": "No classifiers to save"}

    logging.user(request, "~FGBulk saving classifiers for ~SB%s~SN feeds" % len(classifiers_by_feed))

    feeds_updated = []

    for feed_id_str, classifier_data in classifiers_by_feed.items():
        feed_id = None
        social_user_id = None

        if feed_id_str.startswith("social:"):
            social_user_id = int(feed_id_str.replace("social:", ""))
        else:
            feed_id = int(feed_id_str)

        # Mark subscription as dirty for unread recalc
        if social_user_id:
            try:
                socialsub = MSocialSubscription.objects.get(
                    user_id=request.user.pk, subscription_user_id=social_user_id
                )
                if not socialsub.needs_unread_recalc:
                    socialsub.needs_unread_recalc = True
                    socialsub.save()
            except MSocialSubscription.DoesNotExist:
                pass
        else:
            try:
                usersub = UserSubscription.objects.get(user=request.user, feed_id=feed_id)
                if not usersub.needs_unread_recalc or not usersub.is_trained:
                    usersub.needs_unread_recalc = True
                    usersub.is_trained = True
                    usersub.save()
            except UserSubscription.DoesNotExist:
                pass

        # Process each classifier type
        _save_classifiers_for_feed(request.user.pk, feed_id, social_user_id, classifier_data)
        feeds_updated.append(feed_id_str)

    # Publish update notification
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "feed:%s" % ",".join(map(str, feeds_updated)))

    return {"code": 0, "message": "OK", "feeds_updated": feeds_updated}


def _save_classifiers_for_feed(user_id, feed_id, social_user_id, classifier_data):
    """
    Helper function to save classifiers for a single feed.
    classifier_data is a dict like:
    {
        "like_author": ["author1"],
        "dislike_tag": ["tag1"],
        "like_title_regex": ["pattern.*"],
        ...
    }
    """
    classifier_types = {
        "author": MClassifierAuthor,
        "tag": MClassifierTag,
        "title": MClassifierTitle,
        "text": MClassifierText,
        "url": MClassifierUrl,
        "feed": MClassifierFeed,
    }

    # Types that support regex matching
    regex_types = ("title", "text", "url")

    classifiers_config = {
        "like_": 1,
        "dislike_": -1,
        "remove_like_": 0,
        "remove_dislike_": 0,
    }

    for content_type, ClassifierCls in classifier_types.items():
        for prefix, score in classifiers_config.items():
            # Build list of keys to check: standard and regex (for applicable types)
            keys_to_check = [(prefix + content_type, False)]
            if content_type in regex_types:
                keys_to_check.append((prefix + content_type + "_regex", True))

            for key, is_regex in keys_to_check:
                if key not in classifier_data:
                    continue

                values = classifier_data[key]
                if not isinstance(values, list):
                    values = [values]

                for value in values:
                    if not value:
                        continue

                    # Validate regex patterns before saving
                    if is_regex and score != 0:
                        is_valid, error_msg = validate_regex_pattern(value)
                        if not is_valid:
                            logging.info("Invalid regex pattern: %s - %s" % (value, error_msg))
                            continue

                    classifier_dict = {
                        "user_id": user_id,
                        "feed_id": feed_id or 0,
                        "social_user_id": social_user_id or 0,
                    }

                    if content_type in ("author", "tag", "title", "text", "url"):
                        max_length = ClassifierCls._fields[content_type].max_length
                        classifier_dict[content_type] = value[:max_length]
                        # Set is_regex for types that support it
                        if content_type in regex_types:
                            classifier_dict["is_regex"] = is_regex
                    elif content_type == "feed":
                        if not str(value).startswith("social:"):
                            try:
                                classifier_dict["feed_id"] = int(value)
                            except (ValueError, TypeError):
                                # Skip invalid feed IDs
                                continue

                    try:
                        classifier = ClassifierCls.objects.get(**classifier_dict)
                    except ClassifierCls.DoesNotExist:
                        # Fallback for old classifiers missing scope/is_regex/folder_name fields
                        fallback_dict = {
                            k: v
                            for k, v in classifier_dict.items()
                            if k not in ("scope", "folder_name", "is_regex")
                        }
                        if fallback_dict != classifier_dict:
                            try:
                                classifier = ClassifierCls.objects.get(**fallback_dict)
                            except (ClassifierCls.DoesNotExist, ClassifierCls.MultipleObjectsReturned):
                                classifier = None
                        else:
                            classifier = None
                    except ClassifierCls.MultipleObjectsReturned:
                        classifiers = ClassifierCls.objects.filter(**classifier_dict)
                        if score == 0:
                            for classifier in classifiers:
                                classifier.delete()
                        else:
                            first_classifier = classifiers[0]
                            first_classifier.score = score
                            first_classifier.save()
                            for dup in classifiers[1:]:
                                dup.delete()
                        continue

                    if not classifier:
                        if score != 0:
                            try:
                                classifier_dict["score"] = score
                                ClassifierCls.objects.create(**classifier_dict)
                            except NotUniqueError:
                                pass
                    elif score == 0:
                        classifier.delete()
                    elif classifier.score != score:
                        classifier.score = score
                        classifier.save()

    # Handle AI prompt classifiers (prompt = text-only, image_prompt = VLM)
    prompt_opinions = {
        "like_prompt": ("focus", False),
        "dislike_prompt": ("hidden", False),
        "remove_like_prompt": (None, False),
        "remove_dislike_prompt": (None, False),
        "like_image_prompt": ("focus", True),
        "dislike_image_prompt": ("hidden", True),
        "remove_like_image_prompt": (None, True),
        "remove_dislike_image_prompt": (None, True),
    }
    for opinion, (classifier_type, include_images) in prompt_opinions.items():
        if opinion not in classifier_data:
            continue
        values = classifier_data[opinion]
        if not isinstance(values, list):
            values = [values]
        for prompt_text in values:
            if not prompt_text:
                continue
            lookup = {
                "user_id": user_id,
                "feed_id": feed_id or 0,
                "prompt": prompt_text,
                "include_images": include_images,
            }
            try:
                classifier = MClassifierPrompt.objects.get(**lookup)
            except MClassifierPrompt.DoesNotExist:
                classifier = None
            except MClassifierPrompt.MultipleObjectsReturned:
                classifiers_found = MClassifierPrompt.objects.filter(**lookup)
                if classifier_type is None:
                    for c in classifiers_found:
                        c.delete()
                else:
                    first = classifiers_found[0]
                    first.classifier_type = classifier_type
                    first.save()
                    for dup in classifiers_found[1:]:
                        dup.delete()
                continue
            if not classifier:
                if classifier_type is not None:
                    MClassifierPrompt.objects.create(
                        user_id=user_id,
                        feed_id=feed_id or 0,
                        prompt=prompt_text,
                        classifier_type=classifier_type,
                        include_images=include_images,
                    )
            elif classifier_type is None:
                classifier.delete()
            elif classifier.classifier_type != classifier_type:
                classifier.classifier_type = classifier_type
                classifier.save()


def popularity_query(request):
    if request.method == "POST":
        form = PopularityQueryForm(request.POST)
        if form.is_valid():
            logging.user(
                request.user,
                '~BC~FRPopularity query: ~SB%s~SN requests "~SB~FM%s~SN~FR"'
                % (request.POST["email"], request.POST["query"]),
            )
            query = MPopularityQuery.objects.create(email=request.POST["email"], query=request.POST["query"])
            query.queue_email()

            response = render(
                request,
                "analyzer/popularity_query.xhtml",
                {
                    "success": True,
                    "popularity_query_form": form,
                },
            )
            response.set_cookie("newsblur_popularity_query", request.POST["query"])

            return response
        else:
            logging.user(
                request.user,
                '~BC~FRFailed popularity query: ~SB%s~SN requests "~SB~FM%s~SN~FR"'
                % (request.POST["email"], request.POST["query"]),
            )
    else:
        logging.user(request.user, "~BC~FRPopularity query form loading")
        form = PopularityQueryForm(initial={"query": request.COOKIES.get("newsblur_popularity_query", "")})

    response = render(
        request,
        "analyzer/popularity_query.xhtml",
        {
            "popularity_query_form": form,
        },
    )

    return response
