import json
import subprocess
import sys

rows = subprocess.check_output(['java', '-cp', sys.argv[1], 'OfficeFormattingTest'], text=True).splitlines()
sizes = [8, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 72]
assert len(rows) == len(sizes)
for row, size in zip(rows, sizes):
    payload = json.loads(row)
    assert payload == {'FontHeight': {'type': 'float', 'value': f'{size}.0'}}
print('All font sizes: valid UNO JSON and rejected out-of-range values: PASS')
