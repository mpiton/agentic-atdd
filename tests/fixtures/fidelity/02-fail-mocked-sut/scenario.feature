Scenario: Declined card rejects submission and preserves the cart
  Given an authenticated customer with a valid shipping address
  And a cart containing 2 items totalling 39.98 EUR
  And the customer's card "VISA-DECLINED" is declined by the issuer
  When the customer submits the cart
  Then the submission is rejected with reason "PAYMENT_DECLINED"
  And no order is created
  And the cart still contains the same 2 items totalling 39.98 EUR
