import json
import re

lines = open(r'C:\Users\Admin\.gemini\antigravity\brain\44d94b32-0548-455b-bb36-1cdca726d9e9\.system_generated\logs\transcript.jsonl', encoding='utf-8').readlines()
for line in reversed(lines):
    if 'ConsumerStatefulWidget' in line and 'weather_impact_screen' in line and 'ReplacementChunks' in line:
        data = json.loads(line)
        for tc in data.get('tool_calls', []):
            if tc.get('name') == 'multi_replace_file_content':
                chunks = tc['args']['ReplacementChunks']
                if isinstance(chunks, str):
                    chunks = re.sub(r'\\(?![\"\\/bfnrtu])', r'\\\\', chunks)
                    try: 
                        chunks = json.loads(chunks)
                    except Exception as e:
                        print('Still failed JSON:', e)
                        exit(1)
                
                with open('e:/BharatFlow/BharatFlow/lib/features/dashboard/presentation/screens/weather_impact_screen.dart', 'r', encoding='utf-8') as src:
                    content = src.read()
                
                count = 0
                for c in chunks:
                    tgt = c['TargetContent']
                    rpl = c['ReplacementContent']
                    if tgt in content:
                        content = content.replace(tgt, rpl, 1)
                        count += 1
                
                if count > 0:
                    with open('e:/BharatFlow/BharatFlow/lib/features/dashboard/presentation/screens/weather_impact_screen.dart', 'w', encoding='utf-8') as out:
                        out.write(content)
                    print(f'Applied {count} chunks.')
                    exit(0)
