import sqlite3
import time
from typing import List, Tuple
import argparse
from datetime import datetime

def get_new_queries(
        conn: sqlite3.Connection, initial_rows: int, ip_address: str
) -> List[Tuple[str, str]]:
    """
    Get new queries from the Pi-hole query log
    :param conn: The connection to the Pi-hole SQLite database
    :param initial_rows: The initial number of rows in the query log
    :param ipaddress: IP Address to query
    :return: A list of new queries, each represented as a tuple (domain, timestamp)
    """
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM queries WHERE client = ?", (ip_address,))
    current_rows = cursor.fetchone()[0]
    if current_rows > initial_rows:
        cursor.execute(
            "SELECT domain, timestamp FROM queries WHERE client = ? ORDER BY id DESC LIMIT {}".format(
                current_rows - initial_rows
            ),
            (ip_address,),
        )
        new_queries = cursor.fetchall()
        return new_queries
    return []


def print_queries(queries: List[Tuple[str, str]]):
    """
    Print new queries
    :param queries: A list of new queries, each represented as a tuple (domain, timestamp)
    """
    for query in queries:
        timestamp = datetime.fromtimestamp(query[1]).strftime('%m-%d %H:%M')
        print("{} {}".format(timestamp, query[0]))


def tail_queries(database_path: str, ip_address: str):
    """
    Tails the Pi-hole query log
    :param database_path: The path to the Pi-hole SQLite database
    """
    # Connect to the database
    conn = sqlite3.connect(database_path)
    cursor = conn.cursor()

    # Get the initial number of rows
    cursor.execute("SELECT COUNT(*) FROM queries WHERE client = ?", (ip_address,))
    initial_rows = cursor.fetchone()[0]

    while True:
        new_queries = get_new_queries(conn, initial_rows, ip_address)
        print_queries(new_queries)
        initial_rows += len(new_queries)
        # Wait for a second before polling the database again
        time.sleep(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "ip_address", help="The IP address of the client to filter the queries by"
    )
    parser.add_argument(
        "database_path", help="The path to the Pi-hole SQLite database file"
    )
    args = parser.parse_args()
    tail_queries(args.database_path, args.ip_address)
