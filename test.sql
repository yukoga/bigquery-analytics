DECLARE name STRING DEFAULT 'hoge';
DECLARE table_name STRING DEFAULT 'temp';
DECLARE end_date STRING DEFAULT FORMAT_DATE('%y%m%d', CURRENT_DATE('Asia/Tokyo'));

BEGIN
    SELECT name, end_date;

EXCEPTION WHEN ERROR THEN
    # Get error informations
    SELECT
        @@error.message,
        @@error.stack_trace,
        @@error.statement_text,
        @@error.formatted_stack_trace;
END;
