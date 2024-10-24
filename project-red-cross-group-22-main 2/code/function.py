from sqlalchemy import text

def run_sql_from_file(sql_file, psql_conn):
    '''
    Read a SQL file with multiple statements and process it
    adapted from an idea by JF Santos
    '''
    sql_command = ''
    ret_ = True
    for line in sql_file:
        # Ignore commented lines
        if not line.startswith('--') and line.strip('\n'):
            # Append line to the command string, prefix with space
            sql_command += ' ' + line.strip('\n')
            # If the command string ends with ';', it is a full statement
            if sql_command.endswith(';'):
                # Try to execute statement and commit it
                try:
                    psql_conn.execute(text(sql_command))
                except Exception as e:
                    print(f'Error at command: {sql_command}. Error: {e}')
                    ret_ = False
                # Clear command string
                finally:
                    sql_command = ''
    return ret_
