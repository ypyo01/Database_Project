from sqlalchemy import create_engine
import psycopg2
from psycopg2 import Error
import pandas as pd
from function import *
from pathlib import Path
import matplotlib.pyplot as plt
import seaborn as sns

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

    query = """
        WITH ValidApplications AS (
            SELECT
                request_id,
                volunteer_id,
                time_modified,
                EXTRACT(YEAR FROM time_modified) AS year,
                EXTRACT(MONTH FROM time_modified) AS month
            FROM Application
            WHERE is_valid = TRUE
        ),
        ValidRequests AS (
            SELECT
                id AS request_id,
                start_date,
                EXTRACT(YEAR FROM start_date) AS year,
                EXTRACT(MONTH FROM start_date) AS month
            FROM Request
            WHERE start_date IS NOT NULL
        )
        SELECT
            va.year,
            va.month,
            va.valid_applications,
            vr.valid_requests,
            (va.valid_applications - vr.valid_requests) AS difference
        FROM (
            SELECT
                year,
                month,
                COUNT(*) AS valid_applications
            FROM ValidApplications
            GROUP BY year, month
        ) va
        JOIN (
            SELECT
                year,
                month,
                COUNT(*) AS valid_requests
            FROM ValidRequests
            GROUP BY year, month
        ) vr
        ON va.year = vr.year AND va.month = vr.month
        ORDER BY va.year, va.month;
        """
    df = pd.read_sql(text(query), con=psql_conn)
    df['date'] = pd.to_datetime(df[['year', 'month']].assign(day=1))

    # Plotting the data
    fig, ax = plt.subplots(figsize=(12, 6))

    width = 15  # Width of the bars

    ax.bar(df['date'] - pd.Timedelta(days=width/2), df['valid_applications'], width=width, label='Valid Applications')
    ax.bar(df['date'] + pd.Timedelta(days=width/2), df['valid_requests'], width=width, label='Valid Requests')
    ax.plot(df['date'], df['difference'], color='red', marker='o', label='Difference')

    ax.set_xlabel('Month')
    ax.set_ylabel('Count')
    ax.set_title('Valid Volunteer Applications and Requests by Month')
    ax.legend()

    plt.xticks(df['date'], df['date'].dt.strftime('%Y-%m'), rotation=45)
    plt.tight_layout()
    plt.show()

    df_2 = pd.read_sql(text(query), con=psql_conn)
    # Aggregate by month
    monthly_data = df_2.groupby('month').sum().reset_index()

    # Plotting the data
    fig, ax = plt.subplots(figsize=(12, 6))

    width = 0.4  # Width of the bars

    ax.bar(monthly_data['month'] - width/2, monthly_data['valid_applications'], width=width, label='Valid Applications')
    ax.bar(monthly_data['month'] + width/2, monthly_data['valid_requests'], width=width, label='Valid Requests')
    ax.plot(monthly_data['month'], monthly_data['valid_applications'] - monthly_data['valid_requests'], color='red', marker='o', label='Difference')

    ax.set_xlabel('Month')
    ax.set_ylabel('Count')
    ax.set_title('Valid Volunteer Applications and Requests by Month (Aggregated)')
    ax.legend()

    plt.xticks(monthly_data['month'], ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'])
    plt.tight_layout()
    plt.show()

    query = """
        SELECT v.id AS volunteer_id, COALESCE(vs.skill_count, 0) AS skill_count, COALESCE(sa.successful_applications, 0) AS successful_applications
        FROM Volunteer v
        LEFT JOIN (
            SELECT vs.volunteer_id, COUNT(vs.skill_name) AS skill_count
            FROM Volunteer_Skill vs
            GROUP BY vs.volunteer_id
        ) vs ON v.id = vs.volunteer_id
        LEFT JOIN (
            SELECT a.volunteer_id, COUNT(a.id) AS successful_applications
            FROM Application a
            WHERE a.is_valid = TRUE
            GROUP BY a.volunteer_id
        ) sa ON v.id = sa.volunteer_id;

    """

    df_3 = pd.read_sql(text(query), con=psql_conn)
    # Visualization for Skill Count vs. Successful Applications
    fig, ax = plt.subplots(figsize=(10, 6))
    sns.scatterplot(data=df_3, x='skill_count', y='successful_applications', ax=ax)
    ax.set_title('Skill Count vs. Successful Applications')
    ax.set_xlabel('Number of Skills')
    ax.set_ylabel('Number of Successful Applications')
    plt.show()

    # Analyzing correlation
    correlation = df_3['skill_count'].corr(df_3['successful_applications'])
    print(f'Correlation between skill count and successful applications: {correlation}')

except (Exception, Error) as error:  # In case we fail to establish the connection
    print("Error while connecting to PostgreSQL", error)

finally:  # Close the connection
    if connection:
        psql_conn.close()
        # cursor.close()
        connection.close()
        print("PostgreSQL connection is closed")


