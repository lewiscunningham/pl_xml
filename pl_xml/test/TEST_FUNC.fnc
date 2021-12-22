CREATE OR REPLACE FUNCTION test_func( parm1 IN VARCHAR2, parm2 IN VARCHAR2 )
  RETURN VARCHAR2 
IS
BEGIN
  RETURN 'Data: ' || parm1 || '|' || parm2;
END;

  