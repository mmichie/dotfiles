#!/usr/bin/env python3

import argparse
import requests
import sqlite3
import time
import dns.resolver

from datetime import datetime
from typing import List, Tuple


def get_ip_address(domain: str, resolver: str) -> str:
    """
    Get the IP address of a domain
    :param domain: The domain to get the IP address for
    :param resolver: The IP address of the DNS resolver
    :return: The IP address of the domain
    """
    dns_resolver = dns.resolver.Resolver()
    dns_resolver.nameservers = [resolver]
    try:
        answers = dns_resolver.query(domain, "A")
        return str(answers[0])
    except dns.resolver.NXDOMAIN:
        return "NXDOMAIN"
    except dns.resolver.NoAnswer:
        return "NoAnswer"
    except dns.resolver.NoNameservers:
        return "NoNameservers"


def check_domain(domain: str, resolver: str):
    """
    Check if a domain is blocked by OpenDNS Family Shield
    :param domain: The domain to check
    :param resolver: The IP address of the OpenDNS resolver
    :return: True if the domain is blocked, False otherwise
    """
    result = get_ip_address(domain, resolver)
    if result == "146.112.61.106":
        return True
    else:
        return False


def get_new_queries(
    conn: sqlite3.Connection, initial_rows: int, ip_address: str
) -> List[Tuple[str, str]]:
    """
    Get new queries from the Pi-hole query log
    :param conn: The connection to the Pi-hole SQLite database
    :param initial_rows: The initial number of rows in the query log
    :return: A list of new queries, each represented as a tuple (domain, timestamp, type)
    """
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM queries WHERE client = ?", (ip_address,))
    current_rows = cursor.fetchone()[0]
    if current_rows > initial_rows:
        cursor.execute(
            "SELECT domain, timestamp, type FROM queries WHERE client = ? ORDER BY id DESC LIMIT {}".format(
                current_rows - initial_rows
            ),
            (ip_address,),
        )
        new_queries = cursor.fetchall()
        return new_queries
    return []


def print_queries(queries: List[Tuple[str, str, str]], highlight_domains: List[str]):
    """
    Print new queries
    :param queries: A list of new queries, each represented as a tuple (domain, timestamp, type)
    :param highlight_domains: A list of domains to highlight
    """
    for query in queries:
        timestamp = datetime.fromtimestamp(query[1]).strftime("%Y-%m-%d %H:%M:%S")
        domain = query[0]
        query_type = query[2]
        highlighted = any(hd in domain for hd in highlight_domains)
        blocked = check_domain(domain, "208.67.222.123")

        if highlighted:
            print(f"\033[91m{timestamp} {domain}\033[0m")
        elif blocked:
            print(f"\033[91m{timestamp} {domain}\033[0m")
        elif query_type == "block":
            print(f"\033[93m{timestamp} {domain}\033[0m")
        else:
            print("{} {}".format(timestamp, domain))


def tail_queries(database_path: str, ip_address: str, highlight_domains: List[str]):
    """
    Tails the Pi-hole query log
    :param database_path: The path to the Pi-hole SQLite database
    :param highlight_domains: A list of domains to highlight
    """
    # Connect to the database
    conn = sqlite3.connect(database_path)
    cursor = conn.cursor()

    # Get the initial number of rows
    cursor.execute("SELECT COUNT(*) FROM queries WHERE client = ?", (ip_address,))
    initial_rows = cursor.fetchone()[0]

    while True:
        new_queries = get_new_queries(conn, initial_rows, ip_address)
        print_queries(new_queries, highlight_domains)
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
    parser.add_argument(
        "-d", "--domains", nargs="+", help="The domains to be highlighted", default=[]
    )

    args = parser.parse_args()
    tail_queries(args.database_path, args.ip_address, args.domains)
