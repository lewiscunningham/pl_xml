DECLARE
  v_xml XMLType := 
     XMLType('
<ROOT>  
  <CMD type="variable">
    <VAR name="$var1$" type="literal" datatype="char">MyValue</VAR>
  </CMD>  
  <CMD type="variable">
    <VAR name="$var2$" type="function" datatype="date" format="dd/mm/yyyy hh24:mi:ss">
      <FUNCTION name="sysdate" />
    </VAR>
  </CMD>  
  <CMD type="for">   
    <FOR from="1" to="5">
      <CMD type="proc">
        <PROC name="dbms_output.put_line">
          <PARAMETER name="a">$var1$ is $var2$</PARAMETER>
        </PROC>
      </CMD>
    </FOR>
  </CMD>
</ROOT>     
  ');
  
BEGIN

  xml_interpret.main( v_xml );
  
END;
    
