import json
import ast
import traceback

with open('last_call.txt', 'rb') as f:
    raw = f.read()
if raw.startswith(b'\xef\xbb\xbf'):
    raw = raw[3:]
text = raw.decode('utf-8').strip()

# find the JSON start
try:
    data = json.loads(text)
    tc = data.get('tool_calls', [{}])[0]
    chunks_str = tc.get('args', {}).get('ReplacementChunks', '[]')
except Exception as e:
    print('Failed outer JSON parse:', e)
    # The whole line might not be valid JSON, let's extract ReplacementChunks with regex
    import re
    match = re.search(r'"ReplacementChunks"\s*:\s*(\[.*?\])\s*\}', text, flags=re.DOTALL)
    if match:
        chunks_str = match.group(1)
    else:
        print("Regex failed to find chunks.")
        exit(1)

if isinstance(chunks_str, str):
    # Fix the string to be python parseable
    py_str = chunks_str.replace("true", "True").replace("false", "False").replace("null", "None")
    try:
        chunks = ast.literal_eval(py_str)
    except Exception as e:
        print('AST eval failed:', e)
        traceback.print_exc()
        exit(1)
else:
    chunks = chunks_str

with open('e:/BharatFlow/BharatFlow/lib/features/dashboard/presentation/screens/weather_impact_screen.dart', 'r', encoding='utf-8') as src:
    content = src.read()

count = 0
for c in chunks:
    tgt = c['TargetContent']
    rpl = c['ReplacementContent']
    if tgt in content:
        content = content.replace(tgt, rpl, 1)
        count += 1
    else:
        print("WARNING: Chunk target not found in file:")
        print(repr(tgt[:50]))

if count > 0:
    with open('e:/BharatFlow/BharatFlow/lib/features/dashboard/presentation/screens/weather_impact_screen.dart', 'w', encoding='utf-8') as out:
        out.write(content)
    print(f'Applied {count} out of {len(chunks)} chunks successfully.')
else:
    print('No chunks matched the target file content.')
