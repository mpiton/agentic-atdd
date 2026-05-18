# cart-checkout

## Actor
Authenticated customer

## Goal
Complete a purchase so that the customer receives ordered goods and the store records revenue.

## Action
Submit the cart for payment.

## User story
As an authenticated customer, I want to submit my cart for payment, so that I can complete the purchase and receive the goods.

## Business rules
- R-01: Cart must contain at least one item with quantity >= 1.
- R-02: Total amount must be strictly greater than 0.00 EUR.
- R-03: The customer must have a valid shipping address on file.
- R-04: Items flagged out-of-stock at submission time cause the entire submission to be rejected (no partial orders).
- R-05: Payment authorization is captured synchronously; a declined card rejects the submission and leaves the cart untouched.

## Non-goals
- Multi-currency checkout (EUR only).
- Guest checkout (covered by a different US).
- Gift-card application (separate US).

## Milestone
v2.4.0
