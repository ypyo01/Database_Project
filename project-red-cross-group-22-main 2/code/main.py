from sqlalchemy import create_engine
import psycopg2
from psycopg2 import Error
import pandas as pd
from function import *
from pathlib import Path

# Here you define the credentials
DATABASE = "group_22_2024" # TO BE REPLACED
USER = "group_22_2024"# TO BE REPLACED
PASSWORD = "8IB1GtKMTx2H" # TO BE REPLACED
HOST = "dbcourse.cs.aalto.fi"

# Our connection to the database
try:
    connection = psycopg2.connect(
        database = DATABASE,
        user = USER,
        password = PASSWORD,
        host = HOST,
        port = "5432"
    )
    connection.autocommit = True

    # Create a cursor to perform database operations
    cursor = connection.cursor()

    # Connect to db using SQLAlchemy create_engine
    DIALECT = "postgresql+psycopg2://"
    db_uri = "%s:%s@%s/%s" % (USER, PASSWORD, HOST, DATABASE)
    engine = create_engine(DIALECT + db_uri)
    DATADIR = str(Path(__file__).parent)
    sql_file1 = open(DATADIR + "/table.sql")
    psql_conn = engine.connect()

    ####CREATE TABLES
    run_sql_from_file(sql_file1, psql_conn) 
    psql_conn.commit() 

    ####POPULATE DATABASE AND SANITIZE DATA
    # Read the data from the Excel file for City
    data_file_path = str(Path(__file__).parent.parent) + "/data/data.xlsx"
    df = pd.read_excel(data_file_path, sheet_name='city')

    df[['latitude', 'longitude']] = df['geolocation'].str.split('/', expand=True)

    # Convert the new columns to float type
    df['latitude'] = df['latitude'].astype(float)
    df['longitude'] = df['longitude'].astype(float)

    df = df.drop(columns=['geolocation'])

    # Swap columns 'id' and 'name'
    df = df[['id', 'name', 'latitude', 'longitude']]

    df.to_sql('city', engine, if_exists='append', index=False)

    ####
    # Read the data from the Excel file for Volunteer
    df = pd.read_excel(data_file_path, sheet_name='volunteer')

    # Reformat birthdate to remove time component
    df['birthdate'] = pd.to_datetime(df['birthdate']).dt.date
    df = df[['id', 'name', 'birthdate', 'email', 'address', 'travel_readiness']]
    df.to_sql('volunteer', engine, if_exists='append', index=False)

    ####
    # Read the data from the Excel file for Volunteer Range
    df = pd.read_excel(data_file_path, sheet_name='volunteer_range')
    df.to_sql('volunteer_range', engine, if_exists='append', index=False)

    ####
    # Read the data from the Excel file for Skill
    df = pd.read_excel(data_file_path, sheet_name='skill')
    df.to_sql('skill', engine, if_exists='append', index=False)

    ####
    # Read the data from the Excel file for Volunteer Skill
    df = pd.read_excel(data_file_path, sheet_name='skill_assignment')
    df.to_sql('volunteer_skill', engine, if_exists='append', index=False)

    ####
    # Read the data from the Excel file for Volunteer Area of Interest
    df = pd.read_excel(data_file_path, sheet_name='interest_assignment')
    # Separate the entries with spaces and make them lowercase
    df.to_sql('volunteer_area_of_interest', engine, if_exists='append', index=False)

    ####
    # Read the data from the Excel file for Beneficiary
    df = pd.read_excel(data_file_path, sheet_name='beneficiary')
    df = df.drop(columns=['city_id'])
    df.to_sql('beneficiary', engine, if_exists='append', index=False)

    ####
    # Read the data from the Excel file for Request
    df = pd.read_excel(data_file_path, sheet_name='request')
    df['start_date'] = pd.to_datetime(df['start_date']).dt.date
    df['end_date'] = pd.to_datetime(df['end_date']).dt.date
    words_to_remove = ['needed']
    df['title'] = df['title'].apply(lambda x: ''.join(word.capitalize() for word in x.split() if word.lower() not in words_to_remove))
    df.to_sql('request', engine, if_exists='append', index=False)

    ####
    # Read the data from the Excel file for Request Skill
    df = pd.read_excel(data_file_path, sheet_name='request_skill')
    df = df = df.rename(columns={"value": "importance"})
    df.to_sql('request_skill', engine, if_exists='append', index=False)

    ####
    # Read the data from the Excel file for Request Location
    df = pd.read_excel(data_file_path, sheet_name='request_location')
    df.to_sql('request_location', engine, if_exists='append', index=False)

    ####
    # Read the data from the Excel file for Application
    df = pd.read_excel(data_file_path, sheet_name='volunteer_application')
    df = df.rename(columns={"modified": "time_modified"})
    df.to_sql('application', engine, if_exists='append', index=False)
    
except (Exception, Error) as error:  # In case we fail to establish the connection
    print("Error while connecting to PostgreSQL", error)

finally:  # Close the connection
    if connection:
        psql_conn.close()
        # cursor.close()
        connection.close()
        print("PostgreSQL connection is closed")


