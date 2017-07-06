--CREATE OR REPLACE FUNCTION APPS.TEST_SERIAL_1
--  RETURN varchar2 IS
        declare
        l_count number;
        v_serial varchar2(32000); 
        v_min varchar2(4000);
        v_max number;
        v_temp number;  
        v_i number;
        v_j number;
        v_kq varchar2(4000);
  CURSOR line_csr(l_VALUABLE_PAPER_ID number)
  IS
--      SELECT SERIAL_NUMBER--,TYPE_CODE
--      FROM AC_SERIAL_DETAILS_V WHERE INVENTORY_ORG_ID = 4063 AND VALUABLE_PAPER_ID = 2922 ORDER BY SERIAL_NUMBER;
    --  where VALUABLE_PAPER_ID=l_VALUABLE_PAPER_ID;-- and rownum<=300000;
    select distinct split
    from (select regexp_substr ('001,002,003,005,006,007,009,010,012,013,014,016,018,019,020,021,025,026', '[^,]+', 1, rownum) split  from dual  connect by level <= length (regexp_replace ('001,002,003,005,006,007,009,010,012,013,014,016,018,019,020,021,025,026', '[^,]+'))  + 1)
    order by to_number(split);

   TYPE SERIAL_NUMBER_tbl_type IS TABLE OF ac_serial_details_v.SERIAL_NUMBER%TYPE;
   --TYPE TYPE_CODE_tbl_type IS TABLE OF ac_serial_details.TYPE_CODE%TYPE;
   l_SERIAL_NUMBER_tbl SERIAL_NUMBER_tbl_type;
   --l_TYPE_CODE_tbl TYPE_CODE_tbl_type;
BEGIN
     OPEN line_csr(2922);
     FETCH line_csr BULK COLLECT INTO l_SERIAL_NUMBER_tbl;
     l_count:=line_csr%ROWCOUNT;

     CLOSE line_csr;
     
     v_i := 1;
     v_j := 0;
     FOR i in 1..l_count LOOP
        if i <> l_count then
            if v_i=1 then
                v_min := to_char(l_SERIAL_NUMBER_tbl(i));
                v_temp := to_number(l_SERIAL_NUMBER_tbl(i));
            end if;
            
            if v_j=1 then
                --v_min := to_char(l_SERIAL_NUMBER_tbl(i));
                v_temp := to_number(l_SERIAL_NUMBER_tbl(i));
            end if;
            --001,002,003,005,006,007,009,010,012,013,014,016,018,019,020,021
            if (v_temp <> to_number(l_SERIAL_NUMBER_tbl(i))) then
                v_kq := v_kq || ',' || v_min || '-' || LPAD(to_char(v_temp-1), LENGTH(l_SERIAL_NUMBER_tbl(i)), '0');
                v_min := l_SERIAL_NUMBER_tbl(i);
                v_j := 1;
            ELSE 
                v_temp := v_temp+1;
                v_j := 0;    
            end if;
            v_i := v_i +1;
        end if;    
        if i = l_count then 
            v_kq := v_kq || ',' || v_min || '-' || l_SERIAL_NUMBER_tbl(i);
        end if; 
     END LOOP; 
     
--     FOR i IN 1..l_count LOOP
--        if i=1 then
--            v_serial:=v_serial || l_SERIAL_NUMBER_tbl(i);
--        elsif i=l_count-1 then
--            v_serial:=v_serial || '-' || l_SERIAL_NUMBER_tbl(i);
--        end if;
--     end loop;
   --  v_serial:=to_char(v_test);
     --return trim(both ',' from v_kq);
     dbms_output.put_line(trim(both ',' from v_kq));
END test_serial_1;
/