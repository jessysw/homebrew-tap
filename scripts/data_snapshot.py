"""Snapshot only the disposable acceptance database; never print its contents."""
import json
import os
from pathlib import Path
import sys

from sqlalchemy import create_engine, inspect, text

engine = create_engine(os.environ['DATABASE_URL'])
with engine.connect() as connection:
    snapshot = {}
    for table in sorted(inspect(connection).get_table_names()):
        quoted = engine.dialect.identifier_preparer.quote(table)
        rows = connection.execute(text(f'SELECT row_to_json(t)::text FROM {quoted} t')).scalars()
        snapshot[table] = sorted(rows)
Path(sys.argv[1]).write_text(json.dumps(snapshot, sort_keys=True))
engine.dispose()
