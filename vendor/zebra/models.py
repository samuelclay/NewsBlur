from django.db import models

from zebra import mixins
from zebra.conf import options


class StripeCustomer(models.Model, mixins.StripeMixin, mixins.StripeCustomerMixin):
    stripe_customer_id = models.CharField(max_length=50, blank=True, null=True)

    class Meta:
        abstract = True

    def __str__(self):
        return "%s" % self.stripe_customer_id


class StripePlan(models.Model, mixins.StripeMixin, mixins.StripePlanMixin):
    stripe_plan_id = models.CharField(max_length=50, blank=True, null=True)

    class Meta:
        abstract = True

    def __str__(self):
        return "%s" % self.stripe_plan_id


class StripeSubscription(models.Model, mixins.StripeMixin, mixins.StripeSubscriptionMixin):
    """
    You need to provide a stripe_customer attribute. See zebra.models for an
    example implimentation.
    """
    class Meta:
        abstract = True


# Non-abstract classes must be enabled in your project's settings.py
if options.ZEBRA_ENABLE_APP:
    class DatesModelBase(models.Model):
        date_created = models.DateTimeField(auto_now_add=True)
        date_modified = models.DateTimeField(auto_now=True)

        class Meta:
            abstract = True

    class Customer(DatesModelBase, StripeCustomer):
        pass

    class Plan(DatesModelBase, StripePlan):
        pass

    class Subscription(DatesModelBase, StripeSubscription):
        customer = models.ForeignKey(Customer, on_delete=models.CASCADE)
        plan = models.ForeignKey(Plan, on_delete=models.CASCADE)

        def __str__(self):
            return "%s: %s" % (self.customer, self.plan)

        @property
        def stripe_customer(self):
            return self.customer.stripe_customer