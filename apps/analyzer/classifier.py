from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed, Story
from apps.reader.models import UserSubscription, UserStory
from apps.analyzer.models import Category, FeatureCategory
import datetime
import re
import math

class Classifier:
    
    def __init__(self, user, feed):
        self.user = user
        self.feed = feed

    def get_features(self, doc):
        splitter=re.compile('\\W*')
        # Split the words by non-alpha characters
        words=[s.lower() for s in splitter.split(doc) 
              if len(s)>2 and len(s)<20]
  
        # Return the unique set of words only
        return dict([(w,1) for w in words])
        
    def increment_feature(self, feature, category):
        count = self.feature_count(feature,category)
        if count==0:
            fc = FeatureCategory(user=self.user, feed=self.feed, feature=feature, category=category, count=1)
            fc.save()
        else:
            fc = FeatureCategory.objects.get(user=self.user, feed=self.feed, feature=feature, category=category)
            fc.count = count + 1
            fc.save()
              
    def feature_count(self, feature, category):
        try:
            feature_count = FeatureCategory.objects.get(user=self.user, feed=self.feed, feature=feature, category=category)
        except FeatureCategory.DoesNotExist:
            return 0
        else:
            return float(feature_count.count)

    def increment_category(self,category):
        count = self.category_count(category)
        if count==0:
            category = Category(user=self.user, feed=self.feed, category=category, count=1)
            category.save()
        else:
            category = Category.objects.get(user=self.user, feed=self.feed, category=category)
            category.count = count+1
            category.save()

    def category_count(self, category):
        try:
            category_count = Category.objects.get(user=self.user, feed=self.feed, category=category)
        except Category.DoesNotExist:
            return 0
        else:
            return float(category_count.count)

    def categories(self):
        categories = Category.objects.all()
        return categories

    def totalcount(self):
        categories = Category.objects.filter(user=self.user, feed=self.feed).aggregate(sum=Sum(count))
        return categories.sum

    def train(self, item, category):
        features = self.get_features(item)
        
        # Increment the count for every feature with this category
        for feature in features:
            self.increment_feature(feature, category)

        # Increment the count for this category
        self.increment_category(category)

    def feature_probability(self, feature, category):
        if self.category_count(category) == 0:
            return 0

        # The total number of times this feature appeared in this 
        # category divided by the total number of items in this category
        return self.feature_count(feature, category) / self.category_count(category)

    def weighted_probability(self, feature, category, prf, weight=1.0, ap=0.5):
        # Calculate current probability
        basic_prob = prf(feature, category)

        # Count the number of times this feature has appeared in all categories
        totals = sum([self.feature_count(feature, category) for c in self.categories()])

        # Calculate the weighted average
        bp = ((weight*ap) + (totals*basic_prob)) / (weight+totals)
        
        return bp


class FisherClassifier(Classifier):
 
    def __init__(self, user, feed):
        Classifier.__init__(self, user, feed)
        self.minimums = {}
        
    def category_probability(self, feature, category):
        # The frequency of this feature in this category    
        clf = self.feature_probability(feature, category)
        if clf==0: 
            return 0

        # The frequency of this feature in all the categories
        freqsum = sum([self.feature_probability(feature, category) for c in self.categories()])

        # The probability is the frequency in this category divided by
        # the overall frequency
        p = clf / freqsum
    
        return p
        
    def fisher_probability(self, item, category):
        # Multiply all the probabilities together
        p = 1
        features = self.get_features(item)
        
        for feature in features:
            p *= (self.weighted_probability(feature, category, self.category_probability))

        # Take the natural log and multiply by -2
        fscore = -2*math.log(p)

        # Use the inverse chi2 function to get a probability
        return self.invchi2(fscore,len(features)*2)
        
    def invchi2(self, chi, df):
        m = chi / 2.0
        sum = term = math.exp(-m)
        for i in range(1, df//2):
            term *= m / i
            sum += term
        return min(sum, 1.0)
        

    def setminimum(self, category, min):
        self.minimums[category] = min
  
    def getminimum(self, category):
        if category not in self.minimums:
            return 0

        return self.minimums[category]
        
    def classify(self,item,default=None):
        # Loop through looking for the best result
        best = default
        max = 0.0
        
        for category in self.categories():
            p=self.fisher_probability(item, category)
            # Make sure it exceeds its minimum
            if p > self.getminimum(category) and p > max:
                best = category
                max = p
        
        return best
