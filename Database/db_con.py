import os

import mysql.connector
from dotenv import load_dotenv
from mysql.connector import pooling

load_dotenv()

db_config = {
    "host": os.getenv("DB_HOST"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME"),
}

connection_pool = pooling.MySQLConnectionPool(
    pool_name="ride_match_pool",
    pool_size=5,
    **db_config,
)


def get_connection():
    return connection_pool.get_connection()
