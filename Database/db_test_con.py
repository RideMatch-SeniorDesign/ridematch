from db_con import get_connection

try:
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT DATABASE();")
    print("Connected to:", cursor.fetchone()[0])

    cursor.execute("SHOW TABLES;")
    tables = cursor.fetchall()

    print("\nTables:")
    for table in tables:
        print("-", table[0])

except Exception as e:
    print("Error:", e)

finally:
    if conn.is_connected():
        cursor.close()
        conn.close()
        print("\nConnection closed.")