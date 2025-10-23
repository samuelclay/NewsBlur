import redis
from django.conf import settings
from django.shortcuts import get_object_or_404, render
from django.views.decorators.http import require_POST
from mongoengine.queryset import NotUniqueError

from apps.analyzer.forms import PopularityQueryForm
from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierText,
    MClassifierTitle,
    MPopularityQuery,
    get_classifiers_for_user,
)
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed
from apps.social.models import MSocialSubscription
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required, get_user


def index(requst):
    pass


@require_POST
@ajax_login_required
@json.json_view
def save_classifier(request):
    post = request.POST
    feed_id = post["feed_id"]
    feed = None
    social_user_id = None
    if feed_id.startswith("social:"):
        social_user_id = int(feed_id.replace("social:", ""))
        feed_id = None
    else:
        feed_id = int(feed_id)
        feed = get_object_or_404(Feed, pk=feed_id)
    code = 0
    message = "OK"
    payload = {}

    logging.user(request, "~FGSaving classifier: ~SB%s~SN ~FW%s" % (feed, post))

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
    else:
        try:
            usersub = UserSubscription.objects.get(user=request.user, feed=feed)
        except UserSubscription.DoesNotExist:
            pass
        if usersub and (not usersub.needs_unread_recalc or not usersub.is_trained):
            usersub.needs_unread_recalc = True
            usersub.is_trained = True
            usersub.save()

    def _save_classifier(ClassifierCls, content_type):
        classifiers = {
            "like_" + content_type: 1,
            "dislike_" + content_type: -1,
            "remove_like_" + content_type: 0,
            "remove_dislike_" + content_type: 0,
        }
        for opinion, score in classifiers.items():
            if opinion in post:
                post_contents = post.getlist(opinion)
                for post_content in post_contents:
                    if not post_content:
                        continue
                    classifier_dict = {
                        "user_id": request.user.pk,
                        "feed_id": feed_id or 0,
                        "social_user_id": social_user_id or 0,
                    }
                    if content_type in ("author", "tag", "title", "text"):
                        max_length = ClassifierCls._fields[content_type].max_length
                        classifier_dict.update({content_type: post_content[:max_length]})
                    elif content_type == "feed":
                        if not post_content.startswith("social:"):
                            classifier_dict["feed_id"] = post_content
                    try:
                        classifier = ClassifierCls.objects.get(**classifier_dict)
                    except ClassifierCls.DoesNotExist:
                        classifier = None
                    except ClassifierCls.MultipleObjectsReturned:
                        classifiers = ClassifierCls.objects.filter(**classifier_dict)
                        for classifier in classifiers:
                            # Update the score of the first classifier, delete the others, but don't delete more than 1
                            first_classifier = classifiers[0]
                            first_classifier.score = score
                            first_classifier.save()
                            for classifier in classifiers[1:]:
                                classifier.delete()
                                break
                            logging.info(
                                f"Updated classifier {first_classifier.id} and deleted one duplicate."
                            )
                            continue
                    if not classifier:
                        try:
                            classifier_dict.update(dict(score=score))
                            classifier = ClassifierCls.objects.create(**classifier_dict)
                        except NotUniqueError:
                            continue
                    if score == 0:
                        classifier.delete()
                    elif classifier.score != score:
                        if score == 0:
                            if (classifier.score == 1 and opinion.startswith("remove_like")) or (
                                classifier.score == -1 and opinion.startswith("remove_dislike")
                            ):
                                classifier.delete()
                        else:
                            classifier.score = score
                            classifier.save()

    _save_classifier(MClassifierAuthor, "author")
    _save_classifier(MClassifierTag, "tag")
    _save_classifier(MClassifierTitle, "title")
    _save_classifier(MClassifierText, "text")
    _save_classifier(MClassifierFeed, "feed")

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "feed:%s" % feed_id)

    response = dict(code=code, message=message, payload=payload)
    return response


@json.json_view
def get_classifiers_feed(request, feed_id):
    user = get_user(request)
    code = 0

    payload = get_classifiers_for_user(user, feed_id=feed_id)

    response = dict(code=code, payload=payload)

    return response


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
