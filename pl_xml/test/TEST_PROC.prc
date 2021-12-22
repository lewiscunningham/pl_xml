CREATE OR REPLACE PROCEDURE test_proc( parm1 IN VARCHAR2, parm2 IN VARCHAR2 ) 
IS
BEGIN
  DBMS_OUTPUT.PUT_LINE( 'Out: ' || parm1 || parm2 );
END;

  