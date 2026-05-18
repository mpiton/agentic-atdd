Scenario: Submission rejected when cart is empty
  Given an authenticated customer with a valid shipping address
  And an empty cart
  When the customer submits the cart
  Then the submission is rejected with reason "EMPTY_CART"
  And no order is created
