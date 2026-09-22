"""Validate UNO payloads after Java serialization using an independent JSON parser."""
import json
import subprocess
import sys

rows = subprocess.check_output(['java', '-cp', sys.argv[1], 'OfficeSearchTest'], text=True).splitlines()
assert len(rows) == 3
find, replace, replace_all = [json.loads(row) for row in rows]
assert find['SearchItem.SearchString']['value'] == 'Zażółć 😀 "cytat" \\ .* $1\n\t'
assert find['SearchItem.Command']['value'] == 0
assert find['SearchItem.TransliterateFlags']['value'] == 1
assert replace['SearchItem.ReplaceString']['value'] == '$1\\nowa'
assert replace['SearchItem.Command']['value'] == 2
assert replace['SearchItem.Backward']['value'] is True
assert replace['SearchItem.TransliterateFlags']['value'] == 0
assert replace_all['SearchItem.Command']['value'] == 3
assert replace_all['SearchItem.ReplaceString']['value'] == ''
assert replace_all['SearchItem.SearchString']['value'] == ' '
for row in [find, replace, replace_all]:
    assert row['SearchItem.AlgorithmType']['value'] == 0
    assert row['SearchItem.SearchFlags']['value'] == 0
    assert row['SearchItem.Pattern']['value'] is False
print('UNO search: Unicode, JSON escaping, literal mode, case, direction, deletion and input limits: PASS')
