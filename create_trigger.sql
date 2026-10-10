-- =====================================================================
-- Retail Store Sales Management - TRIGGERS
-- Run after create-table.sql and create-sequences.sql.
-- Safe to re-run: every trigger uses CREATE OR REPLACE.
-- =====================================================================


-- =====================================================================
-- 0) Remove duplicate triggers from the earlier version of this script
--    - trg_reduce_inventory_after_sale deducted stock a second time
--      (trg_update_inventory already handles it)
--    - tr_check_negitive_stock duplicated trg_no_negative_stock
-- =====================================================================
BEGIN
  FOR t IN (SELECT trigger_name
              FROM user_triggers
             WHERE trigger_name IN ('TRG_REDUCE_INVENTORY_AFTER_SALE',
                                    'TR_CHECK_NEGITIVE_STOCK'))
  LOOP
    EXECUTE IMMEDIATE 'DROP TRIGGER ' || t.trigger_name;
  END LOOP;
END;
/


-- =====================================================================
-- 1) Auto-fill primary keys from sequences
-- =====================================================================
CREATE OR REPLACE TRIGGER bi_products
BEFORE INSERT ON products
FOR EACH ROW
BEGIN
  IF :NEW.product_id IS NULL THEN
    :NEW.product_id := products_seq.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_store_id
BEFORE INSERT ON stores
FOR EACH ROW
BEGIN
  :NEW.store_id := seq_store.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_customer_id
BEFORE INSERT ON customers
FOR EACH ROW
BEGIN
  :NEW.customer_id := seq_customer.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_sale_id
BEFORE INSERT ON sales
FOR EACH ROW
BEGIN
  :NEW.sale_id := seq_sale.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_sale_item_id
BEFORE INSERT ON sale_items
FOR EACH ROW
BEGIN
  :NEW.sale_item_id := seq_sale_item.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_inventory_id
BEFORE INSERT ON inventory
FOR EACH ROW
BEGIN
  :NEW.inventory_id := seq_inventory_id.NEXTVAL;
END;
/


-- =====================================================================
-- 2) Line total = quantity x unit price x (1 - discount%)
--    If no unit price is supplied, the current product price is used,
--    so the price at the time of sale is kept on the sale item.
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_line_total
BEFORE INSERT OR UPDATE ON sale_items
FOR EACH ROW
BEGIN
  IF :NEW.unit_price IS NULL THEN
    SELECT unit_price
      INTO :NEW.unit_price
      FROM products
     WHERE product_id = :NEW.product_id;
  END IF;

  :NEW.line_total := :NEW.quantity * :NEW.unit_price
                     * (1 - NVL(:NEW.discount, 0) / 100);
END;
/


-- =====================================================================
-- 3) Block a sale item when the store does not have enough stock
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_check_inventory
BEFORE INSERT ON sale_items
FOR EACH ROW
DECLARE
  v_stock NUMBER;
BEGIN
  BEGIN
    SELECT quantity_in_stock
      INTO v_stock
      FROM inventory
     WHERE product_id = :NEW.product_id
       AND store_id = (SELECT store_id FROM sales WHERE sale_id = :NEW.sale_id);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20003, 'This product is not stocked in this store');
  END;

  IF v_stock < :NEW.quantity THEN
    RAISE_APPLICATION_ERROR(-20001, 'Not enough stock for this product');
  END IF;
END;
/


-- =====================================================================
-- 4) Keep inventory in sync with sale items
--    INSERT: take the quantity out of stock
--    UPDATE: put the old quantity back, then take the new one
--    DELETE: put the quantity back
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_update_inventory
AFTER INSERT OR UPDATE OR DELETE ON sale_items
FOR EACH ROW
DECLARE
  v_sale_id  NUMBER;
  v_store_id NUMBER;
BEGIN
  -- :NEW is empty on DELETE, so read the sale from :OLD in that case
  IF DELETING THEN
    v_sale_id := :OLD.sale_id;
  ELSE
    v_sale_id := :NEW.sale_id;
  END IF;

  SELECT store_id
    INTO v_store_id
    FROM sales
   WHERE sale_id = v_sale_id;

  IF INSERTING THEN
    UPDATE inventory
       SET quantity_in_stock = quantity_in_stock - :NEW.quantity
     WHERE product_id = :NEW.product_id
       AND store_id = v_store_id;

  ELSIF UPDATING THEN
    UPDATE inventory
       SET quantity_in_stock = quantity_in_stock + :OLD.quantity
     WHERE product_id = :OLD.product_id
       AND store_id = v_store_id;

    UPDATE inventory
       SET quantity_in_stock = quantity_in_stock - :NEW.quantity
     WHERE product_id = :NEW.product_id
       AND store_id = v_store_id;

  ELSE -- DELETING
    UPDATE inventory
       SET quantity_in_stock = quantity_in_stock + :OLD.quantity
     WHERE product_id = :OLD.product_id
       AND store_id = v_store_id;
  END IF;
END;
/


-- =====================================================================
-- 5) Keep SALES.TOTAL_AMOUNT in sync with its sale items
--    A row-level trigger cannot read SALE_ITEMS while SALE_ITEMS is
--    being changed (ORA-04091, "table is mutating"). A compound trigger
--    solves this: collect the affected sale ids row by row, then
--    recalculate each total once after the statement finishes.
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_update_sale_total
FOR INSERT OR UPDATE OR DELETE ON sale_items
COMPOUND TRIGGER

  TYPE t_sale_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  g_sale_ids t_sale_ids;   -- indexed by sale_id, so duplicates collapse

  AFTER EACH ROW IS
  BEGIN
    IF INSERTING OR UPDATING THEN
      g_sale_ids(:NEW.sale_id) := 1;
    END IF;
    IF DELETING OR UPDATING THEN
      g_sale_ids(:OLD.sale_id) := 1;
    END IF;
  END AFTER EACH ROW;

  AFTER STATEMENT IS
    v_sale_id PLS_INTEGER;
  BEGIN
    v_sale_id := g_sale_ids.FIRST;
    WHILE v_sale_id IS NOT NULL LOOP
      UPDATE sales s
         SET total_amount = (SELECT NVL(SUM(line_total), 0)
                               FROM sale_items
                              WHERE sale_id = s.sale_id)
       WHERE s.sale_id = v_sale_id;
      v_sale_id := g_sale_ids.NEXT(v_sale_id);
    END LOOP;
    g_sale_ids.DELETE;
  END AFTER STATEMENT;

END trg_update_sale_total;
/


-- =====================================================================
-- 6) Stock can never go negative
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_no_negative_stock
BEFORE INSERT OR UPDATE ON inventory
FOR EACH ROW
BEGIN
  IF :NEW.quantity_in_stock < 0 THEN
    RAISE_APPLICATION_ERROR(-20002, 'Stock cannot be negative');
  END IF;
END;
/

-- =====================================================================
-- END OF TRIGGERS SCRIPT
-- =====================================================================
