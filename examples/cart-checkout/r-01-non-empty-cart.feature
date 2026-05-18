# Rule: R-01 — Cart must contain at least one item with quantity >= 1.

Feature: Cart non-empty rule for checkout submission

  @nominal @use-case
  Scenario: Submission succeeds with a single item, quantity one
    Given an authenticated customer with a valid shipping address
    And a cart containing 1 item "SKU-100" at 19.99 EUR
    When the customer submits the cart
    Then the submission is accepted
    And an order is created with total 19.99 EUR

  @violation @use-case
  Scenario: Submission rejected when cart is empty
    Given an authenticated customer with a valid shipping address
    And an empty cart
    When the customer submits the cart
    Then the submission is rejected with reason "EMPTY_CART"
    And no order is created

  @limit @use-case
  Scenario Outline: Submission rejected when any line quantity is below 1
    Given an authenticated customer with a valid shipping address
    And a cart containing 1 item "SKU-100" at <unit_price> EUR with quantity <qty>
    When the customer submits the cart
    Then the submission is rejected with reason "INVALID_QUANTITY"

    Examples:
      | unit_price | qty |
      | 19.99      | 0   |
      | 19.99      | -1  |
