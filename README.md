# Household Retail Database

A relational database for a household goods retail business, built in PostgreSQL. It collects, organizes and analyzes data about products, customers, employees, orders and transactions, and supports analytical insights for sales and customer management.

## Business problems solved

- Automatically collects data on customers, employees, products, suppliers, orders and transactions
- Enables analysis of product popularity and customer behavior to identify purchasing patterns
- Supports product categorization and monitoring of category popularity and size
- Tracks order processing and delivery time to identify problems and improve efficiency
- Enforces business rules automatically (quantity > 0, total price > 0, delivery time > order time, one completed transaction per order)
- Supports decision-making on stock management and promotions
- Ensures data consistency and prevents duplicate entries

## Data model

Tables: `Customers`, `Employees`, `Categories`, `Suppliers`, `Products`, `Orders`, `Order_Product`, `Transactions`

- **Orders** is the main entity. `totalPrice` is calculated automatically by a row-level trigger on `Order_Product`, which sums product price × quantity. `employeeID` is set only for offline orders.
- **Order_Product** implements the many-to-many relationship between Orders and Products (composite primary key, `quantity > 0`).
- **Customers / Employees** store contact data. Email and phone are `UNIQUE`; customers must have signed up after the start of 2024; employee position is `manager` or `assistant`. Both are one-to-many with Orders.
- **Products** store category, supplier, model, brand, price, stock status and quantity. Foreign keys to `Categories` and `Suppliers` enforce referential integrity; price must be positive and quantity non-negative.
- **Categories** group products for reporting on distribution and popularity.
- **Transactions** record payments (`amount > 0`, method: cash / card / transfer, status: completed / failed). Multiple failed transactions per order are allowed, but only one successful one.

The model follows 3NF. Conceptual and logical diagrams are in the PDF documentation.

## Functions, view and roles

- `update_product()`: controlled updates of product data, prevents modification of the primary key
- `add_transaction()`: registers a payment for an order and enforces the transaction rules
- View `latest_quarter`: for the most recent quarter, shows total non-canceled orders and units sold per product to identify the most popular products
- Role `manager`: login with read-only access to the `household` schema

## How to run

For the fisrt time, run the SQL script from the second row in `psql`, DBeaver or pgAdmin.

## Possible improvements

- Trigger for automatic calculation of available products based on orders
- Many-to-many table between products and suppliers (e.g. availability based on supply)
- Trigger that sets the order status to "delivered" when delivery time is NOT NULL
- Delivery logic and tables
- Discount, cancellation and return logic

## Tech

PostgreSQL · PL/pgSQL · draw.io
