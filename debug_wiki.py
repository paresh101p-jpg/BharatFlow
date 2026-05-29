import pandas as pd
import requests
import io

url = "https://en.wikipedia.org/wiki/List_of_members_of_the_18th_Lok_Sabha"
headers = {'User-Agent': 'Mozilla/5.0'}
response = requests.get(url, headers=headers)
tables = pd.read_html(io.StringIO(response.text))

for i, tbl in enumerate(tables):
    print(f"Table {i} columns: {tbl.columns.tolist()}")
