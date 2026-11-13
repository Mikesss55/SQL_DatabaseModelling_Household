 	DROP DATABASE DB_Household;
	CREATE DATABASE DB_Household;
	DROP SCHEMA IF EXISTS household CASCADE;
	CREATE SCHEMA IF NOT EXISTS household;
	
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	-- Creating tables:
	
	-- Customers table:
	CREATE TABLE IF NOT EXISTS household.customers (
		customerID INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,     
		name VARCHAR(50) NOT NULL,	--name and surname have to be specified
		surname VARCHAR(50) NOT NULL,
		email VARCHAR(254) UNIQUE NOT NULL,  --email has to be UNIQUE
			CONSTRAINT customer_email_format CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),  -- checking email format
	    phone VARCHAR(20) UNIQUE NOT NULL, --phone has to be UNIQUE
	    	CONSTRAINT customer_phone_format CHECK (phone ~ '^\+370\d{8}$'),	-- checking phone format
	    address VARCHAR(254), 
	    signUpDate DATE NOT NULL DEFAULT CURRENT_DATE CHECK (signUpDate > DATE '2024-01-01')  -- checking date according to the task description
	);
	
	
	-- Employees table:
	CREATE TABLE IF NOT EXISTS household.employees (
		employeeID INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,     
		name VARCHAR(50) NOT NULL, 
		surname VARCHAR(50) NOT NULL,
		email VARCHAR(254) UNIQUE NOT NULL,
			CONSTRAINT employee_email_format CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'), 
	    phone VARCHAR(20) UNIQUE NOT NULL, 
	    	CONSTRAINT employee_phone_format CHECK (phone ~ '^\+370\d{8}$'),
	    address VARCHAR(254) NOT NULL, 
	    birthDate DATE NOT NULL CHECK (birthDate > DATE '1925-01-01'),
	    position VARCHAR(20) NOT NULL CHECK (position IN ('manager', 'assistant'))  -- inserted value that can only be a specific value
	);
	
	
	-- Categories table:
	CREATE TABLE IF NOT EXISTS household.categories (
		categoryID INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,     
		name VARCHAR(50) NOT NULL,
		description VARCHAR(200)
	);
	
	
	-- Suppliers table:
	CREATE TABLE IF NOT EXISTS household.suppliers (
		supplierID INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, 
		name VARCHAR(50) NOT NULL,
		address VARCHAR(254),
		email VARCHAR(254) UNIQUE NOT NULL,
			CONSTRAINT supplier_email_format CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'), 
	    phone VARCHAR(20) UNIQUE NOT NULL,
			CONSTRAINT supplier_phone_format CHECK (phone ~ '^\+370\d{8}$'),
		description VARCHAR(200)
	);
	
	
	-- Products table:
	CREATE TABLE IF NOT EXISTS household.products (
		productID INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, 
		categoryID INT NOT NULL REFERENCES household.categories(categoryID),
		supplierID INT NOT NULL REFERENCES household.suppliers(supplierID),
		model VARCHAR(50) NOT NULL,
		brand VARCHAR(50) NOT NULL,
		price NUMERIC(8,2) NOT NULL,
			CONSTRAINT price_more_than_zero CHECK (price > 0), 	-- inserted measured value that cannot be negative
		description VARCHAR(200),
		inStock BOOLEAN NOT NULL,
		quantity INT NOT NULL,
			CONSTRAINT quantity_not_negative CHECK (quantity >= 0)
	);
	
	
	-- Orders table:
	CREATE TABLE IF NOT EXISTS household.orders (
		orderID INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, 
		customerID INT NOT NULL REFERENCES household.customers(customerID),
		employeeID INT REFERENCES household.employees(employeeID),
		orderTime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, 
		deliveryTime TIMESTAMP DEFAULT NULL, 
			CONSTRAINT deliveryTime_larger_orderTime CHECK (deliveryTime IS NULL OR (deliveryTime  > orderTime)),
		totalPrice NUMERIC(8, 2) NOT NULL DEFAULT 0,
			CONSTRAINT totalPrice_more_than_zero CHECK (totalPrice >= 0),
		status VARCHAR(20) NOT NULL,
			CONSTRAINT status_type CHECK (status IN ('new','paid','delivering','completed','canceled'))
	);
	
	
	-- Order_product table for many-to-many relationship:
	CREATE TABLE IF NOT EXISTS household.order_product(
		orderID INT NOT NULL REFERENCES household.orders(orderID),
		productID INT NOT NULL REFERENCES household.products(productID),
		quantity INT NOT NULL,
			CONSTRAINT quantity_larger_zero CHECK (quantity > 0),
		PRIMARY KEY (orderID, productID)	-- composite primary key
	);
	
	-- trigger function for calculating total price in orders table:
	CREATE OR REPLACE FUNCTION household.update_order_total_row()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $$
	BEGIN
		UPDATE household.orders o
		SET totalPrice = COALESCE((
			SELECT SUM(op.quantity * p.price)
			FROM household.order_product op
			INNER JOIN household.products p ON op.productID = p.productID
			WHERE op.orderID = COALESCE(NEW.orderID, OLD.orderID)
		), 0)
		WHERE o.orderID = COALESCE(NEW.orderID, OLD.orderID);
	
		RETURN NULL;
	END;
	$$;
	
	DROP TRIGGER IF EXISTS trg_update_order_total_row ON household.order_product;
	CREATE TRIGGER trg_update_order_total_row
	AFTER INSERT OR UPDATE OR DELETE ON household.order_product
	FOR EACH ROW
	EXECUTE FUNCTION household.update_order_total_row();
	
	
	
	-- Transaction table:
	CREATE TABLE IF NOT EXISTS household.transactions (
		transactionID INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, 
		orderID INT NOT NULL REFERENCES household.orders(orderID),
		amount NUMERIC(8,2) NOT NULL CHECK (amount > 0),
		paymentTime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
		paymentMethod VARCHAR(20) NOT NULL CHECK (paymentMethod IN ('cash','card','transfer')),
		status VARCHAR(20) NOT NULL CHECK (status IN ('completed','failed'))
	);

	CREATE UNIQUE INDEX IF NOT EXISTS uq_one_completed_tx
	ON household.transactions(orderID)
	WHERE status = 'completed';
	
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	--Inserts:
	
	-- Categories table:
	INSERT INTO household.categories (
		name, 
		description)
	SELECT v.name, v.description
	FROM (VALUES
		('Kitchen', 'Appliances and utensils for kitchen use'),
		('Bathroom', 'Stuff for bathroom'),
		('Cleaning', 'Home cleaning supplies'),
		('Living Room', 'Furniture and decorations for living room'),
		('Bedroom', 'Beds, wardrobes and bedroom furniture'),
	    ('Garden', 'Outdoor and garden equipment')
	) AS v(name, description)
	
	WHERE NOT EXISTS (
		SELECT 1 
		FROM household.categories cat
		WHERE UPPER(cat.name) = UPPER(v.name)
	);
	
	-- Suppliers table:
	INSERT INTO household.suppliers (
		name, 
		address, 
		email, 
		phone, 
		description)
	SELECT v.name, v.address, v.email, v.phone, v.description
	FROM (VALUES
		('NordHome Supplies', 'Kaunas, Lithuania', 'sales@nordhome.example.com', '+37061234567', 'General household supplier'),
		('CleanIt Ltd', 'Vilnius, Lithuania', 'info@cleanit.example.com', '+37061234568', 'Cleaning chemicals and tools'),
		('ComfortBeds', 'Vilnius, Lithuania', 'contact@comfortbeds.example.com', '+37061234569', 'Bedding and mattresses'),
		('HomeDeco Ltd', 'Vilnius, Lithuania', 'contact@homedeco.com', '+37061234570', 'Furniture and home decor'),
		('KitchenPro', 'Kaunas, Lithuania', 'sales@kitchenpro.com', '+37061234571', 'Kitchen appliances and utensils'),
		('GardenSupplies', 'Kaunas, Lithuania', 'info@gardensupplies.com', '+37061234572', 'Garden tools and outdoor equipment')
	) AS v(name, address, email, phone, description)
	
	WHERE NOT EXISTS (
		SELECT 1
		FROM household.suppliers sup
		WHERE UPPER(sup.name) = UPPER(v.name)
			OR UPPER(sup.email) = UPPER(v.email)
	);
	
	
	---- Products table:
	INSERT INTO household.products (
		categoryID, 
		supplierID, 
		model, 
		brand, 
		price, 
		description,
		inStock, 
		quantity)
	SELECT 
		(SELECT categoryID FROM household.categories cat WHERE UPPER(cat.name) = UPPER(v.category_name)),
		(SELECT supplierID FROM household.suppliers sup WHERE UPPER(sup.name) = UPPER(v.supplier_name)),
		v.model, v.brand, v.price, v.description, v.inStock, v.quantity
	FROM (VALUES
		('Kitchen', 'NordHome Supplies', '2 pro', 'Tefal', 29.99, 'Stainless steel cooking pot, 3 liters', TRUE, 120),
		('Cleaning', 'CleanIt Ltd', 'Sparkle Spray 750ml', 'CleanIt', 4.50, 'All-purpose cleaner, 750ml', TRUE, 100),
		('Bathroom', 'NordHome Supplies', '100 X2 wood', 'JYSK', 9.99, 'Compact organizer for a bathroom', TRUE, 40),
		('Living Room', 'HomeDeco Ltd', 'Comfy Sofa', 'DecoBrand', 399.99, '3-seater fabric sofa', TRUE, 10),
		('Bedroom', 'HomeDeco Ltd', 'SleepWell Bed', 'DecoBrand', 249.50, 'Queen size bed frame', TRUE, 15),
		('Garden', 'GardenSupplies', 'Garden Shovel', 'GardenPro', 19.99, 'Durable steel shovel', TRUE, 50)
	) AS v(category_name, supplier_name, model, brand, price, description, inStock, quantity)
	
	WHERE NOT EXISTS (
		SELECT 1
		FROM household.products pr
		WHERE UPPER(pr.model) = UPPER(v.model)
			AND UPPER(pr.brand) = UPPER(v.brand)
	);
	
	
	-- Customers table:
	INSERT INTO household.customers (
		name, 
		surname,
		email, 
		phone,
		address, 
		signUpDate)
	SELECT v.name, v.surname, v.email, v.phone, v.address, v.signUpDate
	FROM (VALUES
		('Andrew', 'Johnson', 'andrew.johnson@gmail.com', '+37061234600', NULL, CURRENT_DATE - INTERVAL '10 days'),
		('Alice', 'Davis', 'alice.davis@gmail.com', '+37061234603', NULL, CURRENT_DATE - INTERVAL '55 days'),
		('Victoria', 'Wilson', 'victoria.wilson@gmail.com', '+37061234605', 'A. Vivulskio St 7, Vilnius', CURRENT_DATE - INTERVAL '85 days'),
		('Robert', 'Miller', 'robert.miller@gmail.com', '+37061234606', NULL, CURRENT_DATE - INTERVAL '30 days'),
		('Sophie', 'Taylor', 'sophie.taylor@gmail.com', '+37061234607', 'Laisves Ave 12, Kaunas', CURRENT_DATE - INTERVAL '45 days'),
		('Daniel', 'Anderson', 'daniel.anderson@gmail.com', '+37061234608', NULL, CURRENT_DATE - INTERVAL '60 days')
	) AS v(name, surname, email, phone, address, signUpDate)
	
	WHERE NOT EXISTS (
		SELECT 1
		FROM household.customers c
	    WHERE UPPER(c.email) = UPPER(v.email)
			OR UPPER(c.phone) = UPPER(v.phone)
	);
	
	
	-- Employees table
	INSERT INTO household.employees (
		name, 
		surname, 
		email,
		phone, 
		address, 
		birthDate,
		position)
	SELECT v.name, v.surname, v.email, v.phone, v.address, v.birthDate, v.position
	FROM (VALUES
		('John', 'Smith', 'john.smith@gmail.com', '+37061234700', 'Gedimino Ave 12, Vilnius', DATE '1985-03-15', 'assistant'),
		('Emily', 'Brown', 'emily.brown@gmail.com', '+37061234701', 'Laisves Ave 5, Vilnius', DATE '1990-07-22', 'assistant'),
		('Michael', 'Johnson', 'michael.johnson@gmail.com', '+37061234702', 'Savanoriu Ave 30, Vilnius', DATE '1978-11-09', 'manager'),
		('Laura', 'Green', 'laura.green@gmail.com', '+37061234703', 'Pilies St 10, Vilnius', DATE '1988-02-17', 'assistant'),
		('James', 'White', 'james.white@gmail.com', '+37061234704', 'Gedimino Ave 22, Vilnius', DATE '1995-06-05', 'assistant'),
		('Emma', 'Black', 'emma.black@gmail.com', '+37061234705', 'Laisves Ave 8, Kaunas', DATE '1992-09-14', 'assistant')
	) AS v(name, surname, email, phone, address, birthDate, position)
	
	WHERE NOT EXISTS (
		SELECT 1
		FROM household.employees em
	    WHERE UPPER(em.email) = UPPER(v.email)
			OR UPPER(em.phone) = UPPER(v.phone)
	);
	
	
	-- Orders table:
	INSERT INTO household.orders (customerID, employeeID, deliveryTime, status)
	SELECT
	    c.customerID,
	    e.employeeID,
	    v.deliveryTime,
	    v.status
	FROM (VALUES
	    ('andrew.johnson@gmail.com',  'emily.brown@gmail.com',   NULL, 'new'),
	    ('alice.davis@gmail.com',     NULL,  NULL, 'new'),
	    ('victoria.wilson@gmail.com',NULL, CURRENT_TIMESTAMP + INTERVAL '2 days',  'delivering'),
	    ('robert.miller@gmail.com',   'john.smith@gmail.com',CURRENT_TIMESTAMP + INTERVAL '1 day',   'delivering'),
	    ('sophie.taylor@gmail.com',   NULL,   NULL,  'new'),
	    ('daniel.anderson@gmail.com','emma.black@gmail.com',CURRENT_TIMESTAMP + INTERVAL '3 days',  'delivering')
	) AS v(customerEmail, employeeEmail, deliveryTime, status)
	INNER JOIN household.customers c ON upper(c.email) = upper(v.customerEmail)
	LEFT JOIN household.employees e ON upper(e.email) = upper(v.employeeEmail)
	
	WHERE NOT EXISTS (
		SELECT 1
		FROM household.orders o
		WHERE o.customerID = c.customerID
			AND o.employeeID IS NOT DISTINCT FROM e.employeeID
			AND o.deliveryTime::date IS NOT DISTINCT FROM v.deliveryTime::date
			AND o.status = v.status
	);
	
	
	--Order_product table:
	INSERT INTO household.order_product (orderID, productID, quantity)
	SELECT
		o.orderID,
		p.productID,
		v.quantity
	FROM household.orders o
	INNER JOIN household.customers c ON c.customerID = o.customerID
	JOIN (VALUES
		('andrew.johnson@gmail.com',  '2 pro',               'Tefal',      2),
		('andrew.johnson@gmail.com',  'Sparkle Spray 750ml', 'CleanIt',    1),
		('alice.davis@gmail.com',     '100 X2 wood',         'JYSK',       1),
		('alice.davis@gmail.com',     'Sparkle Spray 750ml', 'CleanIt',    3),
		('victoria.wilson@gmail.com', '2 pro',               'Tefal',      1),
		('victoria.wilson@gmail.com', '100 X2 wood',         'JYSK',       2),
		('robert.miller@gmail.com',   '2 pro',               'Tefal',      1),
		('robert.miller@gmail.com',   'Sparkle Spray 750ml', 'CleanIt',    2),
		('sophie.taylor@gmail.com',   '100 X2 wood',         'JYSK',       1),
		('sophie.taylor@gmail.com',   'Garden Shovel',       'GardenPro',  1),
		('daniel.anderson@gmail.com', '2 pro',               'Tefal',      2),
		('daniel.anderson@gmail.com', 'SleepWell Bed',       'DecoBrand',  1)
	) AS v(customerEmail, model, brand, quantity) 
		ON c.email = v.customerEmail
	JOIN household.products p ON upper(p.model) = upper(v.model) 
		AND upper(p.brand) = upper(v.brand)
	
	WHERE NOT EXISTS (
		SELECT 1
		FROM household.order_product op
		WHERE op.orderID = o.orderID
			AND op.productID = p.productID
	);
	
	
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	-- Functions:
	
	--Function for updating products table:
	CREATE OR REPLACE FUNCTION household.update_product(
		p_product_id INT,
		p_column_name TEXT,
		p_new_value TEXT
	)
	RETURNS VOID
	LANGUAGE plpgsql
	AS $$
	BEGIN
		IF NOT EXISTS (
			SELECT 1
			FROM information_schema.columns
			WHERE table_schema = 'household'
				AND table_name = 'products'
				AND column_name = p_column_name
		) THEN
			RAISE EXCEPTION 'Column "%" does not exist in household.products', p_column_name;
		END IF;
		
		IF p_column_name = 'productID' THEN
			RAISE EXCEPTION 'You cannot update primary key';
		END IF;
	
		UPDATE household.products pr
		SET
			model = CASE WHEN p_column_name = 'model' THEN p_new_value ELSE model END,
			brand = CASE WHEN p_column_name = 'brand' THEN p_new_value ELSE brand END,
			price = CASE WHEN p_column_name = 'price' THEN p_new_value::NUMERIC ELSE price END,
			description = CASE WHEN p_column_name = 'description' THEN p_new_value ELSE description END,
			inStock = CASE WHEN p_column_name = 'inStock' THEN p_new_value::BOOLEAN ELSE inStock END,
			quantity = CASE WHEN p_column_name = 'quantity' THEN p_new_value::INT ELSE quantity END  --case statemnts for every column in products table
		WHERE pr.productID = p_product_id;
	
		IF NOT FOUND THEN
			RAISE EXCEPTION 'No product with ID %', p_product_id;
		END IF;
	END;
	$$;
	
	SELECT household.update_product(2, 'description', 'Nice description');
	
	SELECT *
	FROM household.products;
	
	
	--Function for inserting transactions:
	CREATE OR REPLACE FUNCTION household.add_transaction(
		p_customer_email TEXT,
		p_payment_method TEXT,
		p_status TEXT)
	RETURNS TEXT
	LANGUAGE plpgsql
	AS $$
	DECLARE 
		v_customer_id INT;
		v_order_id INT;
		v_amount NUMERIC;
	BEGIN
		IF upper(p_status) NOT IN ('COMPLETED','FAILED') THEN
			RETURN 'Incorrect transaction status';
		END IF;
		
		IF upper(p_payment_method) NOT IN ('CASH','CARD','TRANSFER') THEN
			RETURN 'Incorrect payment method';
		END IF;
			
		SELECT customerId INTO v_customer_id
		FROM household.customers cus
		WHERE upper(cus.email) = upper(p_customer_email); --avoiding hardcoding by using email
		
		IF v_customer_id IS NULL THEN
			RAISE EXCEPTION 'Customer with email "%" not found' , p_customer_email ;
		END IF;
		
		SELECT orderId, totalPrice
		INTO v_order_id, v_amount --using totalPrice generated in orders table
		FROM household.orders
		WHERE customerId = v_customer_id
			AND status = 'new'
		ORDER BY orderTime ASC
		FETCH FIRST 1 ROW ONLY;  -- if the user has multiple unpaid orders, the transaction for the earliest one is generated.
		
		IF v_order_id IS NULL THEN
			RETURN 'No orders to pay for';
		END IF;
	
		IF p_status = 'completed' AND EXISTS (  --dublicate check for completed transactions
			SELECT 1
			FROM household.transactions
			WHERE orderId = v_order_id
			AND status = 'completed')
		THEN
			RETURN 'Order already has a completed transaction';
		END IF;
		
		INSERT INTO household.transactions(orderId, amount, paymentTime, paymentMethod, status)
		VALUES (v_order_id, v_amount, NOW(), p_payment_method, p_status);
		
		UPDATE household.orders
		SET status = 'paid'
		WHERE orderID = v_order_id 
			AND p_status = 'completed';   --ensuring that column status in orders table updates only if a transacrion is completed
		
	    RETURN 'Transaction successfully added';   --returning text
	END;
	$$;
	
	
	
	SELECT household.add_transaction(
		'sophie.taylor@gmail.com',
		'transfer',
		'completed'
	);
	
	SELECT * FROM household.transactions t ;
	
	
	SELECT * 
	FROM household.orders o
	INNER JOIN household.customers cus ON cus.customerID = o.customerID;
	
	
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	-- View:
	 CREATE OR REPLACE VIEW household.latest_quarter AS      
	 
	 WITH latest_quarter AS (      --CTE for current year and quarter
		SELECT
			EXTRACT(YEAR FROM orderTime) AS year,
			EXTRACT(QUARTER FROM orderTime) AS quarter
		FROM household.orders
		ORDER BY orderTime DESC
		FETCH FIRST 1 ROW ONLY
	),
	orders_in_quarter AS (    --CTE with all orders in current quarter which have not been canceled
		SELECT o.orderID
		FROM household.orders o
		JOIN latest_quarter lq
			ON EXTRACT(YEAR FROM o.orderTime) = lq.year
			AND EXTRACT(QUARTER FROM o.orderTime) = lq.quarter
			AND UPPER(o.status) <> 'CANCELED'
	),
	popular AS (   --CTE for finding most popular products 
		SELECT 
			p.model || ' (' || p.brand || ')' AS product_name,
			SUM(op.quantity) AS total_sold
		FROM orders_in_quarter oq
		INNER JOIN household.order_product op ON oq.orderID = op.orderID
		INNER JOIN household.products p ON p.productID = op.productID
		GROUP BY product_name
		ORDER BY total_sold DESC
	)
	
	
	SELECT 
		COALESCE((SELECT COUNT(*) FROM orders_in_quarter), 0) AS total_orders_in_quarter,
		product_name AS most_popular_products,
		total_sold AS product_units_sold
	FROM popular;
	
	SELECT *
	FROM household.latest_quarter;
		
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		
	--DCL:
	DROP ROLE IF EXISTS manager;
	CREATE ROLE manager
	WITH LOGIN
	PASSWORD 'managerpass';  
	
	GRANT USAGE ON SCHEMA household TO manager;
	GRANT SELECT ON ALL TABLES IN SCHEMA household TO manager;
	
	SET ROLE manager;
	
	SELECT *
	FROM household.orders;
	
	SET ROLE postgres;

	REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA household FROM manager;
	REVOKE USAGE ON SCHEMA household FROM manager;
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




