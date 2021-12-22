DECLARE
  v_xml XMLType := 
     XMLType('
<ROOT>  
  <CMD type="debug">   
    <DEBUG flag="true" procedure="dbms_output.put_line" />
  </CMD>  
  <CMD type="for">   
    <FOR from="1" to="3">
      <CMD type="variable">
        <VAR name="$var1$" type="literal" data_type="char">MyValue</VAR>
      </CMD>  
      <CMD type="variable">
        <VAR name="$var2$" type="literal" data_type="date" format="DD-MON-YYYY">01-JAN-2005</VAR>
      </CMD>  
      <CMD type="variable">
        <VAR name="$var3$" type="literal" data_type="number">1999</VAR>
      </CMD>  
      <CMD type="variable">
        <VAR name="$var4$" type="function" data_type="char">
          <FUNCTION name="test_func">
            <PARAMETER name="parm1">$var1$</PARAMETER>
            <PARAMETER name="parm2">def</PARAMETER>
          </FUNCTION>
        </VAR>
      </CMD>  
      <CMD type="proc">
        <PROC name="test_proc">
          <PARAMETER name="parm1">$var1$</PARAMETER>
          <PARAMETER name="parm2">def</PARAMETER>
        </PROC>
      </CMD>
    </FOR>
  </CMD>
  <CMD type="for">   
    <FOR from="1" to="5">
      <CMD type="proc">
        <PROC name="dbms_output.put_">
          <PARAMETER name="a">Hello World!</PARAMETER>
        </PROC>
      </CMD>
    </FOR>
  </CMD>
  <CMD type="case">   
    <WHEN condition="1=2">
      <CMD type="proc">
        <PROC name="dbms_output.put_line">
          <PARAMETER name="a">Condition: 1=2</PARAMETER>
        </PROC>
      </CMD>
    </WHEN>
    <WHEN condition="1=1">
      <CMD type="proc">
        <PROC name="dbms_output.put_line">
          <PARAMETER name="a">Condition: 1=1</PARAMETER>
        </PROC>
      </CMD>
    </WHEN>
  </CMD>
  <CMD type="proc">   
    <PROC name="dbms_output.put_line">
      <PARAMETER name="a">$var4$</PARAMETER>
    </PROC>
  </CMD>
  <CMD type="proc">
     <PROC name="dbms_output.put_line">
        <PARAMETER name="a" type="context">TO_CHAR(sysdate)</PARAMETER>
     </PROC>
  </CMD>
  <CMD type="variable">
    <VAR name="$var5$" type="function" data_type="date" format="dd-mon-yyyy">
      <FUNCTION name="test_date_func" />
    </VAR>
  </CMD>  
  <CMD type="proc">
     <PROC name="dbms_output.put_line">
        <PARAMETER name="a" type="literal">$var5$</PARAMETER>
     </PROC>
  </CMD>
</ROOT>     
  ');
  
BEGIN

  xml_interpret.main( v_xml );
  
END;
    