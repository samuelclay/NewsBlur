import sys
from mongoengine.queryset import OperationError
from mongoengine.base import ValidationError
from apps.analyzer.models import MClassifierFeed
from apps.analyzer.models import MClassifierAuthor
from apps.analyzer.models import MClassifierTag
from apps.analyzer.models import MClassifierTitle

for classifier_cls in [MClassifierFeed, MClassifierAuthor, 
                       MClassifierTag, MClassifierTitle]:
    print " ================================================================= "
    print "                  Now on %s " % classifier_cls.__name__
    print " ================================================================= "
    classifiers = classifier_cls.objects.filter(social_user_id__exists=False)
    count = classifiers.count()
    print " ---> Found %s classifiers" % count
    for i, classifier in enumerate(classifiers):
        if i % 1000 == 0:
            print " ---> %s / %s" % (i, count)
            sys.stdout.flush()
        classifier.social_user_id = 0
        try:
            classifier.save()
        except OperationError, e:
            print " ***> Operation error on: %s" % e
            sys.stdout.flush()
            # classifier.delete()
        except ValidationError, e:
            print " ***> ValidationError error on: %s" % e
            print " ***> Original classifier: %s" % classifier.__dict__

