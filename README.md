# 🛍️ Retail Store Sales Management – Oracle SQL Project

## 📋 Project Overview
This project simulates a **retail store system** using Oracle SQL.  
It manages sales, products, stores, customers, and inventory — providing insights such as sales trends, slow-moving products, and RFM analysis.

The project was designed **from scratch**, including all schema creation, triggers, and analytical views.

---

## 🧱 Database Schema

### 1️⃣ **PRODUCTS**
| Column | Type | Description |
|--------|------|-------------|
| PRODUCT_ID | NUMBER | Primary key |
| PRODUCT_NAME | VARCHAR2(100) | Product name |
| CATEGORY | VARCHAR2(50) | Product category |
| PRICE | NUMBER | Unit price |
| SKU | VARCHAR2(50) NOT NULL | Stock Keeping Unit |

### 2️⃣ **STORES**
| Column | Type | Description |
|--------|------|-------------|
| STORE_ID | NUMBER | Primary key |
| STORE_NAME | VARCHAR2(100) | Store name |
| LOCATION | VARCHAR2(100) | Store location |

### 3️⃣ **CUSTOMERS**
| Column | Type | Description |
|--------|------|-------------|
| CUSTOMER_ID | NUMBER | Primary key |
| CUSTOMER_NAME | VARCHAR2(100) | Customer full name |
| PHONE | VARCHAR2(20) | Contact number |

### 4️⃣ **SALES**
| Column | Type | Description |
|--------|------|-------------|
| SALE_ID | NUMBER | Primary key |
| STORE_ID | NUMBER | Foreign key to STORES |
| CUSTOMER_ID | NUMBER | Foreign key to CUSTOMERS |
| SALE_DATE | DATE | Date of the sale |
| TOTAL_AMOUNT | NUMBER | Total sale amount (auto-updated by trigger) |

### 5️⃣ **SALE_ITEMS**
| Column | Type | Description |
|--------|------|-------------|
| SALE_ITEM_ID | NUMBER | Primary key |
| SALE_ID | NUMBER | Foreign key to SALES |
| PRODUCT_ID | NUMBER | Foreign key to PRODUCTS |
| QUANTITY | NUMBER | Quantity sold |
| DISCOUNT | NUMBER | Discount percentage |
| LINE_TOTAL | NUMBER | Total per line (auto-calculated by trigger) |

### 6️⃣ **INVENTORY**
| Column | Type | Description |
|--------|------|-------------|
| INVENTORY_ID | NUMBER | Primary key |
| PRODUCT_ID | NUMBER | Foreign key to PRODUCTS |
| STORE_ID | NUMBER | Foreign key to STORES |
| QUANTITY_IN_STOCK | NUMBER | Available stock |

---

## ⚙️ Key Features and Logic

### 🔸 Sequences
```sql
CREATE SEQUENCE seq_product_id START WITH 1;
CREATE SEQUENCE seq_sale_id START WITH 1;
CREATE SEQUENCE seq_sale_item_id START WITH 1;
```

### 🔸 Triggers

#### 1️⃣ Calculate Line Total Automatically
```sql
CREATE OR REPLACE TRIGGER trg_line_total
BEFORE INSERT OR UPDATE ON sale_items
FOR EACH ROW
BEGIN
  :NEW.line_total := (:NEW.quantity * 
                      (SELECT price FROM products WHERE product_id = :NEW.product_id))
                      * (1 - NVL(:NEW.discount, 0)/100);
END;
```

#### 2️⃣ Update Sale Total Automatically
```sql
CREATE OR REPLACE TRIGGER trg_update_sale_total
AFTER INSERT OR UPDATE OR DELETE ON sale_items
FOR EACH ROW
BEGIN
  UPDATE sales s
  SET total_amount = (SELECT SUM(line_total)
                      FROM sale_items
                      WHERE sale_id = s.sale_id)
  WHERE s.sale_id = :NEW.sale_id;
END;
```

#### 3️⃣ Prevent Sale if Not Enough Stock
```sql
CREATE OR REPLACE TRIGGER trg_check_inventory
BEFORE INSERT ON sale_items
FOR EACH ROW
DECLARE
  v_stock NUMBER;
BEGIN
  SELECT quantity_in_stock INTO v_stock
  FROM inventory
  WHERE product_id = :NEW.product_id
  AND store_id = (SELECT store_id FROM sales WHERE sale_id = :NEW.sale_id);

  IF v_stock < :NEW.quantity THEN
    RAISE_APPLICATION_ERROR(-20001, 'Not Enough Stock for this Product');
  END IF;
END;
```

#### 4️⃣ Prevent Negative Stock
```sql
CREATE OR REPLACE TRIGGER trg_no_negative_stock
BEFORE UPDATE ON inventory
FOR EACH ROW
BEGIN
  IF :NEW.quantity_in_stock < 0 THEN
    RAISE_APPLICATION_ERROR(-20002, 'Stock cannot be negative');
  END IF;
END;
```

---

## 📊 Analytical Views

### 🔹 1. Materialized View for Inventory
```sql
CREATE MATERIALIZED VIEW mv_inventory_summary AS
SELECT i.store_id, s.store_name,
       i.product_id, p.product_name,
       i.quantity_in_stock
FROM inventory i
JOIN stores s ON i.store_id = s.store_id
JOIN products p ON i.product_id = p.product_id;
```

### 🔹 2. Slow-Moving Products
```sql
CREATE MATERIALIZED VIEW mv_slow_moving AS
SELECT p.product_id, p.product_name,
       SUM(si.quantity) total_sold
FROM sale_items si
JOIN products p ON si.product_id = p.product_id
GROUP BY p.product_id, p.product_name
HAVING SUM(si.quantity) < 5;
```

### 🔹 3. Sales Trend Over Time
```sql
CREATE VIEW v_sales_trend AS
SELECT TO_CHAR(s.sale_date, 'YYYY-MM') AS sale_month,
       SUM(s.total_amount) AS monthly_sales
FROM sales s
GROUP BY TO_CHAR(s.sale_date, 'YYYY-MM')
ORDER BY sale_month;
```

---

## 📈 Future Enhancements
- RFM analysis by **customer** or **product**  
- Add more detailed **supplier** and **purchase order** tables  
- Create **dashboards** using Power BI or Oracle APEX  

---

## 🧑‍💻 Author
**Salma Ahmed Khogali**  
📍 Riyadh, Saudi Arabia  
📧 [saloomkhogali10@gmail.com](mailto:saloomkhogali10@gmail.com)  
💼 Bachelor’s in IT – University of Khartoum  
🧠 Data Science Certified – Datamites Institute  
