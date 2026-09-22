--===========================================================
-- before-insert trigger to auto-fill product_id
--========================================================
CREATE OR REPLACE TRIGGER bi_products
BEFORE INSERT ON products
FOR EACH ROW
BEGIN
  IF :NEW.product_id IS NULL THEN
    :NEW.product_id := products_seq.NEXTVAL;
  END IF;
END;
/


--===========================================================
-- before-insert trigger to auto-fill store_id
--========================================================
CREATE OR REPLACE TRIGGER trg_store_id
BEFORE INSERT ON stores
FOR EACH ROW
BEGIN
  :NEW.store_id := seq_store.NEXTVAL;
END;
/


--===========================================================
-- before-insert trigger to auto-fill customer_id
--========================================================
CREATE OR REPLACE TRIGGER trg_customer_id
BEFORE INSERT ON customers
FOR EACH ROW
BEGIN
  :NEW.customer_id := seq_customer.NEXTVAL;
END;
/


--===========================================================
-- before-insert trigger to auto-fill sale_id
--========================================================
CREATE OR REPLACE TRIGGER trg_sale_id
BEFORE INSERT ON sales
FOR EACH ROW
BEGIN
  :NEW.sale_id := seq_sale.NEXTVAL;
END;
/


--===========================================================
-- before-insert trigger to auto-fill sale_item_id
--========================================================
CREATE OR REPLACE TRIGGER trg_sale_item_id
BEFORE INSERT ON sale_items
FOR EACH ROW
BEGIN
  :NEW.sale_item_id := seq_sale_item.NEXTVAL;
END;
/


--===========================================================
-- before-insert trigger to auto-fill inventory_id
--========================================================
CREATE OR REPLACE TRIGGER trg_inventory_id
BEFORE INSERT ON inventory
FOR EACH ROW
BEGIN
  :NEW.inventory_id := seq_inventory_id.NEXTVAL;
END;
/


--===========================================================
-- update  inventory
--========================================================


CREATE OR REPLACE TRIGGER trg_update_inventory
AFTER INSERT OR UPDATE OR DELETE ON sale_items
FOR EACH ROW
DECLARE
    v_store_id  NUMBER;
BEGIN
    -- نجيب رقم المتجر المرتبط بالبيع
    SELECT store_id INTO v_store_id
    FROM sales
    WHERE sale_id = :NEW.sale_id;

    -- في حالة الإضافة: ننقص الكمية من المخزون
    IF INSERTING THEN
        UPDATE inventory
        SET quantity_in_stock = quantity_in_stock - :NEW.quantity
        WHERE product_id = :NEW.product_id
        AND store_id = v_store_id;
    
    -- في حالة التعديل: نعوض الفرق
    ELSIF UPDATING THEN
        UPDATE inventory
        SET quantity_in_stock = quantity_in_stock - (:NEW.quantity - :OLD.quantity)
        WHERE product_id = :NEW.product_id
        AND store_id = v_store_id;
    
    -- في حالة الحذف: نرجّع الكمية للمخزون
    ELSIF DELETING THEN
        UPDATE inventory
        SET quantity_in_stock = quantity_in_stock + :OLD.quantity
        WHERE product_id = :OLD.product_id
        AND store_id = v_store_id;
    END IF;
END;
/


--===========================================================
-- check inventory negetive
--========================================================

create or replace trigger tr_check_negitive_stock
before update or insert on inventory
for each row
begin
 if :new.quantity_in_stock<0 then raise_application_error(-20010,'error quentity can not be negitive');
  end if;
  
end;
/













































































-- ==============================================
--  Trigger 1: Calculate line total automatically
-- ==============================================
CREATE OR REPLACE TRIGGER trg_line_total
BEFORE INSERT OR UPDATE ON sale_items
FOR EACH ROW
BEGIN
  :NEW.line_total := (:NEW.quantity * 
                     (SELECT price FROM products WHERE product_id = :NEW.product_id))
                     * (1 - NVL(:NEW.discount, 0)/100);
END;
/
SHOW ERRORS;

-- ==============================================
--  Trigger 2: Update total amount in SALES
-- ==============================================
CREATE OR REPLACE TRIGGER trg_update_sale_total
AFTER INSERT OR UPDATE OR DELETE ON sale_items
FOR EACH ROW
BEGIN
  UPDATE sales s
  SET total_amount = (SELECT NVL(SUM(line_total), 0)
                      FROM sale_items
                      WHERE sale_id = s.sale_id)
  WHERE s.sale_id = NVL(:NEW.sale_id, :OLD.sale_id);
END;
/
SHOW ERRORS;

-- ==============================================
-- Trigger 3: Check inventory before inserting a sale item
-- ==============================================
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
    RAISE_APPLICATION_ERROR(-20001, '❌ Not enough stock for this product');
  END IF;
END;
/
SHOW ERRORS;

-- ==============================================
-- Trigger 4: Prevent negative stock
-- ==============================================
CREATE OR REPLACE TRIGGER trg_no_negative_stock
BEFORE UPDATE ON inventory
FOR EACH ROW
BEGIN
  IF :NEW.quantity_in_stock < 0 THEN
    RAISE_APPLICATION_ERROR(-20002, '❌ Stock cannot be negative');
  END IF;
END;
/
SHOW ERRORS;

-- ==============================================
--  Trigger 5: Auto reduce stock after sale
-- ==============================================
CREATE OR REPLACE TRIGGER trg_reduce_inventory_after_sale
AFTER INSERT ON sale_items
FOR EACH ROW
BEGIN
  UPDATE inventory
  SET quantity_in_stock = quantity_in_stock - :NEW.quantity
  WHERE product_id = :NEW.product_id
  AND store_id = (SELECT store_id FROM sales WHERE sale_id = :NEW.sale_id);
END;
/
SHOW ERRORS;

-- ==============================================
-- ✅ END OF TRIGGERS SCRIPT
-- ==============================================
