-- =====================================================================
-- Trigger smoke test
-- Everything is rolled back at the end, so no data is changed.
-- Assumes product 1, store 1 and customer 1 exist, and that
-- inventory has a row for product 1 in store 1.
-- Run in SQL*Plus or VS Code.
-- =====================================================================
SET SERVEROUTPUT ON

DECLARE
  v_sale_id      sales.sale_id%TYPE;
  v_item_id      sale_items.sale_item_id%TYPE;
  v_stock_start  inventory.quantity_in_stock%TYPE;
  v_stock        inventory.quantity_in_stock%TYPE;
  v_line         sale_items.line_total%TYPE;
  v_total        sales.total_amount%TYPE;
BEGIN
  SELECT quantity_in_stock
    INTO v_stock_start
    FROM inventory
   WHERE product_id = 1 AND store_id = 1;
  DBMS_OUTPUT.PUT_LINE('Stock before sale                  : ' || v_stock_start);

  -- 1) New sale in store 1 for customer 1
  INSERT INTO sales (store_id, customer_id)
  VALUES (1, 1)
  RETURNING sale_id INTO v_sale_id;

  -- 2) Sell 2 units of product 1 with a 10% discount
  INSERT INTO sale_items (sale_id, product_id, quantity, discount)
  VALUES (v_sale_id, 1, 2, 10)
  RETURNING sale_item_id INTO v_item_id;

  SELECT line_total INTO v_line  FROM sale_items WHERE sale_item_id = v_item_id;
  SELECT total_amount INTO v_total FROM sales WHERE sale_id = v_sale_id;
  SELECT quantity_in_stock INTO v_stock
    FROM inventory WHERE product_id = 1 AND store_id = 1;

  DBMS_OUTPUT.PUT_LINE('Line total (2 x unit price x 0.9)   : ' || v_line);
  DBMS_OUTPUT.PUT_LINE('Sale total (should equal line total): ' || v_total);
  DBMS_OUTPUT.PUT_LINE('Stock after sale (expected ' || (v_stock_start - 2) || ')    : ' || v_stock);

  -- 3) Selling more than the available stock must be blocked
  BEGIN
    INSERT INTO sale_items (sale_id, product_id, quantity)
    VALUES (v_sale_id, 1, v_stock + 1);
    DBMS_OUTPUT.PUT_LINE('FAIL: overselling was not blocked');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Overselling blocked as expected    : ' || SQLERRM);
  END;

  -- 4) Deleting the item must restore stock and reset the sale total
  DELETE FROM sale_items WHERE sale_item_id = v_item_id;

  SELECT total_amount INTO v_total FROM sales WHERE sale_id = v_sale_id;
  SELECT quantity_in_stock INTO v_stock
    FROM inventory WHERE product_id = 1 AND store_id = 1;

  DBMS_OUTPUT.PUT_LINE('Sale total after delete (expected 0): ' || v_total);
  DBMS_OUTPUT.PUT_LINE('Stock after delete (expected ' || v_stock_start || ')    : ' || v_stock);

  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('Rolled back - no data was changed.');
END;
/
