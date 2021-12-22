CREATE OR REPLACE PACKAGE BODY xml_interpret 
AS

  -- A note about the XML
  -- For XML being passed in:
  --  All ELEMENT TAGs are in upper case
  --  All ATTRIBUTEs are in lower case
  --     exception format in which case case is up to the user
  
  -- Record type to hold variables
  TYPE r_variables IS RECORD (
    data_type VARCHAR2(10),
    format_mask VARCHAR2(100),
    char_field VARCHAR2(32000),
    date_field DATE,
    number_field NUMBER,
    xml_field XMLType );
    
  -- Base array type to hold variables  
  TYPE a_variables IS TABLE OF r_variables
    INDEX BY VARCHAR2(100);

  -- Global array of variables
  -- Variable values are maintained between calls at this point
  --    That could easily be changed by setting the array to NULL in main
  -- It would also be easy to pre-define a list of variables
  g_variables a_variables;

  TYPE r_debug IS RECORD (
    debug_msg VARCHAR2(32000),
    debug_procedure VARCHAR2(32000),
    debug_flag BOOLEAN := FALSE,
    debug_line NUMBER );
    
  g_debug r_debug;    
      
  -- Forward declarations
  -- See the actual procedure calls below for comments  
  PROCEDURE run_command( 
        p_cmd IN VARCHAR2 );
  PROCEDURE run_debug; 
  PROCEDURE set_debug(p_xml IN XMLType);
  PROCEDURE set_debug( 
        p_debug IN BOOLEAN,
        p_debug_procedure IN VARCHAR2 );
  PROCEDURE set_debug_msg( 
        p_debug_msg IN VARCHAR2,
        p_debug_line IN NUMBER );
  FUNCTION extract_parameters( 
        p_xml IN XMLType )
    RETURN VARCHAR2; 
  PROCEDURE CALL_PROC( 
        p_xml IN XMLType ); 
  PROCEDURE CALL_FUNC( 
        p_xml IN XMLType,
        p_variable IN OUT NOCOPY VARCHAR2 ); 
  PROCEDURE CALL_FUNC( 
        p_xml IN XMLType,
        p_variable IN OUT NOCOPY DATE ); 
  PROCEDURE CALL_FUNC( 
        p_xml IN XMLType,
        p_variable IN OUT NOCOPY NUMBER ); 
  PROCEDURE CALL_FUNC( 
        p_xml IN XMLType,
        p_variable IN OUT NOCOPY XMLType ); 
  PROCEDURE FOR_LOOP(
        p_xml IN XMLTYPE );
  PROCEDURE WHEN_COND(
        p_xml IN XMLTYPE );
  PROCEDURE parse_xml( 
        p_xml IN XMLType );
  PROCEDURE init_var( 
        p_xml IN XMLType );
  FUNCTION resolve_var( p_data IN VARCHAR2 )
    RETURN VARCHAR2; 

  -- The guts of this packages
  -- Parse checks the type of CMD and calls the appropriate functionality  
  PROCEDURE parse_xml( 
        p_xml IN XMLType )
  IS
    v_current_node XMLType;  -- Current working node
    v_cnt NUMBER := 1;       -- Loop counter
    v_type VARCHAR2(100);    -- What type of CMD is it?
  BEGIN

    LOOP

      v_type := '/CMD[ ' || v_cnt || ']/@type';
      
      -- Exit when we run out of CMDs for this node
      EXIT WHEN p_xml.existsNode(v_type) != 1; 
       
      v_current_node := p_xml.extract('/CMD[ ' || v_cnt || ']/*');
    
      CASE p_xml.extract(v_type).getStringVal()
      WHEN 'for' 
      THEN
        for_loop( v_current_node );
      WHEN 'proc' 
      THEN
        call_proc( v_current_node );
      WHEN 'variable' 
      THEN
        init_var( v_current_node );
      WHEN 'case' 
      THEN
        when_cond( v_current_node );
      WHEN 'debug' 
      THEN
        set_debug( v_current_node );
      ELSE
        NULL;
      END CASE;
      
      -- increment the loop counter
      v_cnt := v_cnt + 1;

    END LOOP;  
      
  END;
    
  PROCEDURE run_command( p_cmd IN VARCHAR2 )
  IS
  BEGIN
    -- Execute a dynamic procedure call
    EXECUTE IMMEDIATE 'BEGIN ' || p_cmd || ' END;';
  END;  

  FUNCTION extract_parameters( p_xml IN XMLType )
    RETURN VARCHAR2 
  IS
    v_parameter_string VARCHAR2(32000);
    v_cnt NUMBER := 1;
    v_data_string VARCHAR2(32000);
    v_param_type VARCHAR2(10);
  BEGIN
    
    -- If there are parameters
    IF p_xml IS NOT NULL 
    THEN
      LOOP  -- Loop through each parameter
    
        -- If a parameter at v_cnt (1,2,3,etc) position exists
        IF p_xml.existsNode('/PARAMETER[' || v_cnt || ']') = 1 
        THEN
        
          -- The parameter_type can be literal or context
          -- A literal gets wrapped in quotes
          -- A context assumes some kind of context (like a function call)
          --  And just puts it out in plain text
          -- If no paramter type is declared, literal is assumed
          -- If a null paramter type is declared, literal is assumed
          IF p_xml.existsNode('/PARAMETER[' || v_cnt || ']/@type') = 1 
          THEN
            v_param_type := 
                 p_xml.extract('/PARAMETER[' || v_cnt || ']/@type').getStringVal();
            IF v_param_type IS NULL
            THEN
              v_param_type := 'literal';
            END IF;   
          ELSE       
            v_param_type := 'literal'; 
          END IF;
        
          CASE v_param_type
          WHEN 'literal'
          THEN
            v_parameter_string := v_parameter_string || 
                   p_xml.extract( '/PARAMETER' ||
                   '[' || v_cnt || ']/' ||
                   '@name' ).getStringVal()
                   || '=>''' ||
                   p_xml.extract( '/PARAMETER' ||
                   '[' || v_cnt || ']/' ||
                   'text()' ).getStringVal()
                   || ''', ';
          WHEN 'context'
          THEN
            v_parameter_string := v_parameter_string || 
                   p_xml.extract( '/PARAMETER' ||
                   '[' || v_cnt || ']/' ||
                   '@name' ).getStringVal()
                   || '=>' ||
                   p_xml.extract( '/PARAMETER' ||
                   '[' || v_cnt || ']/' ||
                   'text()' ).getStringVal()
                   || ', ';
          END CASE;                 
                 
          v_cnt := v_cnt + 1;
        ELSE
          EXIT;
        END IF;

      END LOOP; 
    
    END IF;
    
    -- If we actually had parameters, get rid of the final , 
    --    and add () 
    -- If we had no parameters, just drop in a ;
    IF v_parameter_string IS NOT NULL 
    THEN
      v_parameter_string := '(' ||
                resolve_var(
                  SUBSTR(v_parameter_string,1,LENGTH(v_parameter_String) - 2)
                ) ||
                ');';
    ELSE
      v_parameter_string := ';';            
    END IF;

    RETURN v_parameter_string;

  END;
    
  PROCEDURE CALL_PROC( p_xml IN XMLType ) 
  IS 
    v_proc_call VARCHAR2(32000);             
  BEGIN
    -- Get the proc
    v_proc_call := p_xml.extract('/PROC/@name').getStringVal();

    -- Call the parameters
    v_proc_call := v_proc_call || 
            extract_parameters( p_xml.extract('/PROC/*') );

    -- Run the command
    run_command( v_proc_call);         

  END;
  
  -- See the text in call_proc doe details of call_func
  -- Call function is overloaded for varchar2, date, number and xml
  PROCEDURE CALL_FUNC( 
        p_xml IN XMLType,
        p_variable IN OUT NOCOPY VARCHAR2 ) 
  IS 
    v_proc_call VARCHAR2(32000);             
  BEGIN
    v_proc_call := p_xml.extract('/FUNCTION/@name').getStringVal();
    v_proc_call := v_proc_call || 
            extract_parameters( p_xml.extract('/FUNCTION/*') );

    EXECUTE IMMEDIATE 'BEGIN :x := ' || v_proc_call || ' END;'
      USING OUT p_variable; 
  END;
  
  PROCEDURE CALL_FUNC( 
        p_xml IN XMLType,
        p_variable IN OUT NOCOPY DATE ) 
  IS 
    v_proc_call VARCHAR2(32000);             
  BEGIN
    v_proc_call := p_xml.extract('/FUNCTION/@name').getStringVal();
    v_proc_call := v_proc_call || 
            extract_parameters( p_xml.extract('/FUNCTION/*') );

    EXECUTE IMMEDIATE 'BEGIN :x := ' || v_proc_call || ' END;'
      USING OUT p_variable; 
  END;
  
  PROCEDURE CALL_FUNC( 
        p_xml IN XMLType,
        p_variable IN OUT NOCOPY NUMBER ) 
  IS 
    v_proc_call VARCHAR2(32000);             
  BEGIN
    v_proc_call := p_xml.extract('/FUNCTION/@name').getStringVal();
    v_proc_call := v_proc_call || 
            extract_parameters( p_xml.extract('/FUNCTION/*') );

    EXECUTE IMMEDIATE 'BEGIN :x := ' || v_proc_call || ' END;'
      USING OUT p_variable; 
  END;
  
  PROCEDURE CALL_FUNC( 
        p_xml IN XMLType,
        p_variable IN OUT NOCOPY XMLType ) 
  IS 
    v_proc_call VARCHAR2(32000);             
  BEGIN
    v_proc_call := p_xml.extract('/FUNCTION/@name').getStringVal();
    v_proc_call := v_proc_call || 
            extract_parameters( p_xml.extract('/FUNCTION/*') );

    EXECUTE IMMEDIATE 'BEGIN :x := ' || v_proc_call || ' END;'
      USING OUT p_variable; 
  END;
  
  -- Set a variable key->value pair
  -- Variable values are maintained between calls at this point
  --    That could easily be changed by setting the array to NULL in main
  PROCEDURE init_var( p_xml IN XMLType ) 
  IS 

    v_var_type VARCHAR2(10) := p_xml.extract('/VAR/@type').getStringVal();
    v_var_name VARCHAR2(10) := p_xml.extract('/VAR/@name').getStringVal();
    v_data_type VARCHAR2(10);
    v_format VARCHAR2(100);         
  BEGIN

    -- Valid data types are:
    --   char
    --   number
    --   date
    --   xml  xml is only valid for function calls, not literals
    -- Defaults to char
    -- DATE requires an additional format attribute
    --    The format will default to DD-MON-YYYY
    IF p_xml.existsNode('/VAR/@datatype') = 1 THEN 
      v_data_type := p_xml.extract('/VAR/@datatype').getStringVal();
      IF p_xml.existsNode('/VAR/@format') = 1 THEN 
        v_format := p_xml.extract('/VAR/@format').getStringVal();
      ELSE  
        v_format := 'DD-MON-YYYY';
      END IF;  
    ELSE
      v_data_type := 'char';
    END IF;           

    set_debug_msg( 'INIT_VAR - VarName: ' || v_var_name ||
                      ', VarType: ' || v_var_type || 
                      ', DataType: ' || v_data_type ||
                      ', Format: ' || v_format
                  , $$PLSQL_LINE);

    -- A literal VAR is text passed on
    -- A function VAR calls a function to retrieve a value
    --    Functions can optionally have parameters
    g_variables(v_var_name).data_type := v_data_type;
    g_variables(v_var_name).format_mask := v_format;

    -- Variables are stored in their type field
    --  CHAR is stored in char_field
    --  NUMBER is stored in number_field
    --  DATE is stored in date_field
    --  XML is stored in xml_field 
    CASE v_var_type
    WHEN 'literal'
    THEN
      CASE v_data_type
      WHEN 'char'  
      THEN
        g_variables(v_var_name).char_field :=
          p_xml.extract('/VAR/text()').getStringVal();
      WHEN 'date'  
      THEN
        g_variables(v_var_name).date_field :=
          to_date( p_xml.extract('/VAR/text()').getStringVal(), v_format );
      WHEN 'number'  
      THEN
        g_variables(v_var_name).number_field :=
          p_xml.extract('/VAR/text()').getStringVal();
      END CASE;    
    WHEN 'function'
    THEN
      CASE v_data_type
      WHEN 'char'  
      THEN
        call_func( 
           p_xml.extract('/VAR/*'),
           g_variables(v_var_name).char_field );
      WHEN 'number'  
      THEN
        call_func( 
           p_xml.extract('/VAR/*'),
           g_variables(v_var_name).number_field );
      WHEN 'date'  
      THEN
        call_func( 
           p_xml.extract('/VAR/*'),
           g_variables(v_var_name).date_field );
      WHEN 'xml'  
      THEN
        call_func( 
           p_xml.extract('/VAR/*'),
           g_variables(v_var_name).xml_field );
      END CASE;    
    ELSE
      NULL;
    END CASE;
        
  END;
  
  FUNCTION resolve_var( p_data IN VARCHAR2 )
    RETURN VARCHAR2 
  IS 
    v_data VARCHAR2(32000) := p_data;
    v_var_name VARCHAR2(100);
    v_pos PLS_INTEGER;
    v_pos2 PLS_INTEGER;
  BEGIN
 
    LOOP
      -- Get the position of the first $
      v_pos := instr(v_data, '$', 1, 1 );
      -- Get the position of the second $
      v_pos2 := instr(v_data, '$', 1, 2 );

      -- Exit if there are zero or 1 $
      EXIT WHEN v_pos = 0 OR v_pos2 = 0;

      -- Extract the variable between the $ including the $
      v_var_name := 
        SUBSTR( v_data,
                v_pos,
                (v_pos2 + 1) - v_pos );

      -- replace the variable names with the variable values                
      CASE g_variables(v_var_name).data_type
      WHEN 'char'
      THEN
        v_data := replace( v_data, v_var_name, g_variables(v_var_name).char_field );
      WHEN 'number'
      THEN
        v_data := replace( v_data, v_var_name, g_variables(v_var_name).number_field );
      WHEN 'date'
      THEN
        v_data := replace( v_data, 
                           v_var_name, 
                           to_char(g_variables(v_var_name).date_field,
                                   g_variables(v_var_name).format_mask) );
      WHEN 'xml'
      THEN
        v_data := replace( v_data, 
                           v_var_name, 
                           g_variables(v_var_name).xml_field.getStringVal() );
      ELSE
        v_data := replace( v_data, v_var_name, g_variables(v_var_name).char_field );
      END CASE;    
    
    END LOOP;         
  
    RETURN v_data;
  END;
  
  PROCEDURE FOR_LOOP(
        p_xml IN XMLTYPE )
  IS
  
  BEGIN
    -- Execute a for loop
    FOR i IN p_xml.extract('/FOR/@from').getNumberVal()..
             p_xml.extract('/FOR/@to').getNumberVal()
    LOOP         

      parse_xml( p_xml.extract('/FOR/*') );

    END LOOP;  
  END;
  
  -- This will run a condition through the database
  -- If the codition does not evealuate to a boolean, 
  --    an error will be raised
  FUNCTION eval_cond( 
        p_cond IN VARCHAR2 )
    RETURN BOOLEAN 
  IS 
    v_boolean VARCHAR2(5);
    v_proc_call VARCHAR2(32000);             
  BEGIN
    v_proc_call := 'BEGIN IF ' || p_cond || ' THEN :x := ''TRUE''; END IF; END;';

    EXECUTE IMMEDIATE v_proc_call
      USING OUT v_boolean; 
      
    RETURN (v_boolean = 'TRUE');  
  END;
  
  -- Loop through WHENs of a CASE
  PROCEDURE WHEN_COND(
        p_xml IN XMLTYPE )
  IS
    v_boolean BOOLEAN;
    v_cnt NUMBER := 1;
  BEGIN
    LOOP
    
      IF p_xml.existsNode('/WHEN[' || v_cnt || ']') = 1 
      THEN
        IF eval_cond(
                p_xml.extract(
                       '/WHEN[' || v_cnt || ']/@condition').getStringVal())
        THEN
          parse_xml( p_xml.extract('/WHEN[' || v_cnt || ']/*') );
          EXIT;
        END IF;  
    
      END IF;

      v_cnt := v_cnt + 1;

    END LOOP;             
  END;

  -- Parse the DEBUG XML and call SET_DEBUG
  PROCEDURE set_debug(p_xml IN XMLType)
  IS
    v_debug_flag BOOLEAN;
    v_debug_procedure VARCHAR2(32000);
  BEGIN
    IF p_xml.existsNode('/DEBUG/@procedure') = 1 
    THEN
       v_debug_procedure := p_xml.extract('/DEBUG/@procedure').getStringVal();
    END IF;   
                       
    IF p_xml.existsNode('/DEBUG/@flag') = 1 
    THEN
       v_debug_flag := UPPER(p_xml.extract('/DEBUG/@flag').getStringVal()) = 'TRUE';
    END IF;   

    set_debug( v_debug_flag, v_debug_procedure );
                           
  END; 

  -- Set the debug flag and debug procedure (optional)
  PROCEDURE set_debug( 
        p_debug IN BOOLEAN,
        p_debug_procedure IN VARCHAR2 )
  IS
  BEGIN
    IF p_debug IS NOT NULL 
    THEN
      g_debug.debug_flag := p_debug;
    END IF;
    
    IF p_debug_procedure IS NOT NULL 
    THEN  
      g_debug.debug_procedure := p_debug_procedure;
    END IF;
      
  END;

  -- Set the debug text message and line number
  PROCEDURE set_debug_msg( 
        p_debug_msg IN VARCHAR2,
        p_debug_line IN NUMBER ) 
  IS
  BEGIN
    g_debug.debug_msg := p_debug_msg;
    g_debug.debug_line := p_debug_line;
    IF g_debug.debug_flag THEN
      run_debug;
    END IF;
  END;          

  -- Output the debug message
  -- Defaults to DBMS_OUTPUT if no procedure defined
  PROCEDURE run_debug 
  IS
    v_output_line VARCHAR2(32000);
  BEGIN
  
    v_output_line := 'Line# ' || to_char(g_debug.debug_line) ||
                     ', Msg: ' || g_debug.debug_msg;
                     
    IF g_debug.debug_procedure IS NULL 
    THEN
      DBMS_OUTPUT.PUT_LINE( v_output_line );
    ELSE
      EXECUTE IMMEDIATE 'BEGIN ' || g_debug.debug_procedure || 
            '( :v_msg ); END;' 
        USING v_output_line;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( v_output_line );
      RAISE;
  END; 

  PROCEDURE main( 
        p_xml IN XMLType )
  IS
    v_cnt NUMBER := 1;
    v_current_node XMLType;        
  BEGIN
    -- Loop through all higher level CMDs starting with the first CMD
    --    Beneath ROOT
    -- Exit when there are no child nodes            
    LOOP
       
      IF p_xml.existsNode('/ROOT/child::node()[' || v_cnt || ']') = 1 
      THEN
        v_current_node := p_xml.extract('/ROOT/child::node()[' || v_cnt || ']');

        set_debug_msg( 'MAIN - Working on: ' || v_current_node.getStringVal(), $$PLSQL_LINE);

        parse_xml( v_current_node );           

        v_cnt := v_cnt + 1;

      ELSE
        EXIT;
      END IF;           
    END LOOP;
  
  EXCEPTION 
    WHEN OTHERS THEN
      run_debug;
      set_debug( TRUE, NULL);
      set_debug_msg( 'Error: ' || 
                          DBMS_UTILITY.FORMAT_ERROR_STACK() ||
                          DBMS_UTILITY.FORMAT_ERROR_BACKTRACE()
                    , g_debug.debug_line);
      RAISE;  
  END;
      
END;

        