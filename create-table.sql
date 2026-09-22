-- ==========================================================
-- Retail Store Sales Management - CREATE TABLES SCRIPT
-- Author: Salma Ahmed Khogali
-- Description: Creates schema for the Retail Store project
-- ==========================================================


-- ==========================================================
--  PRODUCTS TABLE
-- ==========================================================
CREATE TABLE products (
    product_id       NUMBER PRIMARY KEY,
    product_name     VARCHAR2(100) NOT NULL,
    category         VARCHAR2(50),
    price            NUMBER(10,2) CHECK (price >= 0),
    sku              VARCHAR2(50) NOT NULL UNIQUE
);

-- ==========================================================
-- STORES TABLE
-- ==========================================================
CREATE TABLE stores (
  store_id NUMBER PRIMARY KEY,
  name VARCHAR2(100) NOT NULL,
  city VARCHAR2(100),
  address VARCHAR2(255)
);

--===============================================================
--  Customers Table
--===========================================================
CREATE TABLE customers (
  customer_id NUMBER PRIMARY KEY,
  name VARCHAR2(150),
  phone VARCHAR2(20),
  loyalty_member CHAR(1) DEFAULT 'N'
);


-- =====================================
--  Sales Table
-- =========================================
CREATE TABLE sales (
  sale_id NUMBER PRIMARY KEY,
  store_id NUMBER REFERENCES stores(store_id),
  customer_id NUMBER REFERENCES customers(customer_id),
  sale_date DATE DEFAULT SYSDATE,
  total_amount NUMBER(12,2)
);

--================================================================
--  Sale Items Table
-- ==============================================
CREATE TABLE sale_items (
  sale_item_id NUMBER PRIMARY KEY,
  sale_id NUMBER REFERENCES sales(sale_id),
  product_id NUMBER REFERENCES products(product_id),
  quantity NUMBER(5),
  unit_price NUMBER(10,2),
  discount NUMBER(5,2)
);

--====================================================================
-- Inventory Table
--====================================================================
CREATE TABLE inventory (
    inventory_id   NUMBER PRIMARY KEY,
    product_id     NUMBER REFERENCES products(product_id),
    store_id       NUMBER REFERENCES stores(store_id),
    quantity_in_stock NUMBER(10)
);
