# pl_xml
PL/XML: XML Based Scripting for PL/SQL

I started working on a task for a project and decided that there were some very good properties that I could use to help me teach people PL/SQL and XML. I expanded a bit on the idea and ended up with a scripting language, implemented in XML, that can be passed into a PL/SQL procedure. 

The script can execute stored procedures, it has looping logic, conditional (CASE) logic, user defined variables, etc. The nice thing about it is that it’s very easy to read and modify. The XML structure is also very easy to read. 

It’s really a learning tool but it may have some real life uses also. You can modify application functionality on the fly just by changing XML. You could even write a program that would generate XML for you that would then feed other systems. Quite cool! 

Here is a sample script:

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
          <PARAMETER name="a">
            $var1$ is $var2$
          </PARAMETER>
        </PROC>
      </CMD>       
    </FOR>  
  </CMD>
</ROOT>         

That XML, when run through my script interpreter, will output:
MyValue is 25/08/2006 15:06:59
MyValue is 25/08/2006 15:06:59
MyValue is 25/08/2006 15:06:59
MyValue is 25/08/2006 15:06:59
MyValue is 25/08/2006 15:06:59


The script is run sequentially. 

So the first thing it does is declare a variable, $var1$ and assign it the value of “MyValue”. 

The next command is also a variable, $var2$, but instead of being assigned a literal,it gets its value from a function, to_char(sysdate). 

The next command is a for loop. It will loop 1 to 5 times and for each loop will execute a procedure. In this case, it prints out the values of $var1$ and $var2$ with the word “is” between them. 

Procedures and Functions optionally allow parameters. All parameters to functions and procedures are named. You must know and give the name of the parameter. Variables can be named anything but must be enclosed by $. I chose $var1$ and $var2$ just as a standard in my example. I could have named them $boogabooga1$ and $kerplump2$. 

I think this is a good learning tool because it covers so many concepts. 

There are three issues with the code right now. First, there is no documentation except comments, there is absolutely no exception handling and there is no instrumentation or debugging code. I haven’t decided best how to do any exception handling. 

Should the interpreter handle exceptions or just let them propagate up? And I need to write an unobtrusive debug procedure that can optionally output each step of the process. Another thing to think about is that this is meant for access from program to program or by developers. You wouldn’t want to hang this out on the web or something. That could definately be a security problem. 

If you are going to use this, think about making it an invoker’s rights package. I will think more about the security implications in time. Just something to consider. 

If you’re curious, the code for PL/XML covers:

Package Variable
Private Package Variable
Record Types
Tables of Records
Associative Arrays
Procedure Overloading
XMLType
XPath
XSLT
LOOP
FOR LOOP
CASE
Dynamic SQL
Data Driven Programming
String Manipulation
Recursive Programming

All of that in about 500 lines of code (including white space and comments). This was really fun to write. Altogether it took about 4 hours. Here’s a more comprehensive example that shows a lot of the functionality. 

This XML:

<ROOT>
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
        <PROC name="dbms_output.put_line">
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
    <WHEN condition="1=3">
      <CMD type="proc">
        <PROC name="dbms_output.put_line">
          <PARAMETER name="a">Condition: 1=3</PARAMETER>
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
      
Given these test procedures:
CREATE OR REPLACE PROCEDURE test_proc( 
            parm1 IN VARCHAR2, 
            parm2 IN VARCHAR2 ) 
IS
  BEGIN   
    DBMS_OUTPUT.PUT_LINE( 'Out: ' || parm1 || parm2 );
  END;
  
CREATE OR REPLACE FUNCTION test_func( 
            parm1 IN VARCHAR2, 
            parm2 IN VARCHAR2 )   
  RETURN VARCHAR2 
IS
  BEGIN   
    RETURN 'Data: ' || parm1 || '|' || parm2;
  END;

CREATE OR REPLACE FUNCTION test_date_func   
  RETURN DATE
IS
  BEGIN   
    RETURN sysdate;
  END;
  
Produces this output:

Out: MyValuedef
Out: MyValuedef
Out: MyValuedef

Hello World!
Hello World!
Hello World!
Hello World!
Hello World!

Condition: 1=1
Data: MyValue|def25-AUG-0625-AUG-06

I’m releasing this as open source so you can use it or abuse it as you see fit. 
