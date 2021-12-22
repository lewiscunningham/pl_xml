CREATE OR REPLACE FUNCTION test_date_func
  RETURN DATE
IS
BEGIN
  RETURN sysdate;
END;

  