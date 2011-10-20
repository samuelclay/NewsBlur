Django PayPal
=============


About
-----

Django PayPal is a pluggable application that implements with PayPal Payments 
Standard and Payments Pro.

Before diving in, a quick review of PayPal's payment methods is in order! [PayPal Payments Standard](https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_WebsitePaymentsStandard_IntegrationGuide.pdf) is the "Buy it Now" buttons you may have
seen floating around the internets. Buyers click on the button and are taken to PayPal's website where they can pay for the product. After completing the purchase PayPal makes an HTTP POST to your  `notify_url`. PayPal calls this process [Instant Payment Notification](https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_OrderMgmt_IntegrationGuide.pdf) (IPN) but you may know it as [webhooks](http://blog.webhooks.org). This method kinda sucks because it drops your customers off at PayPal's website but it's easy to implement and doesn't require SSL.

PayPal Payments Pro allows you to accept payments on your website. It contains two distinct payment flows - Direct Payment allows the user to enter credit card information on your website and pay on your website. Express Checkout sends the user over to PayPal to confirm their payment method before redirecting back to your website for confirmation. PayPal rules state that both methods must be implemented.

There is currently an active discussion over the handling of some of the finer points of the PayPal API and the evolution of this code base - check it out over at [Django PayPal on Google Groups](http://groups.google.com/group/django-paypal).


Using PayPal Payments Standard IPN:
-------------------------------

1. Download the code from GitHub:

        git clone git://github.com/johnboxall/django-paypal.git paypal

1. Edit `settings.py` and add  `paypal.standard.ipn` to your `INSTALLED_APPS` 
   and `PAYPAL_RECEIVER_EMAIL`:

        # settings.py
        ...
        INSTALLED_APPS = (... 'paypal.standard.ipn', ...)
        ...
        PAYPAL_RECEIVER_EMAIL = "yourpaypalemail@example.com"

1.  Create an instance of the `PayPalPaymentsForm` in the view where you would 
    like to collect money. Call `render` on the instance in your template to 
    write out the HTML.

        # views.py
        ...
        from vendor.paypal.standard.forms import PayPalPaymentsForm
        
        def view_that_asks_for_money(request):
        
            # What you want the button to do.
            paypal_dict = {
                "business": "yourpaypalemail@example.com",
                "amount": "10000000.00",
                "item_name": "name of the item",
                "invoice": "unique-invoice-id",
                "notify_url": "http://www.example.com/your-ipn-location/",
                "return_url": "http://www.example.com/your-return-location/",
                "cancel_return": "http://www.example.com/your-cancel-location/",
            
            }
            
            # Create the instance.
            form = PayPalPaymentsForm(initial=paypal_dict)
            context = {"form": form}
            return render_to_response("payment.html", context)
            
            
        <!-- payment.html -->
        ...
        <h1>Show me the money!</h1>
        <!-- writes out the form tag automatically -->
        {{ form.render }}

1.  When someone uses this button to buy something PayPal makes a HTTP POST to 
    your "notify_url". PayPal calls this Instant Payment Notification (IPN). 
    The view `paypal.standard.ipn.views.ipn` handles IPN processing. To set the 
    correct `notify_url` add the following to your `urls.py`:

        # urls.py
        ...
        urlpatterns = patterns('',
            (r'^something/hard/to/guess/', include('paypal.standard.ipn.urls')),
        )

1.  Whenever an IPN is processed a signal will be sent with the result of the 
    transaction. Connect the signals to actions to perform the needed operations
    when a successful payment is recieved.
    
    There are two signals for basic transactions:
    - `payment_was_succesful` 
    - `payment_was_flagged`
    
    And four signals for subscriptions:
    - `subscription_cancel` - Sent when a subscription is cancelled.
    - `subscription_eot` - Sent when a subscription expires.
    - `subscription_modify` - Sent when a subscription is modified.
    - `subscription_signup` - Sent when a subscription is created.

	Connect to these signals and update your data accordingly. [Django Signals Documentation](http://docs.djangoproject.com/en/dev/topics/signals/).

        # models.py
        ...
        from vendor.paypal.standard.ipn.signals import payment_was_successful
        
        def show_me_the_money(sender, **kwargs):
            ipn_obj = sender
            # Undertake some action depending upon `ipn_obj`.
            if ipn_obj.custom == "Upgrade all users!":
                Users.objects.update(paid=True)        
        payment_was_successful.connect(show_me_the_money)
        
        
Using PayPal Payments Standard PDT:
-------------------------------

Paypal Payment Data Transfer (PDT) allows you to display transaction details to a customer immediately on return to your site unlike PayPal IPN which may take some seconds. [You will need to enable PDT in your PayPal account to use it.your PayPal account to use it](https://cms.paypal.com/us/cgi-bin/?cmd=_render-content&content_ID=developer/howto_html_paymentdatatransfer).

1. Download the code from GitHub:

        git clone git://github.com/johnboxall/django-paypal.git paypal

1. Edit `settings.py` and add  `paypal.standard.pdt` to your `INSTALLED_APPS`. Also set `PAYPAL_IDENTITY_TOKEN` - you can find the correct value of this setting from the PayPal website:

        # settings.py
        ...
        INSTALLED_APPS = (... 'paypal.standard.pdt', ...)
        
        PAYPAL_IDENTITY_TOKEN = "xxx"

1.  Create a view that uses `PayPalPaymentsForm` just like in PayPal IPN.

1.  After someone uses this button to buy something PayPal will return the user to your site at 
    your "return_url" with some extra GET parameters. PayPal calls this Payment Data Transfer (PDT). 
    The view `paypal.standard.pdt.views.pdt` handles PDT processing. to specify the correct
     `return_url` add the following to your `urls.py`:

        # urls.py
        ...
        urlpatterns = patterns('',
            (r'^paypal/pdt/', include('paypal.standard.pdt.urls')),
            ...
        )

Using PayPal Payments Standard with Subscriptions:
-------------------------------

1.  For subscription actions, you'll need to add a parameter to tell it to use the subscription buttons and the command, plus any 
    subscription-specific settings:

        # views.py
        ...
        paypal_dict = {
            "cmd": "_xclick-subscriptions",
            "business": "your_account@paypal",
            "a3": "9.99",                      # monthly price 
            "p3": 1,                           # duration of each unit (depends on unit)
            "t3": "M",                         # duration unit ("M for Month")
            "src": "1",                        # make payments recur
            "sra": "1",                        # reattempt payment on payment error
            "no_note": "1",                    # remove extra notes (optional)
            "item_name": "my cool subscription",
            "notify_url": "http://www.example.com/your-ipn-location/",
            "return_url": "http://www.example.com/your-return-location/",
            "cancel_return": "http://www.example.com/your-cancel-location/",
        }

        # Create the instance.
        form = PayPalPaymentsForm(initial=paypal_dict, button_type="subscribe")
        
        # Output the button.
        form.render()


Using PayPal Payments Standard with Encrypted Buttons:
------------------------------------------------------

Use this method to encrypt your button so sneaky gits don't try to hack it. Thanks to [Jon Atkinson](http://jonatkinson.co.uk/) for the [tutorial](http://jonatkinson.co.uk/paypal-encrypted-buttons-django/).

1. Encrypted buttons require the `M2Crypto` library:

        easy_install M2Crypto
    

1. Encrypted buttons require certificates. Create a private key:

        openssl genrsa -out paypal.pem 1024

1. Create a public key:

        openssl req -new -key paypal.pem -x509 -days 365 -out pubpaypal.pem

1. Upload your public key to the paypal website (sandbox or live).
        
    [https://www.paypal.com/us/cgi-bin/webscr?cmd=_profile-website-cert](https://www.paypal.com/us/cgi-bin/webscr?cmd=_profile-website-cert)

    [https://www.paypal.com/us/cgi-bin/webscr?cmd=_profile-website-cert](https://www.sandbox.paypal.com/us/cgi-bin/webscr?cmd=_profile-website-cert)

1.  Copy your `cert id` - you'll need it in two steps. It's on the screen where
    you uploaded your public key.

1. Download PayPal's public certificate - it's also on that screen.

1. Edit your `settings.py` to include cert information:

        # settings.py
        PAYPAL_PRIVATE_CERT = '/path/to/paypal.pem'
        PAYPAL_PUBLIC_CERT = '/path/to/pubpaypal.pem'
        PAYPAL_CERT = '/path/to/paypal_cert.pem'
        PAYPAL_CERT_ID = 'get-from-paypal-website'

1. Swap out your unencrypted button for a `PayPalEncryptedPaymentsForm`:

        # views.py
        from vendor.paypal.standard.forms import PayPalEncryptedPaymentsForm
        
        def view_that_asks_for_money(request):
            ...
            # Create the instance.
            form = PayPalPaymentsForm(initial=paypal_dict)
            # Works just like before!
            form.render()


Using PayPal Payments Standard with Encrypted Buttons and Shared Secrets:
-------------------------------------------------------------------------

This method uses Shared secrets instead of IPN postback to verify that transactions
are legit. PayPal recommends you should use Shared Secrets if:

    * You are not using a shared website hosting service. 
    * You have enabled SSL on your web server. 
    * You are using Encrypted Website Payments. 
    * You use the notify_url variable on each individual payment transaction.
    
Use postbacks for validation if: 
    * You rely on a shared website hosting service 
    * You do not have SSL enabled on your web server 

1. Swap out your button for a `PayPalSharedSecretEncryptedPaymentsForm`:

        # views.py
        from vendor.paypal.standard.forms import PayPalSharedSecretEncryptedPaymentsForm
        
        def view_that_asks_for_money(request):
            ...
            # Create the instance.
            form = PayPalSharedSecretEncryptedPaymentsForm(initial=paypal_dict)
            # Works just like before!
            form.render()
            
1. Verify that your IPN endpoint is running on SSL - `request.is_secure()` should return `True`!


Using PayPal Payments Pro (WPP)
-------------------------------

WPP is the more awesome version of PayPal that lets you accept payments on your 
site. WPP reuses code from `paypal.standard` so you'll need to include both 
apps. [There is an explanation of WPP in the PayPal Forums](http://www.pdncommunity.com/pdn/board/message?board.id=wppro&thread.id=192).


1. Edit `settings.py` and add  `paypal.standard` and `paypal.pro` to your 
   `INSTALLED_APPS`, also set your PayPal settings:

        # settings.py
        ...
        INSTALLED_APPS = (... 'paypal.standard', 'paypal.pro', ...)
        PAYPAL_TEST = True           # Testing mode on
        PAYPAL_WPP_USER = "???"      # Get from vendor.paypal
        PAYPAL_WPP_PASSWORD = "???"
        PAYPAL_WPP_SIGNATURE = "???"

1. Run `python manage.py syncdb` to add the required tables.

1. Write a wrapper view for `paypal.pro.views.PayPalPro`:

        # views.py
        from vendor.paypal.pro.views import PayPalPro

        def buy_my_item(request):
          item = {"amt": "10.00",             # amount to charge for item
                  "inv": "inventory",         # unique tracking variable paypal
                  "custom": "tracking",       # custom tracking variable for you
                  "cancelurl": "http://...",  # Express checkout cancel url
                  "returnurl": "http://..."}  # Express checkout return url
        
          kw = {"item": item,                            # what you're selling
                "payment_template": "payment.html",      # template name for payment
                "confirm_template": "confirmation.html", # template name for confirmation
                "success_url": "/success/"}              # redirect location after success
                
          ppp = PayPalPro(**kw)
          return ppp(request)


1. Create templates for payment and confirmation. By default both templates are 
   populated with the context variable `form` which contains either a 
   `PaymentForm` or a `Confirmation` form.

    <!-- payment.html -->
    <h1>Show me the money</h1>
    <form method="post" action="">
      {{ form }}
      <input type="submit" value="Pay Up">
    </form>
    
    <!-- confirmation.html -->
    <h1>Are you sure you want to buy this thing?</h1>
    <form method="post" action="">
      {{ form }}
      <input type="submit" value="Yes I Yams">
    </form>

1. Add your view to `urls.py`, and add the IPN endpoint to receive callbacks 
   from vendor.paypal:

        # urls.py
        ...
        urlpatterns = ('',
            ...
            (r'^payment-url/$', 'myproject.views.buy_my_item')
            (r'^some/obscure/name/', include('paypal.standard.ipn.urls')),
        )

1. Profit.


Links:
------

1. [Set your IPN Endpoint on the PayPal Sandbox](https://www.sandbox.paypal.com/us/cgi-bin/webscr?cmd=_profile-ipn-notify)

2. [Django PayPal on Google Groups](http://groups.google.com/group/django-paypal)

License (MIT)
=============

Copyright (c) 2009 Handi Mobility Inc.

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.