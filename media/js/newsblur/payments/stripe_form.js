$(function() {
    if ($('.NB-stripe-form').length) {
        // $("#id_card_number").parents("form").submit(function() {
        //     if ( $("#id_card_number").is(":visible")) {
        //         var form = this;
        //         var card = {
        //             number:   $("#id_card_number").val(),
        //             expMonth: $("#id_card_expiry_month").val(),
        //             expYear:  $("#id_card_expiry_year").val(),
        //             cvc:      $("#id_card_cvv").val()
        //         };
        // 
        //         Stripe.createToken(card, function(status, response) {
        //             if (status === 200) {
        //                 $("#credit-card-errors").hide();
        //                 $("#id_last_4_digits").val(response.card.last4);
        //                 $("#id_stripe_token").val(response.id);
        //                 form.submit();
        //                 $("button[type=submit]").attr("disabled","disabled").html("Submitting..");
        //             } else {
        //                 $(".payment-errors").text(response.error.message);
        //                 $("#user_submit").attr("disabled", false);
        //             }
        //         });
        //         return false;
        //     } 
        // 
        //     return true;
        // });
        
        function addInputNames() {
            // Not ideal, but jQuery's validate plugin requires fields to have names
            // so we add them at the last possible minute, in case any javascript 
            // exceptions have caused other parts of the script to fail.
            $(".card-number").attr("name", "card-number");
            $(".card-cvv").attr("name", "card-cvc");
            $(".card-expiry-year").attr("name", "card-expiry-year");
        }

        function removeInputNames() {
            $(".card-number").removeAttr("name");
            $(".card-cvv").removeAttr("name");
            $(".card-expiry-year").removeAttr("name");
        }

        function submit(form) {
            // remove the input field names for security
            // we do this *before* anything else which might throw an exception
            removeInputNames(); // THIS IS IMPORTANT!

            // given a valid form, submit the payment details to stripe
            $("button[type=submit]").attr("disabled", "disabled");
            $("button[type=submit]").addClass("NB-disabled");
            $("button[type=submit]").removeClass("NB-modal-submit-green");
            $("button[type=submit]").text("Submitting...");
            
            Stripe.createToken({
                number: $('.card-number').val(),
                cvc: $('.card-cvv').val(),
                exp_month: $('.card-expiry-month').val(), 
                exp_year: $('.card-expiry-year').val()
            }, function(status, response) {
                if (response.error) {
                    // re-enable the submit button
                    $("button[type=submit]").removeAttr("disabled");
                    $("button[type=submit]").removeClass("NB-disabled");
                    $("button[type=submit]").addClass("NB-modal-submit-green");
                    $("button[type=submit]").text("Submit Payment");

                    // show the error
                    $(".payment-errors").html(response.error.message);

                    // we add these names back in so we can revalidate properly
                    addInputNames();
                } else {
                    $("#id_last_4_digits").val(response.card.last4);
                    $("#id_stripe_token").val(response.id);

                    form.submit();
                }
            });

            return false;
        }

        // add custom rules for credit card validating
        jQuery.validator.addMethod("cardNumber", Stripe.validateCardNumber, "Please enter a valid card number");
        jQuery.validator.addMethod("cardCVC", Stripe.validateCVC, "Please enter a valid security code");
        jQuery.validator.addMethod("cardExpiry", function() {
            return Stripe.validateExpiry($(".card-expiry-month").val(), 
                                         $(".card-expiry-year").val());
        }, "Please enter a valid expiration");

        // We use the jQuery validate plugin to validate required params on submit
        $("#id_card_number").parents("form").validate({
            submitHandler: submit,
            rules: {
                "card-cvc" : {
                    cardCVC: true,
                    required: true
                },
                "card-number" : {
                    cardNumber: true,
                    required: true
                },
                "card-expiry-year" : "cardExpiry", // we don't validate month separately
                "email": {
                    required: true,
                    email: true
                }
            }
        });

        // adding the input field names is the last step, in case an earlier step errors                
        addInputNames();
    }
    
    
    var $payextra = $("input[name=payextra]");
    var $label2 = $("label[for=id_plan_1]");
    var $label3 = $("label[for=id_plan_2]");
    var $radio2 = $("input#id_plan_1");
    var $radio3 = $("input#id_plan_2");
    var change_payextra = function() {
        if ($payextra.is(':checked')) {
            $label2.hide();
            $label3.show();
            // $radio2.attr('checked', false);
            $radio3.prop('checked', true);
        } else {
            $label2.show();
            $label3.hide();
            // $radio3.attr('checked', false);
            $radio2.prop('checked', true);
        }
    };
    $("input[name=payextra]").on('change', change_payextra);
    if ($radio3.is(':checked')) {
        $payextra.attr('checked', 'checked').change();
    } else {
        $payextra.change();
    }

});
