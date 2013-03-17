import stripe, datetime, time
stripe.api_key = settings.STRIPE_SECRET

week = (datetime.datetime.now() - datetime.timedelta(days=7)).strftime('%s')
failed = []
limit = 100
offset = 0
while True:
    print " ---> At %s" % offset
    try:
        data = stripe.Customer.all(created={'gt': week}, count=limit, offset=offset)
    except stripe.APIConnectionError:
        time.sleep(10)
        continue
    customers = data['data']
    if not len(customers):
        print "At %s, finished" % offset
        break
    offset += limit
    usernames = [c['description'] for c in customers]
    for username in usernames:
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            print " ***> Couldn't find %s" % username
            failed.append(username)
        try:
            if not user.profile.is_premium:
                user.profile.activate_premium()
            elif user.payments.all().count() != 1:
                user.profile.setup_premium_history()
            else:
                print " ---> %s is fine" % username
        except stripe.APIConnectionError:
            print " ***> Failed: %s" % username
            failed.append(username)
            time.sleep(2)
            continue



