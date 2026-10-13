"""Connection-pool wrapper around mysql-connector-python.

Every unit of work runs in ONE transaction: commit on clean exit, rollback on
any exception. MySQL errors raised by constraints/triggers are translated into
user-friendly AppError messages here, so the UI never sees raw SQL errors.
"""
from contextlib import contextmanager

import mysql.connector
from mysql.connector import pooling

import config

_pool = pooling.MySQLConnectionPool(
    pool_name="campus_pool",
    pool_size=8,
    host=config.DB_HOST,
    port=config.DB_PORT,
    user=config.DB_USER,
    password=config.DB_PASSWORD,
    database=config.DB_NAME,
    autocommit=False,
)


class AppError(Exception):
    """A user-facing error: (message, http_status)."""

    def __init__(self, message, status=400):
        super().__init__(message)
        self.message = message
        self.status = status


def _translate(e):
    """Map a MySQL error to an AppError."""
    if e.errno == 1644:                                   # SIGNAL from a trigger
        return AppError(e.msg, 409)
    if e.errno == 3819:                                  # CHECK violated
        return AppError("A data rule was violated: " + e.msg, 400)
    if e.errno == 1062:                                    # duplicate key
        return AppError("Duplicate value: that record already exists", 409)
    if e.errno == 1451:                                    # FK: row is referenced
        return AppError("Cannot delete: other records depend on this one", 409)
    if e.errno == 1452:                                    # FK: no such parent row
        return AppError("Referenced record does not exist", 400)
    return None


@contextmanager
def get_cursor(dictionary=True):
    cnx = _pool.get_connection()
    cur = cnx.cursor(dictionary=dictionary)
    try:
        yield cnx, cur
        cnx.commit()
    except mysql.connector.Error as e:
        cnx.rollback()
        app_err = _translate(e)
        if app_err:
            raise app_err from e
        raise
    except Exception:
        cnx.rollback()
        raise
    finally:
        cur.close()
        cnx.close()
