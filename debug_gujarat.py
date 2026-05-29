import pandas as pd
import requests
import io

url = "https://en.wikipedia.org/wiki/15th_Gujarat_Legislative_Assembly"
headers = {'User-Agent': 'Mozilla/5.0'}
response = requests.get(url, headers=headers)
tables = pd.read_html(io.StringIO(response.text))

for i, tbl in enumerate(tables):
    print(f"Table {i} columns: {tbl.columns.tolist()}")
